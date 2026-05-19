import 'dart:async';

import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/services/matter_port.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeviceControlService
//
// Owns all device-command execution: on/off toggle, brightness, covering,
// fan, colour temperature, thermostat, and automation-action dispatch.
//
// Callers pass callbacks to get and set live-cache entries and to look up
// the device record — the service has no direct reference to DeviceProvider's
// private fields.
// ─────────────────────────────────────────────────────────────────────────────

class DeviceControlService {
  DeviceControlService({
    required MatterPort channel,
    required MatterDevice? Function(String deviceId) deviceGetter,
    required DeviceLiveData? Function(String deviceId) liveGetter,
    required void Function(String deviceId, DeviceLiveData Function(DeviceLiveData) t) mergeCache,
    required Future<void> Function(String deviceId) flushSnapshot,
  })  : _channel      = channel,
        _deviceGetter = deviceGetter,
        _liveGetter   = liveGetter,
        _mergeCache   = mergeCache,
        _flushSnapshot = flushSnapshot;

  final MatterPort _channel;
  final MatterDevice?      Function(String) _deviceGetter;
  final DeviceLiveData?    Function(String) _liveGetter;
  final void Function(String, DeviceLiveData Function(DeviceLiveData)) _mergeCache;
  final Future<void>       Function(String) _flushSnapshot;

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> toggle(String deviceId) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final hasOnOff = device.deviceType.hasOnOff ||
        (_liveGetter(deviceId)?.attrs.containsKey('onOff') ?? false);
    if (!hasOnOff) return;
    final currentOn = _liveGetter(deviceId)?.isOn ?? false;
    final newOn     = !currentOn;
    _mergeCache(deviceId, (e) => e.merge({'onOff': newOn}));
    final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
    if (ok) {
      await _flushSnapshot(deviceId);
    } else {
      _mergeCache(deviceId, (e) => e.merge({'onOff': currentOn}));
    }
  }

  Future<void> setBrightness(String deviceId, double value) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final level    = (value * 254).round().clamp(0, 254);
    final prevLevel = _liveGetter(deviceId)?.levelRaw;
    _mergeCache(deviceId, (e) => e.merge({'level': level}));
    final ok = await _channel.setLevel(device.nodeId, level);
    if (ok) { await _flushSnapshot(deviceId); }
    else if (prevLevel != null) { _mergeCache(deviceId, (e) => e.merge({'level': prevLevel})); }
  }

  Future<void> stepBrightness(String deviceId, {required bool up}) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final hasBrightness = device.deviceType.hasBrightness ||
        (_liveGetter(deviceId)?.attrs.containsKey('level') ?? false);
    if (!hasBrightness) return;
    await _channel.stepLevel(device.nodeId, stepUp: up);
  }

  Future<void> coveringUp(String deviceId)   async { final d = _deviceGetter(deviceId); if (d != null) await _channel.coveringUp(d.nodeId); }
  Future<void> coveringDown(String deviceId) async { final d = _deviceGetter(deviceId); if (d != null) await _channel.coveringDown(d.nodeId); }
  Future<void> coveringStop(String deviceId) async { final d = _deviceGetter(deviceId); if (d != null) await _channel.coveringStop(d.nodeId); }

  Future<void> coveringGoToLift(String deviceId, int percent100ths) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final prev = _liveGetter(deviceId)?.liftPercent100ths;
    _mergeCache(deviceId, (e) => e.merge({'liftPercent100ths': percent100ths}));
    final ok = await _channel.coveringGoToLift(device.nodeId, percent100ths);
    if (!ok && prev != null) _mergeCache(deviceId, (e) => e.merge({'liftPercent100ths': prev}));
  }

  Future<void> setFanMode(String deviceId, int mode) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final prev = _liveGetter(deviceId)?.fanMode;
    _mergeCache(deviceId, (e) => e.merge({'fanMode': mode}));
    final ok = await _channel.setFanMode(device.nodeId, mode);
    if (!ok && prev != null) _mergeCache(deviceId, (e) => e.merge({'fanMode': prev}));
  }

  Future<void> setFanPercent(String deviceId, int percent) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final prev = _liveGetter(deviceId)?.fanPercent;
    _mergeCache(deviceId, (e) => e.merge({'fanPercent': percent}));
    final ok = await _channel.setFanPercent(device.nodeId, percent);
    if (!ok && prev != null) _mergeCache(deviceId, (e) => e.merge({'fanPercent': prev}));
  }

  Future<void> setColorTemperature(String deviceId, int mireds) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final prev = _liveGetter(deviceId)?.colorTempMireds;
    _mergeCache(deviceId, (e) => e.merge({'colorTempMireds': mireds}));
    final ok = await _channel.setColorTemperature(device.nodeId, mireds);
    if (!ok && prev != null) _mergeCache(deviceId, (e) => e.merge({'colorTempMireds': prev}));
  }

  // ── Automation action execution ────────────────────────────────────────────

  Future<void> executeAction(String deviceId, AutomationAction action) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    switch (action) {
      case AutomationAction.toggle:
        if (device.deviceType == DeviceType.thermostat ||
            (_liveGetter(deviceId)?.attrs.containsKey('systemMode') ?? false)) {
          final cur  = _liveGetter(deviceId)?.systemMode ?? 0;
          final next = cur == 0 ? 4 : 0;
          _mergeCache(deviceId, (e) => e.merge({'systemMode': next}));
          await _channel.writeSystemMode(device.nodeId, next);
        } else {
          await toggle(deviceId);
        }
      case AutomationAction.turnOn:
        _mergeCache(deviceId, (e) => e.merge({'onOff': true}));
        await _channel.toggleDevice(device.nodeId, on: true);
      case AutomationAction.turnOff:
        _mergeCache(deviceId, (e) => e.merge({'onOff': false}));
        await _channel.toggleDevice(device.nodeId, on: false);
      case AutomationAction.thermostatOff:
        _mergeCache(deviceId, (e) => e.merge({'systemMode': 0}));
        await _channel.writeSystemMode(device.nodeId, 0);
      case AutomationAction.brightnessStepUp:
        await stepBrightness(deviceId, up: true);
      case AutomationAction.brightnessStepDown:
        await stepBrightness(deviceId, up: false);
      case AutomationAction.thermostatSetpointUp:
        await _adjustSetpoint(deviceId, 1.0);
      case AutomationAction.thermostatSetpointDown:
        await _adjustSetpoint(deviceId, -1.0);
    }
  }

  Future<void> _adjustSetpoint(String deviceId, double deltaCelsius) async {
    final device = _deviceGetter(deviceId);
    if (device == null) return;
    final currentMode = _liveGetter(deviceId)?.systemMode;
    if (currentMode == null || currentMode == 0) {
      _mergeCache(deviceId, (e) => e.merge({'systemMode': 4}));
      await _channel.writeSystemMode(device.nodeId, 4);
    }
    const defaultCenti = 2000;
    final current = _liveGetter(deviceId)?.heatingSetptCenti ?? defaultCenti;
    final next    = (current + (deltaCelsius * 100).round()).clamp(500, 3500);
    _mergeCache(deviceId, (e) => e.merge({'heatingSetptCenti': next}));
    await _channel.writeHeatingSetpoint(device.nodeId, next);
  }
}
