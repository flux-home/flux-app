// This is a generated file - do not edit.
//
// Generated from flux.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Connection lifecycle stages reported by the controller for each device.
class ConnectivityState extends $pb.ProtobufEnum {
  static const ConnectivityState CONNECTIVITY_UNKNOWN =
      ConnectivityState._(0, _omitEnumNames ? '' : 'CONNECTIVITY_UNKNOWN');
  static const ConnectivityState CONNECTIVITY_DISCOVERING =
      ConnectivityState._(1, _omitEnumNames ? '' : 'CONNECTIVITY_DISCOVERING');
  static const ConnectivityState CONNECTIVITY_SUBSCRIBED =
      ConnectivityState._(2, _omitEnumNames ? '' : 'CONNECTIVITY_SUBSCRIBED');
  static const ConnectivityState CONNECTIVITY_RETRYING =
      ConnectivityState._(3, _omitEnumNames ? '' : 'CONNECTIVITY_RETRYING');

  static const $core.List<ConnectivityState> values = <ConnectivityState>[
    CONNECTIVITY_UNKNOWN,
    CONNECTIVITY_DISCOVERING,
    CONNECTIVITY_SUBSCRIBED,
    CONNECTIVITY_RETRYING,
  ];

  static final $core.List<ConnectivityState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ConnectivityState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ConnectivityState._(super.value, super.name);
}

/// Register-map profile that tells the controller how to decode a device.
/// (SUNSPEC stays 0 for wire/NVS compatibility; UNKNOWN is discovery-only.)
class ModbusProfile extends $pb.ProtobufEnum {
  static const ModbusProfile MODBUS_PROFILE_SUNSPEC =
      ModbusProfile._(0, _omitEnumNames ? '' : 'MODBUS_PROFILE_SUNSPEC');
  static const ModbusProfile MODBUS_PROFILE_UNKNOWN =
      ModbusProfile._(1, _omitEnumNames ? '' : 'MODBUS_PROFILE_UNKNOWN');

  /// (discovery result only — not decodable)
  static const ModbusProfile MODBUS_PROFILE_VM3P75CT =
      ModbusProfile._(2, _omitEnumNames ? '' : 'MODBUS_PROFILE_VM3P75CT');

  static const $core.List<ModbusProfile> values = <ModbusProfile>[
    MODBUS_PROFILE_SUNSPEC,
    MODBUS_PROFILE_UNKNOWN,
    MODBUS_PROFILE_VM3P75CT,
  ];

  static final $core.List<ModbusProfile?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ModbusProfile? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModbusProfile._(super.value, super.name);
}

/// Transport for a Modbus device. TCP is the default; some meters (e.g. the
/// VM-3P75CT) speak Modbus over UDP.
class ModbusTransport extends $pb.ProtobufEnum {
  static const ModbusTransport MODBUS_TRANSPORT_TCP =
      ModbusTransport._(0, _omitEnumNames ? '' : 'MODBUS_TRANSPORT_TCP');
  static const ModbusTransport MODBUS_TRANSPORT_UDP =
      ModbusTransport._(1, _omitEnumNames ? '' : 'MODBUS_TRANSPORT_UDP');

  static const $core.List<ModbusTransport> values = <ModbusTransport>[
    MODBUS_TRANSPORT_TCP,
    MODBUS_TRANSPORT_UDP,
  ];

  static final $core.List<ModbusTransport?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ModbusTransport? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModbusTransport._(super.value, super.name);
}

class DeviceEventType extends $pb.ProtobufEnum {
  static const DeviceEventType DEVICE_EVENT_ESTABLISHED =
      DeviceEventType._(0, _omitEnumNames ? '' : 'DEVICE_EVENT_ESTABLISHED');
  static const DeviceEventType DEVICE_EVENT_ATTRS_UPDATE =
      DeviceEventType._(1, _omitEnumNames ? '' : 'DEVICE_EVENT_ATTRS_UPDATE');
  static const DeviceEventType DEVICE_EVENT_ERROR =
      DeviceEventType._(2, _omitEnumNames ? '' : 'DEVICE_EVENT_ERROR');
  static const DeviceEventType DEVICE_EVENT_RESUBSCRIBING =
      DeviceEventType._(3, _omitEnumNames ? '' : 'DEVICE_EVENT_RESUBSCRIBING');
  static const DeviceEventType DEVICE_EVENT_DISCOVERING =
      DeviceEventType._(4, _omitEnumNames ? '' : 'DEVICE_EVENT_DISCOVERING');

  static const $core.List<DeviceEventType> values = <DeviceEventType>[
    DEVICE_EVENT_ESTABLISHED,
    DEVICE_EVENT_ATTRS_UPDATE,
    DEVICE_EVENT_ERROR,
    DEVICE_EVENT_RESUBSCRIBING,
    DEVICE_EVENT_DISCOVERING,
  ];

  static final $core.List<DeviceEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static DeviceEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceEventType._(super.value, super.name);
}

/// ─── Energy history ─────────────────────────────────────────────────────────
/// GET /energy/history?from=<epoch_s>&to=<epoch_s>&bucket=<seconds>
/// Energy usage aggregated into fixed-width time buckets, derived by differencing
/// the cumulative OBIS counters (1.8.0 import / 2.8.0 export) at each bucket edge
/// — with a fallback to integrating active power for devices that expose no
/// counter. Values are watt-hours (Wh) per bucket, SUMMED per device class.
/// Bounded per response (see truncated); page long spans by narrowing [from,to]
/// or widening bucket. Default bucket is 900 s (15 min).
class EnergyClass extends $pb.ProtobufEnum {
  static const EnergyClass ENERGY_CLASS_UNKNOWN =
      EnergyClass._(0, _omitEnumNames ? '' : 'ENERGY_CLASS_UNKNOWN');
  static const EnergyClass ENERGY_CLASS_GRID =
      EnergyClass._(1, _omitEnumNames ? '' : 'ENERGY_CLASS_GRID');
  static const EnergyClass ENERGY_CLASS_PV =
      EnergyClass._(2, _omitEnumNames ? '' : 'ENERGY_CLASS_PV');
  static const EnergyClass ENERGY_CLASS_LOAD =
      EnergyClass._(3, _omitEnumNames ? '' : 'ENERGY_CLASS_LOAD');
  static const EnergyClass ENERGY_CLASS_BATTERY =
      EnergyClass._(4, _omitEnumNames ? '' : 'ENERGY_CLASS_BATTERY');

  static const $core.List<EnergyClass> values = <EnergyClass>[
    ENERGY_CLASS_UNKNOWN,
    ENERGY_CLASS_GRID,
    ENERGY_CLASS_PV,
    ENERGY_CLASS_LOAD,
    ENERGY_CLASS_BATTERY,
  ];

  static final $core.List<EnergyClass?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static EnergyClass? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EnergyClass._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
