import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/services/automation_engine.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

MatterDevice _device(String id, {DeviceType type = DeviceType.onOffLight}) =>
    MatterDevice(
      id: id,
      name: 'Device $id',
      deviceType: type,
      nodeId: 0,
      commissionedAt: DateTime(2024),
      lastModified: DateTime(2024),
    );

DeviceView _view(MatterDevice d, {Map<String, dynamic>? attrs}) =>
    DeviceView(d, attrs != null ? DeviceLiveData(updatedAt: DateTime.now(), isStale: false, attrs: attrs) : null);

AutomationEngine _engine({
  List<AutomationRule>? rules,
  List<MatterDevice>? devices,
  Map<String, DeviceLiveData>? liveCache,
}) {
  final ruleList = List<AutomationRule>.from(rules ?? []);
  final deviceList = devices ?? [];
  final cache = liveCache ?? {};
  return AutomationEngine(
    rules:         ruleList,
    devicesGetter: () => deviceList,
    liveGetter:    (id) => cache[id],
    onNotify:      () {},
    onPersist:     () async {},
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AutomationEngine — rule CRUD', () {
    test('upsertRule adds a new rule', () {
      final engine = _engine();
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        action: AutomationAction.toggle,
        targetDeviceIds: ['tgt'],
      );
      engine.upsertRule(rule);
      expect(engine.rulesFor('src'), hasLength(1));
      expect(engine.rulesFor('src').first.id, equals(rule.id));
    });

    test('upsertRule updates an existing rule by id', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        action: AutomationAction.toggle,
        targetDeviceIds: ['t1'],
      );
      final engine = _engine(rules: [rule]);
      final updated = rule.copyWith(targetDeviceIds: ['t1', 't2']);
      engine.upsertRule(updated);
      expect(engine.rulesFor('src'), hasLength(1));
      expect(engine.rulesFor('src').first.targetDeviceIds, containsAll(['t1', 't2']));
    });

    test('removeRule removes by id', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        action: AutomationAction.toggle,
        targetDeviceIds: ['t'],
      );
      final engine = _engine(rules: [rule]);
      engine.removeRule(rule.id);
      expect(engine.rulesFor('src'), isEmpty);
    });

    test('rulesFor returns only rules for the given device', () {
      final r1 = AutomationRule(sourceDeviceId: 'A', trigger: TriggerType.switchPress,
          action: AutomationAction.toggle, targetDeviceIds: ['T']);
      final r2 = AutomationRule(sourceDeviceId: 'B', trigger: TriggerType.switchPress,
          action: AutomationAction.toggle, targetDeviceIds: ['T']);
      final engine = _engine(rules: [r1, r2]);
      expect(engine.rulesFor('A'), hasLength(1));
      expect(engine.rulesFor('B'), hasLength(1));
      expect(engine.rulesFor('C'), isEmpty);
    });
  });

  group('AutomationEngine — switch press processing', () {
    test('processSwitchPress returns empty when no switchPressTime key', () {
      final engine = _engine();
      final result = engine.processSwitchPress('src', {'onOff': true});
      expect(result, isEmpty);
    });

    test('processSwitchPress debounces duplicate timestamps', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        endpoints: [1],
        action: AutomationAction.toggle,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      final attrs = {'switchPressTime': 100, 'switchLastEndpoint': 1};
      final r1 = engine.processSwitchPress('src', attrs);
      final r2 = engine.processSwitchPress('src', attrs); // same timestamp
      expect(r1, hasLength(1));
      expect(r2, isEmpty); // debounced
    });

    test('processSwitchPress matches endpoint', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        endpoints: [2], // only endpoint 2
        action: AutomationAction.toggle,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      // Endpoint 1 — should not match
      final r1 = engine.processSwitchPress('src', {'switchPressTime': 1, 'switchLastEndpoint': 1});
      expect(r1, isEmpty);
      // Endpoint 2 — should match
      final r2 = engine.processSwitchPress('src', {'switchPressTime': 2, 'switchLastEndpoint': 2});
      expect(r2, hasLength(1));
      expect(r2.first.$1, equals('tgt'));
      expect(r2.first.$2, equals(AutomationAction.toggle));
    });

    test('processSwitchPress returns actions for all target devices', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.switchPress,
        endpoints: [1],
        action: AutomationAction.turnOn,
        targetDeviceIds: ['t1', 't2'],
      );
      final engine = _engine(rules: [rule]);
      final result = engine.processSwitchPress('src', {'switchPressTime': 1, 'switchLastEndpoint': 1});
      expect(result, hasLength(2));
    });
  });

  group('AutomationEngine — contact change processing', () {
    test('processContactChange returns empty when contactState not in attrs', () {
      final engine = _engine();
      final result = engine.processContactChange('src', {'onOff': true}, false);
      expect(result, isEmpty);
    });

    test('processContactChange returns empty when state unchanged', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.contactOpen,
        action: AutomationAction.turnOn,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      // State was false (open), still false — no change
      final result = engine.processContactChange('src', {'contactState': false}, false);
      expect(result, isEmpty);
    });

    test('processContactChange fires contactClose when state goes open→closed', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.contactClose,
        action: AutomationAction.turnOff,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      // Was false (open), now true (closed) → should fire contactClose
      final result = engine.processContactChange('src', {'contactState': true}, false);
      expect(result, hasLength(1));
      expect(result.first.$2, equals(AutomationAction.turnOff));
    });

    test('processContactChange fires contactOpen when state goes closed→open', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.contactOpen,
        action: AutomationAction.turnOn,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      // Was true (closed), now false (open) → should fire contactOpen
      final result = engine.processContactChange('src', {'contactState': false}, true);
      expect(result, hasLength(1));
      expect(result.first.$2, equals(AutomationAction.turnOn));
    });

    test('processContactChange returns empty when prevContact is null', () {
      final rule = AutomationRule(
        sourceDeviceId: 'src',
        trigger: TriggerType.contactClose,
        action: AutomationAction.turnOn,
        targetDeviceIds: ['tgt'],
      );
      final engine = _engine(rules: [rule]);
      // No previous state known → cannot detect transition
      final result = engine.processContactChange('src', {'contactState': true}, null);
      expect(result, isEmpty);
    });
  });

  group('AutomationEngine — supportsAction', () {
    test('toggle supported for device with hasOnOff', () {
      final d = _device('d', type: DeviceType.onOffLight);
      final engine = _engine(devices: [d]);
      expect(engine.supportsAction(_view(d), AutomationAction.toggle), isTrue);
    });

    test('toggle supported when live attrs contain onOff', () {
      final d = _device('d', type: DeviceType.unknown);
      final engine = _engine(devices: [d]);
      expect(engine.supportsAction(_view(d, attrs: {'onOff': true}), AutomationAction.toggle), isTrue);
    });

    test('brightnessStepUp not supported for contactSensor', () {
      final d = _device('d', type: DeviceType.contactSensor);
      final engine = _engine(devices: [d]);
      expect(engine.supportsAction(_view(d), AutomationAction.brightnessStepUp), isFalse);
    });

    test('thermostatSetpointUp supported for thermostat type', () {
      final d = _device('d', type: DeviceType.thermostat);
      final engine = _engine(devices: [d]);
      expect(engine.supportsAction(_view(d), AutomationAction.thermostatSetpointUp), isTrue);
    });
  });

  group('AutomationEngine — connectionsFor', () {
    test('groups rules by (targetDeviceId, switchGroup)', () {
      final r1 = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.switchPress,
          switchGroup: 'A', action: AutomationAction.toggle, targetDeviceIds: ['t1']);
      final r2 = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.switchCw,
          switchGroup: 'A', action: AutomationAction.brightnessStepUp, targetDeviceIds: ['t1']);
      final r3 = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.switchPress,
          switchGroup: 'B', action: AutomationAction.toggle, targetDeviceIds: ['t2']);
      final engine = _engine(rules: [r1, r2, r3]);
      final conns = engine.connectionsFor('src');
      expect(conns, hasLength(2));
    });

    test('connection carries all rules for the (target, group) pair', () {
      final r1 = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.switchPress,
          switchGroup: 'A', action: AutomationAction.toggle, targetDeviceIds: ['t1']);
      final r2 = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.switchCw,
          switchGroup: 'A', action: AutomationAction.brightnessStepUp, targetDeviceIds: ['t1']);
      final engine = _engine(rules: [r1, r2]);
      final conns = engine.connectionsFor('src');
      expect(conns.first.rules, hasLength(2));
    });
  });

  group('AutomationEngine — disconnectTarget', () {
    test('removes rule entirely when single target', () {
      final rule = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.contactOpen,
          action: AutomationAction.turnOn, targetDeviceIds: ['t1']);
      final engine = _engine(rules: [rule]);
      engine.disconnectTarget(sourceDeviceId: 'src', targetDeviceId: 't1', switchGroup: null);
      expect(engine.rulesFor('src'), isEmpty);
    });

    test('removes only the target when rule has multiple targets', () {
      final rule = AutomationRule(sourceDeviceId: 'src', trigger: TriggerType.contactOpen,
          action: AutomationAction.turnOn, targetDeviceIds: ['t1', 't2']);
      final engine = _engine(rules: [rule]);
      engine.disconnectTarget(sourceDeviceId: 'src', targetDeviceId: 't1', switchGroup: null);
      final remaining = engine.rulesFor('src');
      expect(remaining, hasLength(1));
      expect(remaining.first.targetDeviceIds, equals(['t2']));
    });
  });
}
