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

/// What kind of thing a device is, and therefore what `node_id` means for it.
///
/// A device is identified by the PAIR (kind, node_id) — two selection criteria,
/// neither sufficient alone. node_id is scoped to its kind's namespace:
///   DEVICE_KIND_MATTER — a real Matter operational node ID on our fabric.
///   DEVICE_KIND_MODBUS — a controller-assigned id for a polled Modbus device.
///   DEVICE_KIND_CLOUD  — a controller-assigned id for a cloud-API appliance.
///
/// This replaces inferring the kind from the magnitude of node_id. Synthetic
/// devices used to be handed Matter node IDs above a reserved base
/// (0x0100000000000000) and every consumer re-derived "is this really a Matter
/// node?" from that constant — which was duplicated across three repos, was
/// already stale and wrong in one of them, and forced a cross-repo rule that
/// bit 63 stay clear because the app decodes node_id into a signed integer.
/// With kind carried explicitly none of that is needed: the reserved range and
/// the bit-63 rule are both gone, and each namespace can number from 1.
class DeviceKind extends $pb.ProtobufEnum {
  static const DeviceKind DEVICE_KIND_UNKNOWN =
      DeviceKind._(0, _omitEnumNames ? '' : 'DEVICE_KIND_UNKNOWN');
  static const DeviceKind DEVICE_KIND_MATTER =
      DeviceKind._(1, _omitEnumNames ? '' : 'DEVICE_KIND_MATTER');
  static const DeviceKind DEVICE_KIND_MODBUS =
      DeviceKind._(2, _omitEnumNames ? '' : 'DEVICE_KIND_MODBUS');
  static const DeviceKind DEVICE_KIND_CLOUD =
      DeviceKind._(3, _omitEnumNames ? '' : 'DEVICE_KIND_CLOUD');

  static const $core.List<DeviceKind> values = <DeviceKind>[
    DEVICE_KIND_UNKNOWN,
    DEVICE_KIND_MATTER,
    DEVICE_KIND_MODBUS,
    DEVICE_KIND_CLOUD,
  ];

  static final $core.List<DeviceKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DeviceKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceKind._(super.value, super.name);
}

/// What the user says a device IS, in energy terms. Deliberately finer than
/// EnergyClass: a car charger and a heat pump are both `load` to the energy log,
/// but they are not the same thing to the person assigning them, and storing only
/// the coarse class would force the app to keep its own copy of the distinction —
/// which is exactly the split that let rooms and roles drift out of sync.
/// The controller derives the EnergyClass from this when classifying a reading.
class EnergyRole extends $pb.ProtobufEnum {
  static const EnergyRole ENERGY_ROLE_UNSPECIFIED =
      EnergyRole._(0, _omitEnumNames ? '' : 'ENERGY_ROLE_UNSPECIFIED');
  static const EnergyRole ENERGY_ROLE_GRID =
      EnergyRole._(1, _omitEnumNames ? '' : 'ENERGY_ROLE_GRID');
  static const EnergyRole ENERGY_ROLE_PV =
      EnergyRole._(2, _omitEnumNames ? '' : 'ENERGY_ROLE_PV');
  static const EnergyRole ENERGY_ROLE_CAR_CHARGER =
      EnergyRole._(3, _omitEnumNames ? '' : 'ENERGY_ROLE_CAR_CHARGER');
  static const EnergyRole ENERGY_ROLE_HEAT_PUMP =
      EnergyRole._(4, _omitEnumNames ? '' : 'ENERGY_ROLE_HEAT_PUMP');
  static const EnergyRole ENERGY_ROLE_HOME_BATTERY =
      EnergyRole._(5, _omitEnumNames ? '' : 'ENERGY_ROLE_HOME_BATTERY');

  /// A consumer with no more specific role. Not offered in the app's picker —
  /// it is where a pre-rooms role override lands, whose stored form was the
  /// coarse class and so cannot say which kind of consumer it was.
  static const EnergyRole ENERGY_ROLE_LOAD =
      EnergyRole._(6, _omitEnumNames ? '' : 'ENERGY_ROLE_LOAD');

  static const $core.List<EnergyRole> values = <EnergyRole>[
    ENERGY_ROLE_UNSPECIFIED,
    ENERGY_ROLE_GRID,
    ENERGY_ROLE_PV,
    ENERGY_ROLE_CAR_CHARGER,
    ENERGY_ROLE_HEAT_PUMP,
    ENERGY_ROLE_HOME_BATTERY,
    ENERGY_ROLE_LOAD,
  ];

  static final $core.List<EnergyRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static EnergyRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EnergyRole._(super.value, super.name);
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

/// Canonical internal price unit is micro-euro per kWh (µEUR/kWh):
///   1 EUR/MWh = 1000 µEUR/kWh ;  ct/kWh = µEUR/kWh / 10000.
/// Signed — EPEX day-ahead prices can be negative.
class PriceUnit extends $pb.ProtobufEnum {
  static const PriceUnit PRICE_UNIT_UEUR_PER_KWH =
      PriceUnit._(0, _omitEnumNames ? '' : 'PRICE_UNIT_UEUR_PER_KWH');
  static const PriceUnit PRICE_UNIT_EUR_PER_MWH =
      PriceUnit._(1, _omitEnumNames ? '' : 'PRICE_UNIT_EUR_PER_MWH');

  static const $core.List<PriceUnit> values = <PriceUnit>[
    PRICE_UNIT_UEUR_PER_KWH,
    PRICE_UNIT_EUR_PER_MWH,
  ];

  static final $core.List<PriceUnit?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PriceUnit? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PriceUnit._(super.value, super.name);
}

/// POST /remote/signal — one MAC'd offer/answer/candidate (ADR-0003/0005/0006).
/// Our impl (libjuice, ADR-0013) carries the opaque SDP description/candidate.
class IceSignalKind extends $pb.ProtobufEnum {
  static const IceSignalKind ICE_OFFER =
      IceSignalKind._(0, _omitEnumNames ? '' : 'ICE_OFFER');
  static const IceSignalKind ICE_ANSWER =
      IceSignalKind._(1, _omitEnumNames ? '' : 'ICE_ANSWER');
  static const IceSignalKind ICE_CANDIDATE =
      IceSignalKind._(2, _omitEnumNames ? '' : 'ICE_CANDIDATE');

  static const $core.List<IceSignalKind> values = <IceSignalKind>[
    ICE_OFFER,
    ICE_ANSWER,
    ICE_CANDIDATE,
  ];

  static final $core.List<IceSignalKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static IceSignalKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const IceSignalKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
