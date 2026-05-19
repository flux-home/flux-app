import 'dart:async';

import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AutomationEngine — owns rules, handles matching and connection management.
//
// Pure business logic; no ChangeNotifier, no Flutter imports.
// Callbacks for notification and persistence are injected by DeviceProvider.
// Device-control execution (toggle, setpoint, etc.) is delegated back via
// [onExecuteAction].
// ─────────────────────────────────────────────────────────────────────────────


class AutomationEngine {
  AutomationEngine({
    required List<AutomationRule> rules,
    required List<MatterDevice> Function()                 devicesGetter,
    required DeviceLiveData?    Function(String deviceId)  liveGetter,
    required void               Function()                 onNotify,
    required Future<void>       Function()                 onPersist,
  })  : _rules          = rules,
        _devicesGetter  = devicesGetter,
        _liveGetter     = liveGetter,
        _onNotify       = onNotify,
        _onPersist      = onPersist;

  final List<AutomationRule>                   _rules;
  final List<MatterDevice> Function()          _devicesGetter;
  final DeviceLiveData?    Function(String)    _liveGetter;
  final void               Function()          _onNotify;
  final Future<void>       Function()          _onPersist;

  final Map<String, int> _lastSwitchPressTime = {};

  // ── Rule CRUD ─────────────────────────────────────────────────────────────

  List<AutomationRule> rulesFor(String deviceId) =>
      _rules.where((r) => r.sourceDeviceId == deviceId).toList();

  void upsertRule(AutomationRule rule) {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) { _rules[idx] = rule; } else { _rules.add(rule); }
    unawaited(_onPersist());
    _onNotify();
  }

  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    unawaited(_onPersist());
    _onNotify();
  }

  // ── Linkable targets ──────────────────────────────────────────────────────

  List<DeviceView> linkableTargets({String? excludingDeviceId, AutomationAction? action}) {
    return _devicesGetter()
        .where((d) => d.id != excludingDeviceId)
        .map((d) => DeviceView(d, _liveGetter(d.id)))
        .where((v) => action == null || supportsAction(v, action))
        .toList();
  }

  bool supportsAction(DeviceView v, AutomationAction action) {
    final live = v.live;
    return switch (action) {
      AutomationAction.toggle     ||
      AutomationAction.turnOn     ||
      AutomationAction.turnOff    =>
          v.deviceType.hasOnOff || (live?.attrs.containsKey('onOff') ?? false) ||
          v.deviceType == DeviceType.thermostat || (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.thermostatOff =>
          v.deviceType == DeviceType.thermostat || (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.brightnessStepUp   ||
      AutomationAction.brightnessStepDown =>
          v.deviceType.hasBrightness || (live?.attrs.containsKey('level') ?? false),
      AutomationAction.thermostatSetpointUp   ||
      AutomationAction.thermostatSetpointDown =>
          v.deviceType == DeviceType.thermostat || (live?.attrs.containsKey('localTempCenti') ?? false),
    };
  }

  // ── Connection management ─────────────────────────────────────────────────

  List<DeviceConnection> connectionsFor(String sourceDeviceId) {
    final rules = rulesFor(sourceDeviceId);
    final map   = <(String, String?), List<AutomationRule>>{};
    for (final rule in rules) {
      for (final tid in rule.targetDeviceIds) {
        (map[(tid, rule.switchGroup)] ??= []).add(rule);
      }
    }
    return map.entries.map((e) => DeviceConnection(
      targetDeviceId: e.key.$1,
      switchGroup:    e.key.$2,
      rules:          e.value,
    )).toList();
  }

  String? nextFreeSlot(String sourceDeviceId, List<SwitchGroup> groups) {
    if (groups.isEmpty) return null;
    final usedSlots = _rules
        .where((r) => r.sourceDeviceId == sourceDeviceId && r.switchGroup != null)
        .map((r) => r.switchGroup!)
        .toSet();
    return groups.map((g) => g.label).firstWhere(
      (label) => !usedSlots.contains(label),
      orElse: () => groups.first.label,
    );
  }

  void connectDevice({
    required String            sourceDeviceId,
    required DeviceType        sourceType,
    required String            targetDeviceId,
    required List<SwitchGroup> switchGroups,
  }) {
    final targetView = _devicesGetter()
        .where((d) => d.id == targetDeviceId)
        .map((d) => DeviceView(d, _liveGetter(d.id)))
        .firstOrNull;
    if (targetView == null) return;

    if (sourceType == DeviceType.contactSensor) {
      if (supportsAction(targetView, AutomationAction.thermostatOff)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.contactOpen,
          action: AutomationAction.thermostatOff, targetDeviceIds: [targetDeviceId]));
      } else if (supportsAction(targetView, AutomationAction.turnOn)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.contactOpen,
          action: AutomationAction.turnOn, targetDeviceIds: [targetDeviceId]));
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.contactClose,
          action: AutomationAction.turnOff, targetDeviceIds: [targetDeviceId]));
      }
    } else {
      final slot = nextFreeSlot(sourceDeviceId, switchGroups);
      if (slot == null) return;
      final group = switchGroups.firstWhere((g) => g.label == slot);

      if (group.pressEndpoints.isNotEmpty) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.switchPress, switchGroup: slot,
          endpoints: group.pressEndpoints, action: AutomationAction.toggle, targetDeviceIds: [targetDeviceId]));
      }
      if (group.cwEndpoints.isNotEmpty) {
        final a = supportsAction(targetView, AutomationAction.thermostatSetpointUp)
            ? AutomationAction.thermostatSetpointUp
            : supportsAction(targetView, AutomationAction.brightnessStepUp)
                ? AutomationAction.brightnessStepUp : null;
        if (a != null) upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.switchCw, switchGroup: slot,
          endpoints: group.cwEndpoints, action: a, targetDeviceIds: [targetDeviceId]));
      }
      if (group.ccwEndpoints.isNotEmpty) {
        final a = supportsAction(targetView, AutomationAction.thermostatSetpointDown)
            ? AutomationAction.thermostatSetpointDown
            : supportsAction(targetView, AutomationAction.brightnessStepDown)
                ? AutomationAction.brightnessStepDown : null;
        if (a != null) upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId, trigger: TriggerType.switchCcw, switchGroup: slot,
          endpoints: group.ccwEndpoints, action: a, targetDeviceIds: [targetDeviceId]));
      }
    }
  }

  void disconnectTarget({
    required String  sourceDeviceId,
    required String  targetDeviceId,
    required String? switchGroup,
  }) {
    final toProcess = _rules.where((r) =>
        r.sourceDeviceId == sourceDeviceId &&
        r.switchGroup    == switchGroup    &&
        r.targetDeviceIds.contains(targetDeviceId)).toList();

    for (final rule in toProcess) {
      if (rule.targetDeviceIds.length == 1) {
        _rules.remove(rule);
      } else {
        final idx = _rules.indexWhere((r) => r.id == rule.id);
        _rules[idx] = rule.copyWith(
          targetDeviceIds: rule.targetDeviceIds.where((id) => id != targetDeviceId).toList());
      }
    }
    unawaited(_onPersist());
    _onNotify();
  }

  // ── Incoming-event handlers ────────────────────────────────────────────────

  /// Returns a list of (deviceId, action) pairs to execute in response to a
  /// contact-state change.  Caller is responsible for execution.
  List<(String, AutomationAction)> processContactChange(
    String deviceId,
    Map<String, dynamic> attrs,
    bool? prevContact,
  ) {
    if (!attrs.containsKey('contactState')) return const [];
    final newState = attrs['contactState'] as bool?;
    if (newState == null || prevContact == null || newState == prevContact) return const [];
    final trigger = newState ? TriggerType.contactClose : TriggerType.contactOpen;
    return [
      for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger == trigger))
        for (final targetId in rule.targetDeviceIds) (targetId, rule.action),
    ];
  }

  /// Returns a list of (deviceId, action) pairs to execute in response to a
  /// switch-press event.
  List<(String, AutomationAction)> processSwitchPress(
    String deviceId,
    Map<String, dynamic> attrs,
  ) {
    final pressTime = attrs['switchPressTime'] as int?;
    if (pressTime == null) return const [];
    if (pressTime == (_lastSwitchPressTime[deviceId] ?? 0)) return const [];
    _lastSwitchPressTime[deviceId] = pressTime;

    final ep = (attrs['switchLastEndpoint'] as int?) ?? 0;
    if (ep == 0) return const [];

    return [
      for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger.isSwitch))
        if (rule.endpoints.contains(ep))
          for (final targetId in rule.targetDeviceIds) (targetId, rule.action),
    ];
  }
}
