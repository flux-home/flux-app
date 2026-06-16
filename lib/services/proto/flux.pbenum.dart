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

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
