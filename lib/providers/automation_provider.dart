import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/providers/device_provider.dart';

class AutomationProvider extends ChangeNotifier {
  AutomationProvider(this._store);

  final DeviceStore _store;
  DeviceProvider? _deviceProvider;

  void update(DeviceProvider deviceProvider) {
    _deviceProvider = deviceProvider;
    if (_rules.isEmpty) _load();
  }
  final List<AutomationRule> _rules = [];
  final Map<String, int> _lastSwitchPressTime = {};

  List<AutomationRule> get rules => List.unmodifiable(_rules);

  void _load() {
    _rules.clear();
    _rules.addAll(_store.loadRules());
    notifyListeners();
  }

  Future<void> _persist() => _store.saveRules(_rules);

  /// Devices that can be targeted by [action], excluding [excludingDeviceId].
  List<DeviceView> linkableTargets({
    String? excludingDeviceId,
    AutomationAction? action,
  }) {
    final provider = _deviceProvider;
    if (provider == null) return [];
    return provider.devices
        .where((d) => d.id != excludingDeviceId)
        .map((d) => provider.viewFor(d.id)!)
        .where((v) => action == null || _supportsAction(v, action))
        .toList();
  }

  bool _supportsAction(DeviceView v, AutomationAction action) {
    final live = _deviceProvider?.liveDataFor(v.id);
    return switch (action) {
      AutomationAction.toggle ||
      AutomationAction.turnOn ||
      AutomationAction.turnOff =>
        v.deviceType.hasOnOff ||
            (live?.attrs.containsKey('onOff') ?? false) ||
            v.deviceType == DeviceType.thermostat ||
            (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.thermostatOff =>
        v.deviceType == DeviceType.thermostat ||
            (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.brightnessStepUp ||
      AutomationAction.brightnessStepDown =>
        v.deviceType.hasBrightness || (live?.attrs.containsKey('level') ?? false),
      AutomationAction.thermostatSetpointUp ||
      AutomationAction.thermostatSetpointDown =>
        v.deviceType == DeviceType.thermostat ||
            (live?.attrs.containsKey('localTempCenti') ?? false),
    };
  }

  List<AutomationRule> rulesFor(String deviceId) =>
      _rules.where((r) => r.sourceDeviceId == deviceId).toList();

  void upsertRule(AutomationRule rule) {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules[idx] = rule;
    } else {
      _rules.add(rule);
    }
    unawaited(_persist());
    notifyListeners();
  }

  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    unawaited(_persist());
    notifyListeners();
  }

  List<DeviceConnection> connectionsFor(String sourceDeviceId) {
    final rules = rulesFor(sourceDeviceId);
    final map = <(String, String?), List<AutomationRule>>{};
    for (final rule in rules) {
      for (final tid in rule.targetDeviceIds) {
        (map[(tid, rule.switchGroup)] ??= []).add(rule);
      }
    }
    return map.entries
        .map((e) => DeviceConnection(
              targetDeviceId: e.key.$1,
              switchGroup: e.key.$2,
              rules: e.value,
            ))
        .toList();
  }

  String? nextFreeSlot(String sourceDeviceId, List<SwitchGroup> groups) {
    if (groups.isEmpty) return null;
    final usedSlots = _rules
        .where((r) => r.sourceDeviceId == sourceDeviceId && r.switchGroup != null)
        .map((r) => r.switchGroup!)
        .toSet();
    return groups
        .map((g) => g.label)
        .firstWhere((label) => !usedSlots.contains(label),
            orElse: () => groups.first.label);
  }

  /// Processes state updates and returns a list of (targetDeviceId, action) pairs to execute.
  List<(String, AutomationAction)> getPendingActions(
    String deviceId,
    Map<String, dynamic> attrs, {
    bool? prevContact,
  }) {
    final actions = <(String, AutomationAction)>[];

    // Handle Contact Change
    if (attrs.containsKey('contactState')) {
      final newState = attrs['contactState'] as bool?;
      if (newState != null && prevContact != null && newState != prevContact) {
        final trigger = newState ? TriggerType.contactClose : TriggerType.contactOpen;
        for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger == trigger)) {
          for (final targetId in rule.targetDeviceIds) {
            actions.add((targetId, rule.action));
          }
        }
      }
    }

    // Handle Switch Press
    final pressTime = attrs['switchPressTime'] as int?;
    if (pressTime != null && pressTime != (_lastSwitchPressTime[deviceId] ?? 0)) {
      _lastSwitchPressTime[deviceId] = pressTime;
      final ep = (attrs['switchLastEndpoint'] as int?) ?? 0;
      if (ep != 0) {
        for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger.isSwitch)) {
          if (rule.endpoints.contains(ep)) {
            for (final targetId in rule.targetDeviceIds) {
              actions.add((targetId, rule.action));
            }
          }
        }
      }
    }

    return actions;
  }

  void connectDevice({
    required String sourceDeviceId,
    required DeviceType sourceType,
    required String targetDeviceId,
    required List<SwitchGroup> switchGroups,
  }) {
    final targetView = _deviceProvider?.viewFor(targetDeviceId);
    if (targetView == null) return;

    if (sourceType == DeviceType.contactSensor) {
      // Contact sensor presets
      if (_supportsAction(targetView, AutomationAction.thermostatOff)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger: TriggerType.contactOpen,
          action: AutomationAction.thermostatOff,
          targetDeviceIds: [targetDeviceId],
        ));
      } else if (_supportsAction(targetView, AutomationAction.turnOn)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger: TriggerType.contactOpen,
          action: AutomationAction.turnOn,
          targetDeviceIds: [targetDeviceId],
        ));
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger: TriggerType.contactClose,
          action: AutomationAction.turnOff,
          targetDeviceIds: [targetDeviceId],
        ));
      }
    } else {
      // Switch presets — assign to next free slot
      final slot = nextFreeSlot(sourceDeviceId, switchGroups);
      if (slot == null) return;
      final group = switchGroups.firstWhere((g) => g.label == slot);

      if (group.pressEndpoints.isNotEmpty) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger: TriggerType.switchPress,
          switchGroup: slot,
          endpoints: group.pressEndpoints,
          action: AutomationAction.toggle,
          targetDeviceIds: [targetDeviceId],
        ));
      }
      if (group.cwEndpoints.isNotEmpty) {
        final a = _supportsAction(targetView, AutomationAction.thermostatSetpointUp)
            ? AutomationAction.thermostatSetpointUp
            : _supportsAction(targetView, AutomationAction.brightnessStepUp)
                ? AutomationAction.brightnessStepUp
                : null;
        if (a != null) {
          upsertRule(AutomationRule(
            sourceDeviceId: sourceDeviceId,
            trigger: TriggerType.switchCw,
            switchGroup: slot,
            endpoints: group.cwEndpoints,
            action: a,
            targetDeviceIds: [targetDeviceId],
          ));
        }
      }
      if (group.ccwEndpoints.isNotEmpty) {
        final a = _supportsAction(targetView, AutomationAction.thermostatSetpointDown)
            ? AutomationAction.thermostatSetpointDown
            : _supportsAction(targetView, AutomationAction.brightnessStepDown)
                ? AutomationAction.brightnessStepDown
                : null;
        if (a != null) {
          upsertRule(AutomationRule(
            sourceDeviceId: sourceDeviceId,
            trigger: TriggerType.switchCcw,
            switchGroup: slot,
            endpoints: group.ccwEndpoints,
            action: a,
            targetDeviceIds: [targetDeviceId],
          ));
        }
      }
    }
  }

  void disconnectTarget({
    required String sourceDeviceId,
    required String targetDeviceId,
    required String? switchGroup,
  }) {
    final toProcess = _rules
        .where((r) =>
            r.sourceDeviceId == sourceDeviceId &&
            r.switchGroup == switchGroup &&
            r.targetDeviceIds.contains(targetDeviceId))
        .toList();

    for (final rule in toProcess) {
      if (rule.targetDeviceIds.length == 1) {
        _rules.remove(rule);
      } else {
        final idx = _rules.indexWhere((r) => r.id == rule.id);
        _rules[idx] = rule.copyWith(
          targetDeviceIds: rule.targetDeviceIds
              .where((id) => id != targetDeviceId)
              .toList(),
        );
      }
    }
    unawaited(_persist());
    notifyListeners();
  }
}
