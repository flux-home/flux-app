// ignore_for_file: lines_longer_than_80_chars

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/matter_fakes.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

MatterDevice _device({
  String id = 'dev-1',
  String name = 'Light',
  int nodeId = 1001,
  DeviceType type = DeviceType.onOffLight,
  ManagedBy managedBy = ManagedBy.phone,
  bool isOnline = true,
}) {
  final now = DateTime(2024);
  return MatterDevice(
    id: id,
    name: name,
    deviceType: type,
    nodeId: nodeId,
    commissionedAt: now,
    lastModified: now,
    managedBy: managedBy,
    isOnline: isOnline,
  );
}

/// Builds provider + fake, pre-seeding the store with [devices] and
/// optional [snapshots] (map deviceId → attribute map).
Future<(DeviceProvider, FakeMatterPort)> _build({
  List<MatterDevice> devices = const [],
  Map<String, Map<String, dynamic>> snapshots = const {},
  DateTime Function()? now,
}) async {
  final prefs = <String, Object>{};
  if (devices.isNotEmpty) {
    prefs['matter_devices'] = devices.map((d) => jsonEncode(d.toJson())).toList();
  }
  if (snapshots.isNotEmpty) {
    prefs['device_snapshots'] = snapshots.entries
        .map((e) => jsonEncode({'deviceId': e.key, 'state': e.value}))
        .toList();
  }
  SharedPreferences.setMockInitialValues(prefs);
  final store = await DeviceStore.open();
  final fake = FakeMatterPort();
  final provider = DeviceProvider(store, fake, now: now ?? DateTime.now);
  await pumpEventQueue();
  return (provider, fake);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Cold-start load ──────────────────────────────────────────────────────

  group('cold-start load', () {
    test('loads persisted devices from store', () async {
      final d = _device();
      final (provider, _) = await _build(devices: [d]);
      expect(provider.devices, hasLength(1));
      expect(provider.devices.first.id, d.id);
    });

    test('seeds live cache from snapshot and marks it stale', () async {
      final d = _device();
      final (provider, _) = await _build(
        devices: [d],
        snapshots: {d.id: {'onOff': true, 'level': 200}},
      );
      final live = provider.liveDataFor(d.id);
      expect(live, isNotNull);
      expect(live!.isStale, isTrue);
      expect(live.isOn, isTrue);
    });

    test('legacy fix: onOffLight with localTempCenti snapshot becomes thermostat', () async {
      final d = _device(type: DeviceType.onOffLight);
      final (provider, _) = await _build(
        devices: [d],
        snapshots: {d.id: {'localTempCenti': 2150}},
      );
      expect(provider.devices.first.deviceType, DeviceType.thermostat);
    });

    test('onOffLight without thermostat snapshot stays onOffLight', () async {
      final d = _device(type: DeviceType.onOffLight);
      final (provider, _) = await _build(
        devices: [d],
        snapshots: {d.id: {'onOff': true}},
      );
      expect(provider.devices.first.deviceType, DeviceType.onOffLight);
    });
  });

  // ── 2. Subscription lifecycle ───────────────────────────────────────────────

  group('subscription lifecycle', () {
    test('construction starts one subscription per phone-managed device', () async {
      final d1 = _device(id: 'a', nodeId: 1);
      final d2 = _device(id: 'b', nodeId: 2);
      final (_, fake) = await _build(devices: [d1, d2]);
      expect(fake.startedSubscriptions, containsAll([1, 2]));
    });

    test('SubscriptionEstablishedEvent is processed without error', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      // Emitting established should cancel the timer and not throw.
      fake.emit(SubscriptionEstablishedEvent(d.nodeId));
      await pumpEventQueue();

      // Subscription was started and the event was processed.
      expect(fake.startedSubscriptions, contains(d.nodeId));
      // Provider is still in a good state.
      expect(provider.devices, hasLength(1));
    });

    test('controller-managed device still gets a subscription started', () async {
      // Controller-managed devices subscribe via the same channel path but
      // do NOT arm the 15s establish-fallback timer (would cause false offline
      // due to CoAP Observe delivery timing — see _startSubscription comment).
      final d = _device(managedBy: ManagedBy.controller);
      final (_, fake) = await _build(devices: [d]);

      expect(fake.startedSubscriptions, contains(d.nodeId));
    });
  });

  // ── 3. Stale marking ────────────────────────────────────────────────────────

  group('stale marking', () {
    test('SubscriptionErrorEvent marks cache stale without clearing values', () async {
      final d = _device();
      final (provider, fake) = await _build(
        devices: [d],
        snapshots: {d.id: {'onOff': true}},
      );
      // Wait for subscription and flush initial stale marking from load.
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': true}));
      await pumpEventQueue();
      expect(provider.liveDataFor(d.id)!.isStale, isFalse);

      fake.emit(SubscriptionErrorEvent(d.nodeId, 'timeout'));
      await pumpEventQueue();
      final live = provider.liveDataFor(d.id);
      expect(live!.isStale, isTrue);
      expect(live.isOn, isTrue); // value preserved
    });

    test('SubscriptionUpdateEvent after error un-stales the cache', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': true}));
      await pumpEventQueue();
      fake.emit(SubscriptionErrorEvent(d.nodeId, 'x'));
      await pumpEventQueue();
      expect(provider.liveDataFor(d.id)!.isStale, isTrue);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': false}));
      await pumpEventQueue();
      expect(provider.liveDataFor(d.id)!.isStale, isFalse);
      expect(provider.liveDataFor(d.id)!.isOn, isFalse);
    });
  });

  // ── 4. Toggle optimistic update + rollback ──────────────────────────────────

  group('toggle', () {
    test('optimistic update flips on/off immediately', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': false}));
      await pumpEventQueue();
      expect(provider.liveDataFor(d.id)!.isOn, isFalse);

      unawaited(provider.toggle(d.id));
      await pumpEventQueue();
      // Before the channel future resolves: already flipped.
      expect(provider.liveDataFor(d.id)!.isOn, isTrue);
      expect(fake.toggleCalls, hasLength(1));
      expect(fake.toggleCalls.first.on, isTrue);
    });

    test('toggle rolls back on channel failure', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': true}));
      await pumpEventQueue();

      // Make toggle fail.
      fake.toggleOverride = (nodeId, {required bool on}) async => false;

      await provider.toggle(d.id);
      await pumpEventQueue();

      // Rolled back to previous value.
      expect(provider.liveDataFor(d.id)!.isOn, isTrue);
    });

    test('successful toggle persists snapshot (second provider sees it)', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': false}));
      await pumpEventQueue();

      await provider.toggle(d.id);
      await pumpEventQueue();

      // Open a second provider over the same prefs.
      final store2 = await DeviceStore.open();
      final provider2 = DeviceProvider(store2, FakeMatterPort());
      await pumpEventQueue();

      final live2 = provider2.liveDataFor(d.id);
      expect(live2, isNotNull);
      expect(live2!.isOn, isTrue);
    });
  });

  // ── 5. Switch automation ────────────────────────────────────────────────────

  group('switch automation', () {
    test('switch press fires toggle on target device', () async {
      final src = _device(id: 'switch-1', nodeId: 10, type: DeviceType.genericSwitch);
      final tgt = _device(id: 'light-1', nodeId: 20, type: DeviceType.onOffLight);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.switchPress,
        endpoints: [1],
        action: AutomationAction.toggle,
        targetDeviceIds: [tgt.id],
      ));

      // Prime target live cache so toggle has something to flip.
      fake.emit(SubscriptionUpdateEvent(tgt.nodeId, {'onOff': false}));
      await pumpEventQueue();

      // Fire press event with unique pressTime.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {
        'switchPressTime': 12345,
        'switchLastEndpoint': 1,
      }));
      await pumpEventQueue();

      expect(fake.toggleCalls, isNotEmpty);
      expect(fake.toggleCalls.first.nodeId, tgt.nodeId);
    });

    test('identical pressTime is debounced (second event ignored)', () async {
      final src = _device(id: 'switch-1', nodeId: 10, type: DeviceType.genericSwitch);
      final tgt = _device(id: 'light-1', nodeId: 20, type: DeviceType.onOffLight);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.switchPress,
        endpoints: [1],
        action: AutomationAction.turnOn,
        targetDeviceIds: [tgt.id],
      ));

      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'switchPressTime': 999, 'switchLastEndpoint': 1}));
      await pumpEventQueue();
      final countAfterFirst = fake.toggleCalls.length;

      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'switchPressTime': 999, 'switchLastEndpoint': 1}));
      await pumpEventQueue();
      // Count must not change.
      expect(fake.toggleCalls.length, countAfterFirst);
    });

    test('endpoint 0 is ignored', () async {
      final src = _device(id: 'sw', nodeId: 10, type: DeviceType.genericSwitch);
      final tgt = _device(id: 'lt', nodeId: 20);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.switchPress,
        endpoints: [0],
        action: AutomationAction.toggle,
        targetDeviceIds: [tgt.id],
      ));

      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'switchPressTime': 42, 'switchLastEndpoint': 0}));
      await pumpEventQueue();

      // Endpoint 0 is filtered out.
      expect(fake.toggleCalls, isEmpty);
    });
  });

  // ── 6. Contact automation ───────────────────────────────────────────────────

  group('contact automation', () {
    test('first-ever contact report fires nothing (prevContact is null)', () async {
      final src = _device(id: 'contact-1', nodeId: 10, type: DeviceType.contactSensor);
      final tgt = _device(id: 'light-1', nodeId: 20);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.contactClose,
        action: AutomationAction.turnOn,
        targetDeviceIds: [tgt.id],
      ));

      // First report — no previous value.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'contactState': true}));
      await pumpEventQueue();

      expect(fake.toggleCalls, isEmpty);
    });

    test('open → close transition fires contactClose rules', () async {
      final src = _device(id: 'contact-1', nodeId: 10, type: DeviceType.contactSensor);
      final tgt = _device(id: 'light-1', nodeId: 20);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.contactClose,
        action: AutomationAction.turnOn,
        targetDeviceIds: [tgt.id],
      ));

      // First: establish open state.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'contactState': false}));
      await pumpEventQueue();

      // Transition to closed.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'contactState': true}));
      await pumpEventQueue();

      expect(fake.toggleCalls, isNotEmpty);
    });

    test('close → open transition fires contactOpen rules', () async {
      final src = _device(id: 'contact-1', nodeId: 10, type: DeviceType.contactSensor);
      final tgt = _device(id: 'thermostat-1', nodeId: 20, type: DeviceType.thermostat);
      final (provider, fake) = await _build(devices: [src, tgt]);

      provider.upsertRule(AutomationRule(
        sourceDeviceId: src.id,
        trigger: TriggerType.contactOpen,
        action: AutomationAction.thermostatOff,
        targetDeviceIds: [tgt.id],
      ));

      // Prime live cache with systemMode so thermostatOff path is exercised.
      fake.emit(SubscriptionUpdateEvent(tgt.nodeId, {'systemMode': 4}));
      await pumpEventQueue();

      // Establish closed.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'contactState': true}));
      await pumpEventQueue();

      // Open.
      fake.emit(SubscriptionUpdateEvent(src.nodeId, {'contactState': false}));
      await pumpEventQueue();

      expect(fake.writeSystemModeCalls, isNotEmpty);
      expect(fake.writeSystemModeCalls.first.mode, 0); // Off mode
    });
  });

  // ── 7. Energy accounting ────────────────────────────────────────────────────

  group('energy accounting', () {
    test('cumulative energy update is recorded directly', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 5000}));
      await pumpEventQueue();

      expect(provider.liveDataFor(d.id)!.cumulativeEnergyMwh, 5000);
    });

    test('periodic energy accumulates onto baseline odometer', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      // Establish a baseline cumulative reading.
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 10000}));
      await pumpEventQueue();

      // Periodic delta arrives.
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'periodicEnergyMwh': 500}));
      await pumpEventQueue();

      // Odometer = 10000 + 500 = 10500.
      expect(provider.liveDataFor(d.id)!.cumulativeEnergyMwh, 10500);
    });

    test('15-min bucket seals when clock crosses boundary', () async {
      var fakeNow = DateTime(2024, 1, 1, 12, 0); // 12:00

      final d = _device();
      final (provider, fake) = await _build(
        devices: [d],
        now: () => fakeNow,
      );

      // First reading at 12:00 opens a bucket.
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 1000}));
      await pumpEventQueue();
      expect(provider.energyHistoryFor(d.id), isEmpty); // open, not sealed

      // Advance clock to 12:15 → next bucket.
      fakeNow = DateTime(2024, 1, 1, 12, 15);
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 2000}));
      await pumpEventQueue();

      // Previous bucket (1000 mWh = 1 Wh) should now be sealed.
      final history = provider.energyHistoryFor(d.id);
      expect(history, hasLength(1));
      expect(history.first.wh, 1); // (2000-1000)/1000 = 1 Wh
    });

    test('energy history survives persistence round-trip', () async {
      // The EnergyHistoryRecorder is created lazily on the first energy event.
      // Its constructor calls loadEnergyHistory(deviceId), so the sealed bucket
      // is restored from SharedPreferences when the recorder is first created.
      var fakeNow = DateTime(2024, 1, 1, 12, 0);
      final d = _device();
      final (provider, fake) = await _build(
        devices: [d],
        now: () => fakeNow,
      );

      // Seal a bucket at 12:00.
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 1000}));
      await pumpEventQueue();
      fakeNow = DateTime(2024, 1, 1, 12, 15);
      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 2000}));
      await pumpEventQueue();
      expect(provider.energyHistoryFor(d.id), hasLength(1));

      // Open second provider over same store (same SharedPreferences mock).
      final store2 = await DeviceStore.open();
      final fake2 = FakeMatterPort();
      final provider2 = DeviceProvider(store2, fake2, now: () => fakeNow);
      await pumpEventQueue();

      // Trigger recorder creation — the recorder loads history from the store
      // in its constructor, then handles the new reading.
      fake2.emit(SubscriptionUpdateEvent(d.nodeId, {'cumulativeEnergyMwh': 2000}));
      await pumpEventQueue();

      // Sealed bucket was loaded from disk.
      expect(provider2.energyHistoryFor(d.id), hasLength(1));
    });
  });

  // ── 8. removeDevice / adoptHubMode ─────────────────────────────────────────

  group('removeDevice', () {
    test('stops subscription, calls channel removeDevice, purges caches', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      fake.emit(SubscriptionUpdateEvent(d.nodeId, {'onOff': true}));
      await pumpEventQueue();

      await provider.removeDevice(d.id);
      await pumpEventQueue();

      expect(fake.stoppedSubscriptions, contains(d.nodeId));
      expect(fake.removeDeviceCalls, contains(d.nodeId));
      expect(provider.devices, isEmpty);
      expect(provider.liveDataFor(d.id), isNull);
    });
  });

  // ── 9. Establish timer is cancelled on removeDevice ───────────────────────────
  //
  // removeDevice() now cancels _establishTimeouts[deviceId] immediately after
  // _stopSubscription so no dangling timer fires for a gone device.

  group('timer leak fix', () {
    test('removeDevice cancels establish-fallback timer and cleans up caches', () async {
      final d = _device();
      final (provider, fake) = await _build(devices: [d]);

      // Remove before the established event arrives — timer was armed.
      await provider.removeDevice(d.id);
      await pumpEventQueue();

      // Device is fully removed; timer was cancelled so no dangling lookup fires.
      expect(provider.devices, isEmpty);
      expect(provider.liveDataFor(d.id), isNull);
      expect(fake.stoppedSubscriptions, contains(d.nodeId));
    });
  });
}
