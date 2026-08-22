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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'flux.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'flux.pbenum.dart';

/// GET /info
class ControllerInfo extends $pb.GeneratedMessage {
  factory ControllerInfo({
    $core.String? firmwareVersion,
    $core.String? hostname,
    $core.String? ethernetIp,
    $core.bool? ethernetUp,
    $fixnum.Int64? fabricId,
    $core.int? uptimeSeconds,
    $core.String? serialNumber,
  }) {
    final result = create();
    if (firmwareVersion != null) result.firmwareVersion = firmwareVersion;
    if (hostname != null) result.hostname = hostname;
    if (ethernetIp != null) result.ethernetIp = ethernetIp;
    if (ethernetUp != null) result.ethernetUp = ethernetUp;
    if (fabricId != null) result.fabricId = fabricId;
    if (uptimeSeconds != null) result.uptimeSeconds = uptimeSeconds;
    if (serialNumber != null) result.serialNumber = serialNumber;
    return result;
  }

  ControllerInfo._();

  factory ControllerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControllerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControllerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firmwareVersion')
    ..aOS(2, _omitFieldNames ? '' : 'hostname')
    ..aOS(3, _omitFieldNames ? '' : 'ethernetIp')
    ..aOB(4, _omitFieldNames ? '' : 'ethernetUp')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'fabricId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(6, _omitFieldNames ? '' : 'uptimeSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(7, _omitFieldNames ? '' : 'serialNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControllerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControllerInfo copyWith(void Function(ControllerInfo) updates) =>
      super.copyWith((message) => updates(message as ControllerInfo))
          as ControllerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControllerInfo create() => ControllerInfo._();
  @$core.override
  ControllerInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControllerInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControllerInfo>(create);
  static ControllerInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get firmwareVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set firmwareVersion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirmwareVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirmwareVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostname => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostname() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get ethernetIp => $_getSZ(2);
  @$pb.TagNumber(3)
  set ethernetIp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEthernetIp() => $_has(2);
  @$pb.TagNumber(3)
  void clearEthernetIp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get ethernetUp => $_getBF(3);
  @$pb.TagNumber(4)
  set ethernetUp($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEthernetUp() => $_has(3);
  @$pb.TagNumber(4)
  void clearEthernetUp() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get fabricId => $_getI64(4);
  @$pb.TagNumber(5)
  set fabricId($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFabricId() => $_has(4);
  @$pb.TagNumber(5)
  void clearFabricId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get uptimeSeconds => $_getIZ(5);
  @$pb.TagNumber(6)
  set uptimeSeconds($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUptimeSeconds() => $_has(5);
  @$pb.TagNumber(6)
  void clearUptimeSeconds() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get serialNumber => $_getSZ(6);
  @$pb.TagNumber(7)
  set serialNumber($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSerialNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearSerialNumber() => $_clearField(7);
}

/// GET /thread/dataset  POST /thread/dataset
class ThreadDataset extends $pb.GeneratedMessage {
  factory ThreadDataset({
    $core.List<$core.int>? tlv,
    $core.String? networkName,
    $core.int? channel,
    $core.int? panId,
    $core.String? role,
    $core.int? neighborCount,
    $core.int? rloc16,
    $core.int? partitionId,
  }) {
    final result = create();
    if (tlv != null) result.tlv = tlv;
    if (networkName != null) result.networkName = networkName;
    if (channel != null) result.channel = channel;
    if (panId != null) result.panId = panId;
    if (role != null) result.role = role;
    if (neighborCount != null) result.neighborCount = neighborCount;
    if (rloc16 != null) result.rloc16 = rloc16;
    if (partitionId != null) result.partitionId = partitionId;
    return result;
  }

  ThreadDataset._();

  factory ThreadDataset.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadDataset.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadDataset',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'tlv', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'networkName')
    ..aI(3, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'panId', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'role')
    ..aI(6, _omitFieldNames ? '' : 'neighborCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'rloc16', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'partitionId',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadDataset clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadDataset copyWith(void Function(ThreadDataset) updates) =>
      super.copyWith((message) => updates(message as ThreadDataset))
          as ThreadDataset;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadDataset create() => ThreadDataset._();
  @$core.override
  ThreadDataset createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadDataset getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadDataset>(create);
  static ThreadDataset? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get tlv => $_getN(0);
  @$pb.TagNumber(1)
  set tlv($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTlv() => $_has(0);
  @$pb.TagNumber(1)
  void clearTlv() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get networkName => $_getSZ(1);
  @$pb.TagNumber(2)
  set networkName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNetworkName() => $_has(1);
  @$pb.TagNumber(2)
  void clearNetworkName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get channel => $_getIZ(2);
  @$pb.TagNumber(3)
  set channel($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChannel() => $_has(2);
  @$pb.TagNumber(3)
  void clearChannel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get panId => $_getIZ(3);
  @$pb.TagNumber(4)
  set panId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPanId() => $_has(3);
  @$pb.TagNumber(4)
  void clearPanId() => $_clearField(4);

  /// diagnostics (read-only, populated on GET)
  @$pb.TagNumber(5)
  $core.String get role => $_getSZ(4);
  @$pb.TagNumber(5)
  set role($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearRole() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get neighborCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set neighborCount($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNeighborCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearNeighborCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get rloc16 => $_getIZ(6);
  @$pb.TagNumber(7)
  set rloc16($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRloc16() => $_has(6);
  @$pb.TagNumber(7)
  void clearRloc16() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get partitionId => $_getIZ(7);
  @$pb.TagNumber(8)
  set partitionId($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPartitionId() => $_has(7);
  @$pb.TagNumber(8)
  void clearPartitionId() => $_clearField(8);
}

/// POST /thread/epskc
/// Start Thread Credential Sharing (Thread 1.4).  The Border Router generates a
/// one-time passcode (OTPC) and starts the ephemeral PSKc session.  A commissioner
/// candidate (phone app) can then discover the Border Router via _meshcop-e._udp
/// DNS-SD, connect over DTLS using the returned OTPC, and retrieve Thread credentials.
/// DELETE /thread/epskc stops an active session.
/// GET    /thread/epskc returns the current ephemeral key manager state.
class ThreadEphemeralKeyRequest extends $pb.GeneratedMessage {
  factory ThreadEphemeralKeyRequest({
    $core.int? timeoutSeconds,
  }) {
    final result = create();
    if (timeoutSeconds != null) result.timeoutSeconds = timeoutSeconds;
    return result;
  }

  ThreadEphemeralKeyRequest._();

  factory ThreadEphemeralKeyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadEphemeralKeyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadEphemeralKeyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'timeoutSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralKeyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralKeyRequest copyWith(
          void Function(ThreadEphemeralKeyRequest) updates) =>
      super.copyWith((message) => updates(message as ThreadEphemeralKeyRequest))
          as ThreadEphemeralKeyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralKeyRequest create() => ThreadEphemeralKeyRequest._();
  @$core.override
  ThreadEphemeralKeyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralKeyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadEphemeralKeyRequest>(create);
  static ThreadEphemeralKeyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get timeoutSeconds => $_getIZ(0);
  @$pb.TagNumber(1)
  set timeoutSeconds($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimeoutSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimeoutSeconds() => $_clearField(1);
}

class ThreadEphemeralKeyResult extends $pb.GeneratedMessage {
  factory ThreadEphemeralKeyResult({
    $core.bool? success,
    $core.String? otpc,
    $core.int? udpPort,
    $core.String? state,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (otpc != null) result.otpc = otpc;
    if (udpPort != null) result.udpPort = udpPort;
    if (state != null) result.state = state;
    if (error != null) result.error = error;
    return result;
  }

  ThreadEphemeralKeyResult._();

  factory ThreadEphemeralKeyResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadEphemeralKeyResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadEphemeralKeyResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'otpc')
    ..aI(3, _omitFieldNames ? '' : 'udpPort', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'state')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralKeyResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralKeyResult copyWith(
          void Function(ThreadEphemeralKeyResult) updates) =>
      super.copyWith((message) => updates(message as ThreadEphemeralKeyResult))
          as ThreadEphemeralKeyResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralKeyResult create() => ThreadEphemeralKeyResult._();
  @$core.override
  ThreadEphemeralKeyResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralKeyResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadEphemeralKeyResult>(create);
  static ThreadEphemeralKeyResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get otpc => $_getSZ(1);
  @$pb.TagNumber(2)
  set otpc($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOtpc() => $_has(1);
  @$pb.TagNumber(2)
  void clearOtpc() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get udpPort => $_getIZ(2);
  @$pb.TagNumber(3)
  set udpPort($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUdpPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearUdpPort() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get state => $_getSZ(3);
  @$pb.TagNumber(4)
  set state($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
}

/// POST /thread/join
/// Thread 1.4 credential sharing — JOIN side. flux acts as a MeshCoP commissioner
/// against a foreign Border Router's ephemeral-key (ePSKc) session: connects over
/// DTLS (EC-JPAKE, password = the ephemeral key), retrieves the Active Operational
/// Dataset, and returns it. With apply/migrate set, flux also adopts the network.
/// target_addr/port identify the foreign Border Agent (discoverable via
/// _meshcop-e._udp); ephemeral_key is the code shown by that ecosystem's app.
class ThreadJoinRequest extends $pb.GeneratedMessage {
  factory ThreadJoinRequest({
    $core.String? targetAddr,
    $core.int? targetPort,
    $core.String? ephemeralKey,
    $core.bool? apply,
    $core.bool? migrate,
    $core.int? delayMs,
  }) {
    final result = create();
    if (targetAddr != null) result.targetAddr = targetAddr;
    if (targetPort != null) result.targetPort = targetPort;
    if (ephemeralKey != null) result.ephemeralKey = ephemeralKey;
    if (apply != null) result.apply = apply;
    if (migrate != null) result.migrate = migrate;
    if (delayMs != null) result.delayMs = delayMs;
    return result;
  }

  ThreadJoinRequest._();

  factory ThreadJoinRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadJoinRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadJoinRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'targetAddr')
    ..aI(2, _omitFieldNames ? '' : 'targetPort', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'ephemeralKey')
    ..aOB(4, _omitFieldNames ? '' : 'apply')
    ..aOB(5, _omitFieldNames ? '' : 'migrate')
    ..aI(6, _omitFieldNames ? '' : 'delayMs', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadJoinRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadJoinRequest copyWith(void Function(ThreadJoinRequest) updates) =>
      super.copyWith((message) => updates(message as ThreadJoinRequest))
          as ThreadJoinRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadJoinRequest create() => ThreadJoinRequest._();
  @$core.override
  ThreadJoinRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadJoinRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadJoinRequest>(create);
  static ThreadJoinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get targetAddr => $_getSZ(0);
  @$pb.TagNumber(1)
  set targetAddr($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetAddr() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get targetPort => $_getIZ(1);
  @$pb.TagNumber(2)
  set targetPort($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get ephemeralKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set ephemeralKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEphemeralKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearEphemeralKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get apply => $_getBF(3);
  @$pb.TagNumber(4)
  set apply($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasApply() => $_has(3);
  @$pb.TagNumber(4)
  void clearApply() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get migrate => $_getBF(4);
  @$pb.TagNumber(5)
  set migrate($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMigrate() => $_has(4);
  @$pb.TagNumber(5)
  void clearMigrate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get delayMs => $_getIZ(5);
  @$pb.TagNumber(6)
  set delayMs($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDelayMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearDelayMs() => $_clearField(6);
}

class ThreadJoinResult extends $pb.GeneratedMessage {
  factory ThreadJoinResult({
    $core.bool? success,
    $core.List<$core.int>? tlv,
    $core.String? networkName,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (tlv != null) result.tlv = tlv;
    if (networkName != null) result.networkName = networkName;
    if (error != null) result.error = error;
    return result;
  }

  ThreadJoinResult._();

  factory ThreadJoinResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadJoinResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadJoinResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'tlv', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'networkName')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadJoinResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadJoinResult copyWith(void Function(ThreadJoinResult) updates) =>
      super.copyWith((message) => updates(message as ThreadJoinResult))
          as ThreadJoinResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadJoinResult create() => ThreadJoinResult._();
  @$core.override
  ThreadJoinResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadJoinResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadJoinResult>(create);
  static ThreadJoinResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get tlv => $_getN(1);
  @$pb.TagNumber(2)
  set tlv($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTlv() => $_has(1);
  @$pb.TagNumber(2)
  void clearTlv() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get networkName => $_getSZ(2);
  @$pb.TagNumber(3)
  set networkName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNetworkName() => $_has(2);
  @$pb.TagNumber(3)
  void clearNetworkName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

/// GET /thread/join
/// List foreign Border Agents currently advertising a Thread 1.4 ephemeral-key
/// session (_meshcop-e._udp) — only present while the other ecosystem's Thread-
/// sharing sheet is open. The controller (the OTBR on the mesh) browses for them.
/// The app can show these to the user; then POST /thread/join with the code
/// (target_addr optional — the controller re-discovers/auto-picks if omitted).
class ThreadEphemeralCandidate extends $pb.GeneratedMessage {
  factory ThreadEphemeralCandidate({
    $core.String? addr,
    $core.int? port,
    $core.String? name,
  }) {
    final result = create();
    if (addr != null) result.addr = addr;
    if (port != null) result.port = port;
    if (name != null) result.name = name;
    return result;
  }

  ThreadEphemeralCandidate._();

  factory ThreadEphemeralCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadEphemeralCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadEphemeralCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'addr')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralCandidate copyWith(
          void Function(ThreadEphemeralCandidate) updates) =>
      super.copyWith((message) => updates(message as ThreadEphemeralCandidate))
          as ThreadEphemeralCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralCandidate create() => ThreadEphemeralCandidate._();
  @$core.override
  ThreadEphemeralCandidate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralCandidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadEphemeralCandidate>(create);
  static ThreadEphemeralCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get addr => $_getSZ(0);
  @$pb.TagNumber(1)
  set addr($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddr() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);
}

class ThreadEphemeralList extends $pb.GeneratedMessage {
  factory ThreadEphemeralList({
    $core.Iterable<ThreadEphemeralCandidate>? candidates,
  }) {
    final result = create();
    if (candidates != null) result.candidates.addAll(candidates);
    return result;
  }

  ThreadEphemeralList._();

  factory ThreadEphemeralList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThreadEphemeralList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadEphemeralList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..pPM<ThreadEphemeralCandidate>(1, _omitFieldNames ? '' : 'candidates',
        subBuilder: ThreadEphemeralCandidate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadEphemeralList copyWith(void Function(ThreadEphemeralList) updates) =>
      super.copyWith((message) => updates(message as ThreadEphemeralList))
          as ThreadEphemeralList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralList create() => ThreadEphemeralList._();
  @$core.override
  ThreadEphemeralList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThreadEphemeralList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadEphemeralList>(create);
  static ThreadEphemeralList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ThreadEphemeralCandidate> get candidates => $_getList(0);
}

/// POST /devices/commissioning-window
/// Open an Administrator Commissioning (ECM) window on a device this controller
/// already commissioned, so ANOTHER admin/ecosystem can commission it too
/// (Matter multi-admin). The controller generates the passcode + PAKE verifier,
/// opens the window on the device (AdministratorCommissioning 0x3C), and returns
/// the manual pairing code to hand to the other ecosystem.
class OpenCommissioningWindowRequest extends $pb.GeneratedMessage {
  factory OpenCommissioningWindowRequest({
    $fixnum.Int64? nodeId,
    $core.int? timeoutS,
    $core.int? iterations,
    $core.int? discriminator,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (timeoutS != null) result.timeoutS = timeoutS;
    if (iterations != null) result.iterations = iterations;
    if (discriminator != null) result.discriminator = discriminator;
    return result;
  }

  OpenCommissioningWindowRequest._();

  factory OpenCommissioningWindowRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OpenCommissioningWindowRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenCommissioningWindowRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(2, _omitFieldNames ? '' : 'timeoutS', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'iterations', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'discriminator',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenCommissioningWindowRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenCommissioningWindowRequest copyWith(
          void Function(OpenCommissioningWindowRequest) updates) =>
      super.copyWith(
              (message) => updates(message as OpenCommissioningWindowRequest))
          as OpenCommissioningWindowRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OpenCommissioningWindowRequest create() =>
      OpenCommissioningWindowRequest._();
  @$core.override
  OpenCommissioningWindowRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OpenCommissioningWindowRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenCommissioningWindowRequest>(create);
  static OpenCommissioningWindowRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get timeoutS => $_getIZ(1);
  @$pb.TagNumber(2)
  set timeoutS($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimeoutS() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimeoutS() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get iterations => $_getIZ(2);
  @$pb.TagNumber(3)
  set iterations($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIterations() => $_has(2);
  @$pb.TagNumber(3)
  void clearIterations() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get discriminator => $_getIZ(3);
  @$pb.TagNumber(4)
  set discriminator($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDiscriminator() => $_has(3);
  @$pb.TagNumber(4)
  void clearDiscriminator() => $_clearField(4);
}

class OpenCommissioningWindowResult extends $pb.GeneratedMessage {
  factory OpenCommissioningWindowResult({
    $core.bool? success,
    $core.String? manualCode,
    $core.int? discriminator,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (manualCode != null) result.manualCode = manualCode;
    if (discriminator != null) result.discriminator = discriminator;
    if (error != null) result.error = error;
    return result;
  }

  OpenCommissioningWindowResult._();

  factory OpenCommissioningWindowResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OpenCommissioningWindowResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenCommissioningWindowResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'manualCode')
    ..aI(3, _omitFieldNames ? '' : 'discriminator',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenCommissioningWindowResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenCommissioningWindowResult copyWith(
          void Function(OpenCommissioningWindowResult) updates) =>
      super.copyWith(
              (message) => updates(message as OpenCommissioningWindowResult))
          as OpenCommissioningWindowResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OpenCommissioningWindowResult create() =>
      OpenCommissioningWindowResult._();
  @$core.override
  OpenCommissioningWindowResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OpenCommissioningWindowResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenCommissioningWindowResult>(create);
  static OpenCommissioningWindowResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get manualCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set manualCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasManualCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearManualCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get discriminator => $_getIZ(2);
  @$pb.TagNumber(3)
  set discriminator($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDiscriminator() => $_has(2);
  @$pb.TagNumber(3)
  void clearDiscriminator() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

/// POST /fabric/provision
/// App installs the controller's operational Matter identity.
/// All certs must be X.509 DER encoded; the CHIP stack converts them to Matter TLV
/// internally.  The NOC subject must encode node_id 0x0002 and the fabric_id;
/// node_id/fabric_id fields here are advisory only.
class FabricProvision extends $pb.GeneratedMessage {
  factory FabricProvision({
    $fixnum.Int64? fabricId,
    $fixnum.Int64? nodeId,
    $core.List<$core.int>? rootCaTlv,
    $core.List<$core.int>? icacTlv,
    $core.List<$core.int>? nocTlv,
    $core.List<$core.int>? opPrivKey,
    $core.List<$core.int>? ipk,
    $core.int? vendorId,
    $core.List<$core.int>? rcacPrivKey,
  }) {
    final result = create();
    if (fabricId != null) result.fabricId = fabricId;
    if (nodeId != null) result.nodeId = nodeId;
    if (rootCaTlv != null) result.rootCaTlv = rootCaTlv;
    if (icacTlv != null) result.icacTlv = icacTlv;
    if (nocTlv != null) result.nocTlv = nocTlv;
    if (opPrivKey != null) result.opPrivKey = opPrivKey;
    if (ipk != null) result.ipk = ipk;
    if (vendorId != null) result.vendorId = vendorId;
    if (rcacPrivKey != null) result.rcacPrivKey = rcacPrivKey;
    return result;
  }

  FabricProvision._();

  factory FabricProvision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FabricProvision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FabricProvision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'fabricId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'rootCaTlv', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'icacTlv', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'nocTlv', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'opPrivKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'ipk', $pb.PbFieldType.OY)
    ..aI(8, _omitFieldNames ? '' : 'vendorId', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'rcacPrivKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FabricProvision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FabricProvision copyWith(void Function(FabricProvision) updates) =>
      super.copyWith((message) => updates(message as FabricProvision))
          as FabricProvision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FabricProvision create() => FabricProvision._();
  @$core.override
  FabricProvision createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FabricProvision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FabricProvision>(create);
  static FabricProvision? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get fabricId => $_getI64(0);
  @$pb.TagNumber(1)
  set fabricId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFabricId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFabricId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get nodeId => $_getI64(1);
  @$pb.TagNumber(2)
  set nodeId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get rootCaTlv => $_getN(2);
  @$pb.TagNumber(3)
  set rootCaTlv($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRootCaTlv() => $_has(2);
  @$pb.TagNumber(3)
  void clearRootCaTlv() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get icacTlv => $_getN(3);
  @$pb.TagNumber(4)
  set icacTlv($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIcacTlv() => $_has(3);
  @$pb.TagNumber(4)
  void clearIcacTlv() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get nocTlv => $_getN(4);
  @$pb.TagNumber(5)
  set nocTlv($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNocTlv() => $_has(4);
  @$pb.TagNumber(5)
  void clearNocTlv() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get opPrivKey => $_getN(5);
  @$pb.TagNumber(6)
  set opPrivKey($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOpPrivKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearOpPrivKey() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get ipk => $_getN(6);
  @$pb.TagNumber(7)
  set ipk($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIpk() => $_has(6);
  @$pb.TagNumber(7)
  void clearIpk() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get vendorId => $_getIZ(7);
  @$pb.TagNumber(8)
  set vendorId($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVendorId() => $_has(7);
  @$pb.TagNumber(8)
  void clearVendorId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get rcacPrivKey => $_getN(8);
  @$pb.TagNumber(9)
  set rcacPrivKey($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRcacPrivKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearRcacPrivKey() => $_clearField(9);
}

/// Response to POST /fabric/provision
class FabricProvisionResult extends $pb.GeneratedMessage {
  factory FabricProvisionResult({
    $core.bool? success,
    $core.int? fabricIndex,
    $fixnum.Int64? compressedFabricId,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (fabricIndex != null) result.fabricIndex = fabricIndex;
    if (compressedFabricId != null)
      result.compressedFabricId = compressedFabricId;
    if (error != null) result.error = error;
    return result;
  }

  FabricProvisionResult._();

  factory FabricProvisionResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FabricProvisionResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FabricProvisionResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'fabricIndex',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'compressedFabricId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FabricProvisionResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FabricProvisionResult copyWith(
          void Function(FabricProvisionResult) updates) =>
      super.copyWith((message) => updates(message as FabricProvisionResult))
          as FabricProvisionResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FabricProvisionResult create() => FabricProvisionResult._();
  @$core.override
  FabricProvisionResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FabricProvisionResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FabricProvisionResult>(create);
  static FabricProvisionResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get fabricIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set fabricIndex($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFabricIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearFabricIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get compressedFabricId => $_getI64(2);
  @$pb.TagNumber(3)
  set compressedFabricId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCompressedFabricId() => $_has(2);
  @$pb.TagNumber(3)
  void clearCompressedFabricId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

/// POST /mfg/provision
/// Programs manufacturing-time secrets and identity into the controller.
/// At least one field must be present.  Safe to call multiple times (overwrites).
class MfgProvision extends $pb.GeneratedMessage {
  factory MfgProvision({
    $core.List<$core.int>? rcacPrivKey,
    $core.String? serialNumber,
    $core.List<$core.int>? rcacCertDer,
    $core.List<$core.int>? psk,
  }) {
    final result = create();
    if (rcacPrivKey != null) result.rcacPrivKey = rcacPrivKey;
    if (serialNumber != null) result.serialNumber = serialNumber;
    if (rcacCertDer != null) result.rcacCertDer = rcacCertDer;
    if (psk != null) result.psk = psk;
    return result;
  }

  MfgProvision._();

  factory MfgProvision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MfgProvision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MfgProvision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'rcacPrivKey', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'serialNumber')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'rcacCertDer', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'psk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MfgProvision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MfgProvision copyWith(void Function(MfgProvision) updates) =>
      super.copyWith((message) => updates(message as MfgProvision))
          as MfgProvision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MfgProvision create() => MfgProvision._();
  @$core.override
  MfgProvision createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MfgProvision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MfgProvision>(create);
  static MfgProvision? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get rcacPrivKey => $_getN(0);
  @$pb.TagNumber(1)
  set rcacPrivKey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRcacPrivKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearRcacPrivKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get serialNumber => $_getSZ(1);
  @$pb.TagNumber(2)
  set serialNumber($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSerialNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearSerialNumber() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get rcacCertDer => $_getN(2);
  @$pb.TagNumber(3)
  set rcacCertDer($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRcacCertDer() => $_has(2);
  @$pb.TagNumber(3)
  void clearRcacCertDer() => $_clearField(3);

  /// matter-rcac-id).  When present the controller uses this cert
  /// verbatim in the FabricTable instead of generating one via
  /// NewRootX509Cert (which encodes matter-rcac-id non-standardly).
  @$pb.TagNumber(4)
  $core.List<$core.int> get psk => $_getN(3);
  @$pb.TagNumber(4)
  set psk($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPsk() => $_has(3);
  @$pb.TagNumber(4)
  void clearPsk() => $_clearField(4);
}

class MfgProvisionResult extends $pb.GeneratedMessage {
  factory MfgProvisionResult({
    $core.bool? success,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    return result;
  }

  MfgProvisionResult._();

  factory MfgProvisionResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MfgProvisionResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MfgProvisionResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MfgProvisionResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MfgProvisionResult copyWith(void Function(MfgProvisionResult) updates) =>
      super.copyWith((message) => updates(message as MfgProvisionResult))
          as MfgProvisionResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MfgProvisionResult create() => MfgProvisionResult._();
  @$core.override
  MfgProvisionResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MfgProvisionResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MfgProvisionResult>(create);
  static MfgProvisionResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// POST /commission
/// Hand a commissionable device to the controller (standard Matter flow — the
/// controller does its own discovery, PASE and commissioning onto its *own*
/// fabric with its own CA, so no device CSR ever leaves the controller and
/// /fabric/sign-noc is not needed).  On success the controller has an
/// operational session and registers + subscribes the device itself (no
/// separate /node/register call required).  Two ways in:
///
///  * Direct handover (device already on the network): the user got a pairing
///    code from another ecosystem's share flow (multi-admin) or the device is
///    a factory-fresh on-network device.  The phone forwards the code's
///    passcode + discriminator verbatim — it never commissions the device
///    itself.  Manual 11-digit codes only carry the 4-bit short discriminator;
///    set short_discriminator so the controller matches on the high nibble.
///
///  * Commission-then-handoff (device needs network credentials): the phone
///    BLE-commissions the device onto a throwaway phone fabric, pushes the
///    hub's Thread credentials, opens an ECM window and forwards the window's
///    passcode + full 12-bit discriminator.  The phone then verifies the
///    device's Fabrics attribute shows fabric_id before removing its
///    throwaway fabric (RemoveFabric).  See docs/flows.md.
///
/// The controller locates the device itself: commissionable DNS-SD on the LAN,
/// plus its own SRP server table for devices on its Thread mesh (the OTBR's
/// SRP->mDNS proxy strips the discriminator/CM TXT, so the mDNS echo of its
/// own registrations is unusable — the SRP table is the authoritative source).
class CommissionRequest extends $pb.GeneratedMessage {
  factory CommissionRequest({
    $core.int? passcode,
    $core.int? discriminator,
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.int? vendorId,
    $core.int? productId,
    $core.int? deviceType,
    $core.bool? shortDiscriminator,
  }) {
    final result = create();
    if (passcode != null) result.passcode = passcode;
    if (discriminator != null) result.discriminator = discriminator;
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (vendorId != null) result.vendorId = vendorId;
    if (productId != null) result.productId = productId;
    if (deviceType != null) result.deviceType = deviceType;
    if (shortDiscriminator != null)
      result.shortDiscriminator = shortDiscriminator;
    return result;
  }

  CommissionRequest._();

  factory CommissionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommissionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommissionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'passcode', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'discriminator',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aI(5, _omitFieldNames ? '' : 'vendorId', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'productId', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'deviceType', fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'shortDiscriminator')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionRequest copyWith(void Function(CommissionRequest) updates) =>
      super.copyWith((message) => updates(message as CommissionRequest))
          as CommissionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommissionRequest create() => CommissionRequest._();
  @$core.override
  CommissionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommissionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommissionRequest>(create);
  static CommissionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get passcode => $_getIZ(0);
  @$pb.TagNumber(1)
  set passcode($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPasscode() => $_has(0);
  @$pb.TagNumber(1)
  void clearPasscode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get discriminator => $_getIZ(1);
  @$pb.TagNumber(2)
  set discriminator($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDiscriminator() => $_has(1);
  @$pb.TagNumber(2)
  void clearDiscriminator() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get nodeId => $_getI64(2);
  @$pb.TagNumber(3)
  set nodeId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNodeId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNodeId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get vendorId => $_getIZ(4);
  @$pb.TagNumber(5)
  set vendorId($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVendorId() => $_has(4);
  @$pb.TagNumber(5)
  void clearVendorId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get productId => $_getIZ(5);
  @$pb.TagNumber(6)
  set productId($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasProductId() => $_has(5);
  @$pb.TagNumber(6)
  void clearProductId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get deviceType => $_getIZ(6);
  @$pb.TagNumber(7)
  set deviceType($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDeviceType() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeviceType() => $_clearField(7);

  @$pb.TagNumber(10)
  $core.bool get shortDiscriminator => $_getBF(7);
  @$pb.TagNumber(10)
  set shortDiscriminator($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(10)
  $core.bool hasShortDiscriminator() => $_has(7);
  @$pb.TagNumber(10)
  void clearShortDiscriminator() => $_clearField(10);
}

class CommissionResult extends $pb.GeneratedMessage {
  factory CommissionResult({
    $core.bool? success,
    $fixnum.Int64? nodeId,
    $fixnum.Int64? fabricId,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (nodeId != null) result.nodeId = nodeId;
    if (fabricId != null) result.fabricId = fabricId;
    if (error != null) result.error = error;
    return result;
  }

  CommissionResult._();

  factory CommissionResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommissionResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommissionResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'fabricId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionResult copyWith(void Function(CommissionResult) updates) =>
      super.copyWith((message) => updates(message as CommissionResult))
          as CommissionResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommissionResult create() => CommissionResult._();
  @$core.override
  CommissionResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommissionResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommissionResult>(create);
  static CommissionResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get nodeId => $_getI64(1);
  @$pb.TagNumber(2)
  set nodeId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get fabricId => $_getI64(2);
  @$pb.TagNumber(3)
  set fabricId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFabricId() => $_has(2);
  @$pb.TagNumber(3)
  void clearFabricId() => $_clearField(3);

  /// the phone matches this against the device's Fabrics attribute
  /// before calling RemoveFabric on its throwaway fabric
  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

/// GET /commission/events (CoAP Observe)
/// Fine-grained progress of the /commission currently in flight.  A plain GET
/// returns the LATEST event (seq 0 = nothing in flight yet); Observe
/// notifications fire on every stage change.  seq is monotonic so the app can
/// drop stale or duplicate notifies.  stage is a CHIP CommissioningStage name
/// exactly as StageToString() renders it (e.g. "SendNOC", "Cleanup") — the
/// same names the phone SDK reports during its own commissioning — or one of
/// the controller's discovery pseudo-stages that precede PASE:
///   "SrpLookup"     checking the controller's own SRP server table
///   "Discovering"   commissionable DNS-SD browse on the LAN
///   "Found"         device located (detail = address); PASE starting
/// Only one commission runs at a time, so the stream is global.  Events are
/// advisory (UI progress) — the POST /commission reply remains the source of
/// truth for success/failure.
class CommissionEvent extends $pb.GeneratedMessage {
  factory CommissionEvent({
    $core.int? seq,
    $core.String? stage,
    $core.bool? failed,
    $core.String? detail,
  }) {
    final result = create();
    if (seq != null) result.seq = seq;
    if (stage != null) result.stage = stage;
    if (failed != null) result.failed = failed;
    if (detail != null) result.detail = detail;
    return result;
  }

  CommissionEvent._();

  factory CommissionEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommissionEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommissionEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'seq', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'stage')
    ..aOB(3, _omitFieldNames ? '' : 'failed')
    ..aOS(4, _omitFieldNames ? '' : 'detail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommissionEvent copyWith(void Function(CommissionEvent) updates) =>
      super.copyWith((message) => updates(message as CommissionEvent))
          as CommissionEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommissionEvent create() => CommissionEvent._();
  @$core.override
  CommissionEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommissionEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommissionEvent>(create);
  static CommissionEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get seq => $_getIZ(0);
  @$pb.TagNumber(1)
  set seq($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get stage => $_getSZ(1);
  @$pb.TagNumber(2)
  set stage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStage() => $_has(1);
  @$pb.TagNumber(2)
  void clearStage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get failed => $_getBF(2);
  @$pb.TagNumber(3)
  set failed($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFailed() => $_has(2);
  @$pb.TagNumber(3)
  void clearFailed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get detail => $_getSZ(3);
  @$pb.TagNumber(4)
  set detail($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDetail() => $_has(3);
  @$pb.TagNumber(4)
  void clearDetail() => $_clearField(4);
}

class Device extends $pb.GeneratedMessage {
  factory Device({
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.bool? reachable,
    $core.int? vendorId,
    $core.int? productId,
    $core.int? deviceType,
    ConnectivityState? connectivity,
    DeviceKind? kind,
    $core.int? roomId,
    EnergyRole? energyRole,
    $core.int? endpoint,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (reachable != null) result.reachable = reachable;
    if (vendorId != null) result.vendorId = vendorId;
    if (productId != null) result.productId = productId;
    if (deviceType != null) result.deviceType = deviceType;
    if (connectivity != null) result.connectivity = connectivity;
    if (kind != null) result.kind = kind;
    if (roomId != null) result.roomId = roomId;
    if (energyRole != null) result.energyRole = energyRole;
    if (endpoint != null) result.endpoint = endpoint;
    return result;
  }

  Device._();

  factory Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOB(3, _omitFieldNames ? '' : 'reachable')
    ..aI(4, _omitFieldNames ? '' : 'vendorId', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'productId', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'deviceType', fieldType: $pb.PbFieldType.OU3)
    ..aE<ConnectivityState>(7, _omitFieldNames ? '' : 'connectivity',
        enumValues: ConnectivityState.values)
    ..aE<DeviceKind>(8, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..aI(9, _omitFieldNames ? '' : 'roomId', fieldType: $pb.PbFieldType.OU3)
    ..aE<EnergyRole>(10, _omitFieldNames ? '' : 'energyRole',
        enumValues: EnergyRole.values)
    ..aI(11, _omitFieldNames ? '' : 'endpoint', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device copyWith(void Function(Device) updates) =>
      super.copyWith((message) => updates(message as Device)) as Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Device create() => Device._();
  @$core.override
  Device createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Device getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Device>(create);
  static Device? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get reachable => $_getBF(2);
  @$pb.TagNumber(3)
  set reachable($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReachable() => $_has(2);
  @$pb.TagNumber(3)
  void clearReachable() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get vendorId => $_getIZ(3);
  @$pb.TagNumber(4)
  set vendorId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVendorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearVendorId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get productId => $_getIZ(4);
  @$pb.TagNumber(5)
  set productId($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasProductId() => $_has(4);
  @$pb.TagNumber(5)
  void clearProductId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get deviceType => $_getIZ(5);
  @$pb.TagNumber(6)
  set deviceType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDeviceType() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceType() => $_clearField(6);

  @$pb.TagNumber(7)
  ConnectivityState get connectivity => $_getN(6);
  @$pb.TagNumber(7)
  set connectivity(ConnectivityState value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasConnectivity() => $_has(6);
  @$pb.TagNumber(7)
  void clearConnectivity() => $_clearField(7);

  @$pb.TagNumber(8)
  DeviceKind get kind => $_getN(7);
  @$pb.TagNumber(8)
  set kind(DeviceKind value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasKind() => $_has(7);
  @$pb.TagNumber(8)
  void clearKind() => $_clearField(8);

  /// Per-device metadata the controller owns (see DeviceMeta). The app caches
  /// these for offline display but is not their source of truth: rooms and
  /// energy roles used to be phone-local, so two phones disagreed forever and
  /// re-adding a device silently wiped both.
  @$pb.TagNumber(9)
  $core.int get roomId => $_getIZ(8);
  @$pb.TagNumber(9)
  set roomId($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRoomId() => $_has(8);
  @$pb.TagNumber(9)
  void clearRoomId() => $_clearField(9);

  @$pb.TagNumber(10)
  EnergyRole get energyRole => $_getN(9);
  @$pb.TagNumber(10)
  set energyRole(EnergyRole value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasEnergyRole() => $_has(9);
  @$pb.TagNumber(10)
  void clearEnergyRole() => $_clearField(10);

  /// Matter endpoint, part of the device key (see FW-ADR-0018).
  ///   0  = the node itself — every non-bridge device, and a bridge's own entry
  ///   >0 = a device BRIDGED behind this node, living on that endpoint
  /// A Matter bridge exposes its children as endpoints of one node, so
  /// (kind, node_id) alone cannot name them: a Hue Bridge with five bulbs is
  /// one node and six devices.
  @$pb.TagNumber(11)
  $core.int get endpoint => $_getIZ(10);
  @$pb.TagNumber(11)
  set endpoint($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasEndpoint() => $_has(10);
  @$pb.TagNumber(11)
  void clearEndpoint() => $_clearField(11);
}

/// GET /devices
class DeviceList extends $pb.GeneratedMessage {
  factory DeviceList({
    $core.Iterable<Device>? devices,
  }) {
    final result = create();
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  DeviceList._();

  factory DeviceList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..pPM<Device>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: Device.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceList copyWith(void Function(DeviceList) updates) =>
      super.copyWith((message) => updates(message as DeviceList)) as DeviceList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceList create() => DeviceList._();
  @$core.override
  DeviceList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceList>(create);
  static DeviceList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Device> get devices => $_getList(0);
}

/// ─── Rooms ──────────────────────────────────────────────────────────────────
/// A room is a named group devices are assigned to. The controller owns both the
/// list and the membership so the layout survives a reinstall and agrees across
/// phones. IDs are small controller-issued integers, not UUIDs: Device.room_id
/// sits in a fixed-size record, where 2 bytes beats 37.
///
/// id 0 is the reserved "No Room" sentinel. It is never stored and never sent in
/// a RoomList — every device that has not been assigned carries room_id 0.
/// Membership lives on the device (room_id), NOT as a room→devices list, so there
/// is only one copy of the relationship to keep consistent.
class Room extends $pb.GeneratedMessage {
  factory Room({
    $core.int? id,
    $core.String? name,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    return result;
  }

  Room._();

  factory Room.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Room.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Room',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Room clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Room copyWith(void Function(Room) updates) =>
      super.copyWith((message) => updates(message as Room)) as Room;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Room create() => Room._();
  @$core.override
  Room createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Room getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Room>(create);
  static Room? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

/// GET /rooms → RoomList ;  PUT /rooms ← RoomList
/// PUT is a FULL REPLACE, mirroring how the app holds the list. An entry with
/// id 0 is a request to create (the controller assigns the id and returns the
/// new list); omitting an existing room deletes it, and any device left pointing
/// at a deleted room falls back to room_id 0 rather than dangling.
class RoomList extends $pb.GeneratedMessage {
  factory RoomList({
    $core.Iterable<Room>? rooms,
  }) {
    final result = create();
    if (rooms != null) result.rooms.addAll(rooms);
    return result;
  }

  RoomList._();

  factory RoomList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoomList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoomList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..pPM<Room>(1, _omitFieldNames ? '' : 'rooms', subBuilder: Room.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoomList copyWith(void Function(RoomList) updates) =>
      super.copyWith((message) => updates(message as RoomList)) as RoomList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoomList create() => RoomList._();
  @$core.override
  RoomList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoomList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoomList>(create);
  static RoomList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Room> get rooms => $_getList(0);
}

/// POST /devices/meta — partial update of the metadata the controller owns.
/// Every field is `optional` so "not sent" is distinguishable from "set to the
/// default": clearing a room (room_id 0) and clearing an energy role
/// (ENERGY_CLASS_UNKNOWN) are both legitimate writes, and without presence they
/// would be indistinguishable from an untouched field.
class DeviceMeta extends $pb.GeneratedMessage {
  factory DeviceMeta({
    $fixnum.Int64? nodeId,
    DeviceKind? kind,
    $core.String? name,
    $core.int? roomId,
    EnergyRole? energyRole,
    $core.int? endpoint,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (kind != null) result.kind = kind;
    if (name != null) result.name = name;
    if (roomId != null) result.roomId = roomId;
    if (energyRole != null) result.energyRole = energyRole;
    if (endpoint != null) result.endpoint = endpoint;
    return result;
  }

  DeviceMeta._();

  factory DeviceMeta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceMeta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceMeta',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<DeviceKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'roomId', fieldType: $pb.PbFieldType.OU3)
    ..aE<EnergyRole>(5, _omitFieldNames ? '' : 'energyRole',
        enumValues: EnergyRole.values)
    ..aI(6, _omitFieldNames ? '' : 'endpoint', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMeta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMeta copyWith(void Function(DeviceMeta) updates) =>
      super.copyWith((message) => updates(message as DeviceMeta)) as DeviceMeta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceMeta create() => DeviceMeta._();
  @$core.override
  DeviceMeta createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceMeta getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceMeta>(create);
  static DeviceMeta? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  DeviceKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(DeviceKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get roomId => $_getIZ(3);
  @$pb.TagNumber(4)
  set roomId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRoomId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRoomId() => $_clearField(4);

  @$pb.TagNumber(5)
  EnergyRole get energyRole => $_getN(4);
  @$pb.TagNumber(5)
  set energyRole(EnergyRole value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEnergyRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnergyRole() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get endpoint => $_getIZ(5);
  @$pb.TagNumber(6)
  set endpoint($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEndpoint() => $_has(5);
  @$pb.TagNumber(6)
  void clearEndpoint() => $_clearField(6);
}

/// POST /devices/{id}/name
class RenameDeviceRequest extends $pb.GeneratedMessage {
  factory RenameDeviceRequest({
    $fixnum.Int64? nodeId,
    $core.String? name,
    DeviceKind? kind,
    $core.int? endpoint,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    if (endpoint != null) result.endpoint = endpoint;
    return result;
  }

  RenameDeviceRequest._();

  factory RenameDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenameDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<DeviceKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..aI(4, _omitFieldNames ? '' : 'endpoint', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameDeviceRequest copyWith(void Function(RenameDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RenameDeviceRequest))
          as RenameDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenameDeviceRequest create() => RenameDeviceRequest._();
  @$core.override
  RenameDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenameDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameDeviceRequest>(create);
  static RenameDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  DeviceKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(DeviceKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get endpoint => $_getIZ(3);
  @$pb.TagNumber(4)
  set endpoint($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndpoint() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndpoint() => $_clearField(4);
}

/// POST /node/register
/// App notifies controller that a device has been commissioned into the shared
/// fabric.  The controller upserts the device into its registry and opens a
/// CASE session + subscription.  The app must have granted Node 0x0002 Administer
/// access on the device's ACL before calling this.
class RegisterNodeRequest extends $pb.GeneratedMessage {
  factory RegisterNodeRequest({
    $fixnum.Int64? fabricId,
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.int? vendorId,
    $core.int? productId,
    $core.int? deviceType,
  }) {
    final result = create();
    if (fabricId != null) result.fabricId = fabricId;
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (vendorId != null) result.vendorId = vendorId;
    if (productId != null) result.productId = productId;
    if (deviceType != null) result.deviceType = deviceType;
    return result;
  }

  RegisterNodeRequest._();

  factory RegisterNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'fabricId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'vendorId', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'productId', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'deviceType', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterNodeRequest copyWith(void Function(RegisterNodeRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterNodeRequest))
          as RegisterNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterNodeRequest create() => RegisterNodeRequest._();
  @$core.override
  RegisterNodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterNodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterNodeRequest>(create);
  static RegisterNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get fabricId => $_getI64(0);
  @$pb.TagNumber(1)
  set fabricId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFabricId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFabricId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get nodeId => $_getI64(1);
  @$pb.TagNumber(2)
  set nodeId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get vendorId => $_getIZ(3);
  @$pb.TagNumber(4)
  set vendorId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVendorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearVendorId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get productId => $_getIZ(4);
  @$pb.TagNumber(5)
  set productId($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasProductId() => $_has(4);
  @$pb.TagNumber(5)
  void clearProductId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get deviceType => $_getIZ(5);
  @$pb.TagNumber(6)
  set deviceType($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDeviceType() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceType() => $_clearField(6);
}

/// POST /modbus/devices
/// Add or update a Modbus TCP device.  The controller persists the config,
/// registers the device (device_type per profile), and begins polling it.
class ModbusDeviceConfig extends $pb.GeneratedMessage {
  factory ModbusDeviceConfig({
    $core.String? host,
    $core.int? port,
    $core.int? unitId,
    ModbusProfile? profile,
    $core.int? pollSeconds,
    $core.String? name,
    $fixnum.Int64? nodeId,
    ModbusTransport? transport,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (unitId != null) result.unitId = unitId;
    if (profile != null) result.profile = profile;
    if (pollSeconds != null) result.pollSeconds = pollSeconds;
    if (name != null) result.name = name;
    if (nodeId != null) result.nodeId = nodeId;
    if (transport != null) result.transport = transport;
    return result;
  }

  ModbusDeviceConfig._();

  factory ModbusDeviceConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModbusDeviceConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModbusDeviceConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'unitId', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModbusProfile>(4, _omitFieldNames ? '' : 'profile',
        enumValues: ModbusProfile.values)
    ..aI(5, _omitFieldNames ? '' : 'pollSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'name')
    ..a<$fixnum.Int64>(7, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<ModbusTransport>(8, _omitFieldNames ? '' : 'transport',
        enumValues: ModbusTransport.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusDeviceConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusDeviceConfig copyWith(void Function(ModbusDeviceConfig) updates) =>
      super.copyWith((message) => updates(message as ModbusDeviceConfig))
          as ModbusDeviceConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModbusDeviceConfig create() => ModbusDeviceConfig._();
  @$core.override
  ModbusDeviceConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModbusDeviceConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModbusDeviceConfig>(create);
  static ModbusDeviceConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get unitId => $_getIZ(2);
  @$pb.TagNumber(3)
  set unitId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUnitId() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnitId() => $_clearField(3);

  @$pb.TagNumber(4)
  ModbusProfile get profile => $_getN(3);
  @$pb.TagNumber(4)
  set profile(ModbusProfile value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasProfile() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfile() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get pollSeconds => $_getIZ(4);
  @$pb.TagNumber(5)
  set pollSeconds($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPollSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearPollSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get name => $_getSZ(5);
  @$pb.TagNumber(6)
  set name($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasName() => $_has(5);
  @$pb.TagNumber(6)
  void clearName() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get nodeId => $_getI64(6);
  @$pb.TagNumber(7)
  set nodeId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNodeId() => $_has(6);
  @$pb.TagNumber(7)
  void clearNodeId() => $_clearField(7);

  @$pb.TagNumber(8)
  ModbusTransport get transport => $_getN(7);
  @$pb.TagNumber(8)
  set transport(ModbusTransport value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTransport() => $_has(7);
  @$pb.TagNumber(8)
  void clearTransport() => $_clearField(8);
}

/// One candidate surfaced by a discovery scan (not yet registered).
class ModbusCandidate extends $pb.GeneratedMessage {
  factory ModbusCandidate({
    $core.String? host,
    ModbusProfile? profile,
    $core.String? serial,
    $core.String? model,
    ModbusTransport? transport,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (profile != null) result.profile = profile;
    if (serial != null) result.serial = serial;
    if (model != null) result.model = model;
    if (transport != null) result.transport = transport;
    return result;
  }

  ModbusCandidate._();

  factory ModbusCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModbusCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModbusCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aE<ModbusProfile>(2, _omitFieldNames ? '' : 'profile',
        enumValues: ModbusProfile.values)
    ..aOS(3, _omitFieldNames ? '' : 'serial')
    ..aOS(4, _omitFieldNames ? '' : 'model')
    ..aE<ModbusTransport>(5, _omitFieldNames ? '' : 'transport',
        enumValues: ModbusTransport.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusCandidate copyWith(void Function(ModbusCandidate) updates) =>
      super.copyWith((message) => updates(message as ModbusCandidate))
          as ModbusCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModbusCandidate create() => ModbusCandidate._();
  @$core.override
  ModbusCandidate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModbusCandidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModbusCandidate>(create);
  static ModbusCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  ModbusProfile get profile => $_getN(1);
  @$pb.TagNumber(2)
  set profile(ModbusProfile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get serial => $_getSZ(2);
  @$pb.TagNumber(3)
  set serial($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSerial() => $_has(2);
  @$pb.TagNumber(3)
  void clearSerial() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get model => $_getSZ(3);
  @$pb.TagNumber(4)
  set model($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearModel() => $_clearField(4);

  @$pb.TagNumber(5)
  ModbusTransport get transport => $_getN(4);
  @$pb.TagNumber(5)
  set transport(ModbusTransport value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTransport() => $_has(4);
  @$pb.TagNumber(5)
  void clearTransport() => $_clearField(5);
}

/// GET /modbus/discovered
/// Result of scanning the controller's own Ethernet subnet for Modbus devices.
/// Suggest-only: nothing is polled until the app confirms via POST /modbus/devices.
class ModbusDiscovered extends $pb.GeneratedMessage {
  factory ModbusDiscovered({
    $core.Iterable<ModbusCandidate>? candidates,
  }) {
    final result = create();
    if (candidates != null) result.candidates.addAll(candidates);
    return result;
  }

  ModbusDiscovered._();

  factory ModbusDiscovered.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModbusDiscovered.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModbusDiscovered',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..pPM<ModbusCandidate>(1, _omitFieldNames ? '' : 'candidates',
        subBuilder: ModbusCandidate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusDiscovered clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusDiscovered copyWith(void Function(ModbusDiscovered) updates) =>
      super.copyWith((message) => updates(message as ModbusDiscovered))
          as ModbusDiscovered;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModbusDiscovered create() => ModbusDiscovered._();
  @$core.override
  ModbusDiscovered createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModbusDiscovered getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModbusDiscovered>(create);
  static ModbusDiscovered? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ModbusCandidate> get candidates => $_getList(0);
}

/// GET /modbus/rawdump?host=<ip>&unit=<id>[&transport=tcp|udp]
/// Raw SunSpec register capture of one device for off-device capability
/// profiling (field-hardware database). The controller walks the SunSpec model
/// chain ('SunS' marker + each model header) and returns the registers verbatim
/// — it does NOT decode models on-device; the app forwards this blob and it is
/// decoded off-device (e.g. pysunspec2). `registers` is big-endian uint16[reg_count]
/// starting at `base_addr`. On failure `error` is set and registers is empty.
class ModbusRawDump extends $pb.GeneratedMessage {
  factory ModbusRawDump({
    $core.String? host,
    $core.int? unitId,
    ModbusTransport? transport,
    $core.int? baseAddr,
    $core.int? regCount,
    $core.List<$core.int>? registers,
    $core.bool? truncated,
    $core.String? error,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (unitId != null) result.unitId = unitId;
    if (transport != null) result.transport = transport;
    if (baseAddr != null) result.baseAddr = baseAddr;
    if (regCount != null) result.regCount = regCount;
    if (registers != null) result.registers = registers;
    if (truncated != null) result.truncated = truncated;
    if (error != null) result.error = error;
    return result;
  }

  ModbusRawDump._();

  factory ModbusRawDump.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModbusRawDump.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModbusRawDump',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'unitId', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModbusTransport>(3, _omitFieldNames ? '' : 'transport',
        enumValues: ModbusTransport.values)
    ..aI(4, _omitFieldNames ? '' : 'baseAddr', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'regCount', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'registers', $pb.PbFieldType.OY)
    ..aOB(7, _omitFieldNames ? '' : 'truncated')
    ..aOS(8, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusRawDump clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModbusRawDump copyWith(void Function(ModbusRawDump) updates) =>
      super.copyWith((message) => updates(message as ModbusRawDump))
          as ModbusRawDump;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModbusRawDump create() => ModbusRawDump._();
  @$core.override
  ModbusRawDump createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModbusRawDump getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModbusRawDump>(create);
  static ModbusRawDump? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get unitId => $_getIZ(1);
  @$pb.TagNumber(2)
  set unitId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnitId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnitId() => $_clearField(2);

  @$pb.TagNumber(3)
  ModbusTransport get transport => $_getN(2);
  @$pb.TagNumber(3)
  set transport(ModbusTransport value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTransport() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransport() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get baseAddr => $_getIZ(3);
  @$pb.TagNumber(4)
  set baseAddr($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBaseAddr() => $_has(3);
  @$pb.TagNumber(4)
  void clearBaseAddr() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get regCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set regCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRegCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearRegCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get registers => $_getN(5);
  @$pb.TagNumber(6)
  set registers($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRegisters() => $_has(5);
  @$pb.TagNumber(6)
  void clearRegisters() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get truncated => $_getBF(6);
  @$pb.TagNumber(7)
  set truncated($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTruncated() => $_has(6);
  @$pb.TagNumber(7)
  void clearTruncated() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get error => $_getSZ(7);
  @$pb.TagNumber(8)
  set error($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => $_clearField(8);
}

enum Attr_Value { boolVal, intVal, longVal, notSet }

/// A single cluster attribute with a typed value.
/// Key names must match SubscriptionKeys.kt exactly.
class Attr extends $pb.GeneratedMessage {
  factory Attr({
    $core.String? key,
    $core.bool? boolVal,
    $core.int? intVal,
    $fixnum.Int64? longVal,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (boolVal != null) result.boolVal = boolVal;
    if (intVal != null) result.intVal = intVal;
    if (longVal != null) result.longVal = longVal;
    return result;
  }

  Attr._();

  factory Attr.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Attr.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Attr_Value> _Attr_ValueByTag = {
    2: Attr_Value.boolVal,
    3: Attr_Value.intVal,
    4: Attr_Value.longVal,
    0: Attr_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Attr',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4])
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOB(2, _omitFieldNames ? '' : 'boolVal')
    ..aI(3, _omitFieldNames ? '' : 'intVal', fieldType: $pb.PbFieldType.OS3)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'longVal', $pb.PbFieldType.OS6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attr clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attr copyWith(void Function(Attr) updates) =>
      super.copyWith((message) => updates(message as Attr)) as Attr;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attr create() => Attr._();
  @$core.override
  Attr createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Attr getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Attr>(create);
  static Attr? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  Attr_Value whichValue() => _Attr_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get boolVal => $_getBF(1);
  @$pb.TagNumber(2)
  set boolVal($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBoolVal() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolVal() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get intVal => $_getIZ(2);
  @$pb.TagNumber(3)
  set intVal($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIntVal() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntVal() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get longVal => $_getI64(3);
  @$pb.TagNumber(4)
  set longVal($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLongVal() => $_has(3);
  @$pb.TagNumber(4)
  void clearLongVal() => $_clearField(4);
}

/// A batch of attribute updates for one node.
class AttrsUpdate extends $pb.GeneratedMessage {
  factory AttrsUpdate({
    $fixnum.Int64? nodeId,
    $core.Iterable<Attr>? attrs,
    DeviceKind? kind,
    $core.int? endpoint,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (attrs != null) result.attrs.addAll(attrs);
    if (kind != null) result.kind = kind;
    if (endpoint != null) result.endpoint = endpoint;
    return result;
  }

  AttrsUpdate._();

  factory AttrsUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AttrsUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttrsUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<Attr>(2, _omitFieldNames ? '' : 'attrs', subBuilder: Attr.create)
    ..aE<DeviceKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..aI(4, _omitFieldNames ? '' : 'endpoint', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttrsUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttrsUpdate copyWith(void Function(AttrsUpdate) updates) =>
      super.copyWith((message) => updates(message as AttrsUpdate))
          as AttrsUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AttrsUpdate create() => AttrsUpdate._();
  @$core.override
  AttrsUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AttrsUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttrsUpdate>(create);
  static AttrsUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Attr> get attrs => $_getList(1);

  @$pb.TagNumber(3)
  DeviceKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(DeviceKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  /// Which device on that node the readings belong to. Without this, every
  /// device bridged behind one node collapses into a single attribute bag and
  /// the last endpoint to report wins per key — five Hue devices sharing one
  /// onOff. See Device.endpoint.
  @$pb.TagNumber(4)
  $core.int get endpoint => $_getIZ(3);
  @$pb.TagNumber(4)
  set endpoint($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndpoint() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndpoint() => $_clearField(4);
}

/// Pushed when a subscription changes state or attributes are updated.
class DeviceStateEvent extends $pb.GeneratedMessage {
  factory DeviceStateEvent({
    $fixnum.Int64? nodeId,
    DeviceEventType? type,
    AttrsUpdate? update,
    $core.String? error,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (type != null) result.type = type;
    if (update != null) result.update = update;
    if (error != null) result.error = error;
    if (kind != null) result.kind = kind;
    return result;
  }

  DeviceStateEvent._();

  factory DeviceStateEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceStateEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceStateEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<DeviceEventType>(2, _omitFieldNames ? '' : 'type',
        enumValues: DeviceEventType.values)
    ..aOM<AttrsUpdate>(3, _omitFieldNames ? '' : 'update',
        subBuilder: AttrsUpdate.create)
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aE<DeviceKind>(5, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceStateEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceStateEvent copyWith(void Function(DeviceStateEvent) updates) =>
      super.copyWith((message) => updates(message as DeviceStateEvent))
          as DeviceStateEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceStateEvent create() => DeviceStateEvent._();
  @$core.override
  DeviceStateEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceStateEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceStateEvent>(create);
  static DeviceStateEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  DeviceEventType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(DeviceEventType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  AttrsUpdate get update => $_getN(2);
  @$pb.TagNumber(3)
  set update(AttrsUpdate value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdate() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdate() => $_clearField(3);
  @$pb.TagNumber(3)
  AttrsUpdate ensureUpdate() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  DeviceKind get kind => $_getN(4);
  @$pb.TagNumber(5)
  set kind(DeviceKind value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);
}

enum CommandArg_Value { boolVal, uintVal, intVal, strVal, notSet }

/// A single typed argument for a cluster command (e.g. IdentifyTime=3).
/// tag is the TLV field tag number from the Matter cluster spec (0-based).
/// name is kept for logging only.
class CommandArg extends $pb.GeneratedMessage {
  factory CommandArg({
    $core.String? name,
    $core.bool? boolVal,
    $core.int? uintVal,
    $core.int? intVal,
    $core.String? strVal,
    $core.int? tag,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (boolVal != null) result.boolVal = boolVal;
    if (uintVal != null) result.uintVal = uintVal;
    if (intVal != null) result.intVal = intVal;
    if (strVal != null) result.strVal = strVal;
    if (tag != null) result.tag = tag;
    return result;
  }

  CommandArg._();

  factory CommandArg.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommandArg.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, CommandArg_Value> _CommandArg_ValueByTag = {
    2: CommandArg_Value.boolVal,
    3: CommandArg_Value.uintVal,
    4: CommandArg_Value.intVal,
    5: CommandArg_Value.strVal,
    0: CommandArg_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommandArg',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5])
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOB(2, _omitFieldNames ? '' : 'boolVal')
    ..aI(3, _omitFieldNames ? '' : 'uintVal', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'intVal', fieldType: $pb.PbFieldType.OS3)
    ..aOS(5, _omitFieldNames ? '' : 'strVal')
    ..aI(6, _omitFieldNames ? '' : 'tag', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandArg clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandArg copyWith(void Function(CommandArg) updates) =>
      super.copyWith((message) => updates(message as CommandArg)) as CommandArg;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommandArg create() => CommandArg._();
  @$core.override
  CommandArg createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommandArg getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommandArg>(create);
  static CommandArg? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  CommandArg_Value whichValue() => _CommandArg_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get boolVal => $_getBF(1);
  @$pb.TagNumber(2)
  set boolVal($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBoolVal() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolVal() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get uintVal => $_getIZ(2);
  @$pb.TagNumber(3)
  set uintVal($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUintVal() => $_has(2);
  @$pb.TagNumber(3)
  void clearUintVal() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get intVal => $_getIZ(3);
  @$pb.TagNumber(4)
  set intVal($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIntVal() => $_has(3);
  @$pb.TagNumber(4)
  void clearIntVal() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get strVal => $_getSZ(4);
  @$pb.TagNumber(5)
  set strVal($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStrVal() => $_has(4);
  @$pb.TagNumber(5)
  void clearStrVal() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get tag => $_getIZ(5);
  @$pb.TagNumber(6)
  set tag($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTag() => $_has(5);
  @$pb.TagNumber(6)
  void clearTag() => $_clearField(6);
}

/// Send a cluster command (OnOff, Level, Color, Thermostat, Covering, Fan,
/// Lock, Identify, …).
class DeviceCommand extends $pb.GeneratedMessage {
  factory DeviceCommand({
    $fixnum.Int64? nodeId,
    $core.int? endpointId,
    $core.int? clusterId,
    $core.int? commandId,
    $core.Iterable<CommandArg>? args,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointId != null) result.endpointId = endpointId;
    if (clusterId != null) result.clusterId = clusterId;
    if (commandId != null) result.commandId = commandId;
    if (args != null) result.args.addAll(args);
    if (kind != null) result.kind = kind;
    return result;
  }

  DeviceCommand._();

  factory DeviceCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(2, _omitFieldNames ? '' : 'endpointId', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'clusterId', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'commandId', fieldType: $pb.PbFieldType.OU3)
    ..pPM<CommandArg>(5, _omitFieldNames ? '' : 'args',
        subBuilder: CommandArg.create)
    ..aE<DeviceKind>(6, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceCommand copyWith(void Function(DeviceCommand) updates) =>
      super.copyWith((message) => updates(message as DeviceCommand))
          as DeviceCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceCommand create() => DeviceCommand._();
  @$core.override
  DeviceCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceCommand>(create);
  static DeviceCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endpointId => $_getIZ(1);
  @$pb.TagNumber(2)
  set endpointId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndpointId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndpointId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get clusterId => $_getIZ(2);
  @$pb.TagNumber(3)
  set clusterId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClusterId() => $_has(2);
  @$pb.TagNumber(3)
  void clearClusterId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get commandId => $_getIZ(3);
  @$pb.TagNumber(4)
  set commandId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCommandId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommandId() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<CommandArg> get args => $_getList(4);

  @$pb.TagNumber(6)
  DeviceKind get kind => $_getN(5);
  @$pb.TagNumber(6)
  set kind(DeviceKind value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasKind() => $_has(5);
  @$pb.TagNumber(6)
  void clearKind() => $_clearField(6);
}

enum WriteAttrRequest_Value { boolVal, intVal, notSet }

/// Write a single cluster attribute.
class WriteAttrRequest extends $pb.GeneratedMessage {
  factory WriteAttrRequest({
    $fixnum.Int64? nodeId,
    $core.int? endpointId,
    $core.int? clusterId,
    $core.int? attrId,
    $core.bool? boolVal,
    $core.int? intVal,
    $core.String? jsonVal,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointId != null) result.endpointId = endpointId;
    if (clusterId != null) result.clusterId = clusterId;
    if (attrId != null) result.attrId = attrId;
    if (boolVal != null) result.boolVal = boolVal;
    if (intVal != null) result.intVal = intVal;
    if (jsonVal != null) result.jsonVal = jsonVal;
    if (kind != null) result.kind = kind;
    return result;
  }

  WriteAttrRequest._();

  factory WriteAttrRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WriteAttrRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WriteAttrRequest_Value>
      _WriteAttrRequest_ValueByTag = {
    5: WriteAttrRequest_Value.boolVal,
    6: WriteAttrRequest_Value.intVal,
    0: WriteAttrRequest_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteAttrRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..oo(0, [5, 6])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(2, _omitFieldNames ? '' : 'endpointId', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'clusterId', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'attrId', fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'boolVal')
    ..aI(6, _omitFieldNames ? '' : 'intVal', fieldType: $pb.PbFieldType.OS3)
    ..aOS(7, _omitFieldNames ? '' : 'jsonVal')
    ..aE<DeviceKind>(8, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteAttrRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteAttrRequest copyWith(void Function(WriteAttrRequest) updates) =>
      super.copyWith((message) => updates(message as WriteAttrRequest))
          as WriteAttrRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WriteAttrRequest create() => WriteAttrRequest._();
  @$core.override
  WriteAttrRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WriteAttrRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WriteAttrRequest>(create);
  static WriteAttrRequest? _defaultInstance;

  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  WriteAttrRequest_Value whichValue() =>
      _WriteAttrRequest_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endpointId => $_getIZ(1);
  @$pb.TagNumber(2)
  set endpointId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndpointId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndpointId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get clusterId => $_getIZ(2);
  @$pb.TagNumber(3)
  set clusterId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClusterId() => $_has(2);
  @$pb.TagNumber(3)
  void clearClusterId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get attrId => $_getIZ(3);
  @$pb.TagNumber(4)
  set attrId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAttrId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAttrId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get boolVal => $_getBF(4);
  @$pb.TagNumber(5)
  set boolVal($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBoolVal() => $_has(4);
  @$pb.TagNumber(5)
  void clearBoolVal() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get intVal => $_getIZ(5);
  @$pb.TagNumber(6)
  set intVal($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIntVal() => $_has(5);
  @$pb.TagNumber(6)
  void clearIntVal() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get jsonVal => $_getSZ(6);
  @$pb.TagNumber(7)
  set jsonVal($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasJsonVal() => $_has(6);
  @$pb.TagNumber(7)
  void clearJsonVal() => $_clearField(7);

  @$pb.TagNumber(8)
  DeviceKind get kind => $_getN(7);
  @$pb.TagNumber(8)
  set kind(DeviceKind value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasKind() => $_has(7);
  @$pb.TagNumber(8)
  void clearKind() => $_clearField(8);
}

/// Read one or more cluster attributes.
class ReadRequest extends $pb.GeneratedMessage {
  factory ReadRequest({
    $fixnum.Int64? nodeId,
    $core.Iterable<$core.int>? endpointIds,
    $core.Iterable<$core.int>? clusterIds,
    $core.Iterable<$core.int>? attrIds,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointIds != null) result.endpointIds.addAll(endpointIds);
    if (clusterIds != null) result.clusterIds.addAll(clusterIds);
    if (attrIds != null) result.attrIds.addAll(attrIds);
    if (kind != null) result.kind = kind;
    return result;
  }

  ReadRequest._();

  factory ReadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$core.int>(2, _omitFieldNames ? '' : 'endpointIds', $pb.PbFieldType.KU3)
    ..p<$core.int>(3, _omitFieldNames ? '' : 'clusterIds', $pb.PbFieldType.KU3)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'attrIds', $pb.PbFieldType.KU3)
    ..aE<DeviceKind>(5, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReadRequest copyWith(void Function(ReadRequest) updates) =>
      super.copyWith((message) => updates(message as ReadRequest))
          as ReadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReadRequest create() => ReadRequest._();
  @$core.override
  ReadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReadRequest>(create);
  static ReadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get endpointIds => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get clusterIds => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get attrIds => $_getList(3);

  @$pb.TagNumber(5)
  DeviceKind get kind => $_getN(4);
  @$pb.TagNumber(5)
  set kind(DeviceKind value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);
}

/// Simple success/failure response.
class BoolResult extends $pb.GeneratedMessage {
  factory BoolResult({
    $core.bool? success,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    return result;
  }

  BoolResult._();

  factory BoolResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BoolResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BoolResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BoolResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BoolResult copyWith(void Function(BoolResult) updates) =>
      super.copyWith((message) => updates(message as BoolResult)) as BoolResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BoolResult create() => BoolResult._();
  @$core.override
  BoolResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BoolResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BoolResult>(create);
  static BoolResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Generic mutation response (used by HTTP stubs not yet returning richer types)
class StatusResponse extends $pb.GeneratedMessage {
  factory StatusResponse({
    $core.int? code,
    $core.String? message,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  StatusResponse._();

  factory StatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'code', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusResponse copyWith(void Function(StatusResponse) updates) =>
      super.copyWith((message) => updates(message as StatusResponse))
          as StatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatusResponse create() => StatusResponse._();
  @$core.override
  StatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StatusResponse>(create);
  static StatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// One time bucket: energy over [start + index*bucket_seconds, +bucket_seconds).
/// A 0/omitted field (proto3 default) means no contribution from that class.
class EnergyBucket extends $pb.GeneratedMessage {
  factory EnergyBucket({
    $core.int? index,
    $core.int? gridImportWh,
    $core.int? gridExportWh,
    $core.int? pvWh,
    $core.int? loadWh,
    $core.int? batteryChargeWh,
    $core.int? batteryDischargeWh,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (gridImportWh != null) result.gridImportWh = gridImportWh;
    if (gridExportWh != null) result.gridExportWh = gridExportWh;
    if (pvWh != null) result.pvWh = pvWh;
    if (loadWh != null) result.loadWh = loadWh;
    if (batteryChargeWh != null) result.batteryChargeWh = batteryChargeWh;
    if (batteryDischargeWh != null)
      result.batteryDischargeWh = batteryDischargeWh;
    return result;
  }

  EnergyBucket._();

  factory EnergyBucket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnergyBucket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnergyBucket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'gridImportWh',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'gridExportWh',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'pvWh', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'loadWh', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'batteryChargeWh',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'batteryDischargeWh',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyBucket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyBucket copyWith(void Function(EnergyBucket) updates) =>
      super.copyWith((message) => updates(message as EnergyBucket))
          as EnergyBucket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnergyBucket create() => EnergyBucket._();
  @$core.override
  EnergyBucket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnergyBucket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnergyBucket>(create);
  static EnergyBucket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get gridImportWh => $_getIZ(1);
  @$pb.TagNumber(2)
  set gridImportWh($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGridImportWh() => $_has(1);
  @$pb.TagNumber(2)
  void clearGridImportWh() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get gridExportWh => $_getIZ(2);
  @$pb.TagNumber(3)
  set gridExportWh($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGridExportWh() => $_has(2);
  @$pb.TagNumber(3)
  void clearGridExportWh() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get pvWh => $_getIZ(3);
  @$pb.TagNumber(4)
  set pvWh($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPvWh() => $_has(3);
  @$pb.TagNumber(4)
  void clearPvWh() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get loadWh => $_getIZ(4);
  @$pb.TagNumber(5)
  set loadWh($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLoadWh() => $_has(4);
  @$pb.TagNumber(5)
  void clearLoadWh() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get batteryChargeWh => $_getIZ(5);
  @$pb.TagNumber(6)
  set batteryChargeWh($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBatteryChargeWh() => $_has(5);
  @$pb.TagNumber(6)
  void clearBatteryChargeWh() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get batteryDischargeWh => $_getIZ(6);
  @$pb.TagNumber(7)
  set batteryDischargeWh($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBatteryDischargeWh() => $_has(6);
  @$pb.TagNumber(7)
  void clearBatteryDischargeWh() => $_clearField(7);
}

/// Per-device energy contribution over the same time base as EnergyHistory —
/// currently emitted for PV devices only, so the app can break the summed PV
/// total down per inverter. wh[i] aligns to EnergyHistory.buckets[i] (0 = no
/// contribution in that bucket); the series is dense (wh_count == buckets_count).
class EnergyDeviceSeries extends $pb.GeneratedMessage {
  factory EnergyDeviceSeries({
    $fixnum.Int64? nodeId,
    EnergyClass? cls,
    $core.String? name,
    $core.Iterable<$core.int>? wh,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (cls != null) result.cls = cls;
    if (name != null) result.name = name;
    if (wh != null) result.wh.addAll(wh);
    if (kind != null) result.kind = kind;
    return result;
  }

  EnergyDeviceSeries._();

  factory EnergyDeviceSeries.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnergyDeviceSeries.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnergyDeviceSeries',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<EnergyClass>(2, _omitFieldNames ? '' : 'cls',
        enumValues: EnergyClass.values)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'wh', $pb.PbFieldType.KU3)
    ..aE<DeviceKind>(5, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyDeviceSeries clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyDeviceSeries copyWith(void Function(EnergyDeviceSeries) updates) =>
      super.copyWith((message) => updates(message as EnergyDeviceSeries))
          as EnergyDeviceSeries;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnergyDeviceSeries create() => EnergyDeviceSeries._();
  @$core.override
  EnergyDeviceSeries createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnergyDeviceSeries getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnergyDeviceSeries>(create);
  static EnergyDeviceSeries? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  EnergyClass get cls => $_getN(1);
  @$pb.TagNumber(2)
  set cls(EnergyClass value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCls() => $_has(1);
  @$pb.TagNumber(2)
  void clearCls() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get wh => $_getList(3);

  @$pb.TagNumber(5)
  DeviceKind get kind => $_getN(4);
  @$pb.TagNumber(5)
  set kind(DeviceKind value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);
}

/// Per-battery State-of-Charge over the same bucket timeline. SOC is an
/// instantaneous LEVEL (%), not a flow, so it is the measured value at each
/// bucket's end (carried forward across gaps); 255 = no sample yet. Distinct
/// from device_series (which carries accumulated Wh).
class BatterySocSeries extends $pb.GeneratedMessage {
  factory BatterySocSeries({
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.List<$core.int>? socPct,
    DeviceKind? kind,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (socPct != null) result.socPct = socPct;
    if (kind != null) result.kind = kind;
    return result;
  }

  BatterySocSeries._();

  factory BatterySocSeries.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BatterySocSeries.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatterySocSeries',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nodeId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'socPct', $pb.PbFieldType.OY)
    ..aE<DeviceKind>(4, _omitFieldNames ? '' : 'kind',
        enumValues: DeviceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatterySocSeries clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatterySocSeries copyWith(void Function(BatterySocSeries) updates) =>
      super.copyWith((message) => updates(message as BatterySocSeries))
          as BatterySocSeries;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatterySocSeries create() => BatterySocSeries._();
  @$core.override
  BatterySocSeries createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BatterySocSeries getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatterySocSeries>(create);
  static BatterySocSeries? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nodeId => $_getI64(0);
  @$pb.TagNumber(1)
  set nodeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get socPct => $_getN(2);
  @$pb.TagNumber(3)
  set socPct($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSocPct() => $_has(2);
  @$pb.TagNumber(3)
  void clearSocPct() => $_clearField(3);

  @$pb.TagNumber(4)
  DeviceKind get kind => $_getN(3);
  @$pb.TagNumber(4)
  set kind(DeviceKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);
}

class EnergyHistory extends $pb.GeneratedMessage {
  factory EnergyHistory({
    $fixnum.Int64? start,
    $core.int? bucketSeconds,
    $fixnum.Int64? from,
    $fixnum.Int64? to,
    $core.bool? timeSynced,
    $core.bool? truncated,
    $core.Iterable<EnergyBucket>? buckets,
    $core.Iterable<EnergyDeviceSeries>? deviceSeries,
    $core.Iterable<BatterySocSeries>? batterySoc,
  }) {
    final result = create();
    if (start != null) result.start = start;
    if (bucketSeconds != null) result.bucketSeconds = bucketSeconds;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (timeSynced != null) result.timeSynced = timeSynced;
    if (truncated != null) result.truncated = truncated;
    if (buckets != null) result.buckets.addAll(buckets);
    if (deviceSeries != null) result.deviceSeries.addAll(deviceSeries);
    if (batterySoc != null) result.batterySoc.addAll(batterySoc);
    return result;
  }

  EnergyHistory._();

  factory EnergyHistory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnergyHistory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnergyHistory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'start')
    ..aI(2, _omitFieldNames ? '' : 'bucketSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aInt64(3, _omitFieldNames ? '' : 'from')
    ..aInt64(4, _omitFieldNames ? '' : 'to')
    ..aOB(5, _omitFieldNames ? '' : 'timeSynced')
    ..aOB(6, _omitFieldNames ? '' : 'truncated')
    ..pPM<EnergyBucket>(7, _omitFieldNames ? '' : 'buckets',
        subBuilder: EnergyBucket.create)
    ..pPM<EnergyDeviceSeries>(8, _omitFieldNames ? '' : 'deviceSeries',
        subBuilder: EnergyDeviceSeries.create)
    ..pPM<BatterySocSeries>(9, _omitFieldNames ? '' : 'batterySoc',
        subBuilder: BatterySocSeries.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyHistory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnergyHistory copyWith(void Function(EnergyHistory) updates) =>
      super.copyWith((message) => updates(message as EnergyHistory))
          as EnergyHistory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnergyHistory create() => EnergyHistory._();
  @$core.override
  EnergyHistory createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnergyHistory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnergyHistory>(create);
  static EnergyHistory? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get start => $_getI64(0);
  @$pb.TagNumber(1)
  set start($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearStart() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get bucketSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set bucketSeconds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBucketSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearBucketSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get from => $_getI64(2);
  @$pb.TagNumber(3)
  set from($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrom() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrom() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get to => $_getI64(3);
  @$pb.TagNumber(4)
  set to($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTo() => $_has(3);
  @$pb.TagNumber(4)
  void clearTo() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get timeSynced => $_getBF(4);
  @$pb.TagNumber(5)
  set timeSynced($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimeSynced() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimeSynced() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get truncated => $_getBF(5);
  @$pb.TagNumber(6)
  set truncated($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTruncated() => $_has(5);
  @$pb.TagNumber(6)
  void clearTruncated() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<EnergyBucket> get buckets => $_getList(6);

  /// Per-device breakdown (PV only for now); the buckets above stay the summed
  /// per-class totals. Capped — excess devices simply aren't broken out.
  @$pb.TagNumber(8)
  $pb.PbList<EnergyDeviceSeries> get deviceSeries => $_getList(7);

  /// Per-battery SOC lines (measured), index-aligned to buckets.
  @$pb.TagNumber(9)
  $pb.PbList<BatterySocSeries> get batterySoc => $_getList(8);
}

/// GET /prices — the current + upcoming day-ahead curve.
class PriceCurve extends $pb.GeneratedMessage {
  factory PriceCurve({
    $fixnum.Int64? startEpoch,
    $core.int? resolutionSeconds,
    $core.String? currency,
    PriceUnit? unit,
    $core.Iterable<$core.int>? prices,
    $fixnum.Int64? fetchedAt,
    $core.bool? stale,
  }) {
    final result = create();
    if (startEpoch != null) result.startEpoch = startEpoch;
    if (resolutionSeconds != null) result.resolutionSeconds = resolutionSeconds;
    if (currency != null) result.currency = currency;
    if (unit != null) result.unit = unit;
    if (prices != null) result.prices.addAll(prices);
    if (fetchedAt != null) result.fetchedAt = fetchedAt;
    if (stale != null) result.stale = stale;
    return result;
  }

  PriceCurve._();

  factory PriceCurve.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PriceCurve.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PriceCurve',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'startEpoch')
    ..aI(2, _omitFieldNames ? '' : 'resolutionSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'currency')
    ..aE<PriceUnit>(4, _omitFieldNames ? '' : 'unit',
        enumValues: PriceUnit.values)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'prices', $pb.PbFieldType.KS3)
    ..aInt64(6, _omitFieldNames ? '' : 'fetchedAt')
    ..aOB(7, _omitFieldNames ? '' : 'stale')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PriceCurve clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PriceCurve copyWith(void Function(PriceCurve) updates) =>
      super.copyWith((message) => updates(message as PriceCurve)) as PriceCurve;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PriceCurve create() => PriceCurve._();
  @$core.override
  PriceCurve createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PriceCurve getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PriceCurve>(create);
  static PriceCurve? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get startEpoch => $_getI64(0);
  @$pb.TagNumber(1)
  set startEpoch($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartEpoch() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartEpoch() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get resolutionSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set resolutionSeconds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResolutionSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearResolutionSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get currency => $_getSZ(2);
  @$pb.TagNumber(3)
  set currency($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrency() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrency() => $_clearField(3);

  @$pb.TagNumber(4)
  PriceUnit get unit => $_getN(3);
  @$pb.TagNumber(4)
  set unit(PriceUnit value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUnit() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnit() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get prices => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get fetchedAt => $_getI64(5);
  @$pb.TagNumber(6)
  set fetchedAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFetchedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearFetchedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get stale => $_getBF(6);
  @$pb.TagNumber(7)
  set stale($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStale() => $_has(6);
  @$pb.TagNumber(7)
  void clearStale() => $_clearField(7);
}

/// GET/POST /prices/config — pricing acquisition settings (persisted in NVS).
class PricingConfig extends $pb.GeneratedMessage {
  factory PricingConfig({
    $core.bool? enabled,
    $core.String? provider,
    $core.String? zone,
    $core.String? apiToken,
    $core.String? baseUrl,
    $core.int? fetchHourLocal,
    $core.int? markupUeurPerKwh,
    $core.int? vatPercent,
    $core.int? feedInUeurPerKwh,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (provider != null) result.provider = provider;
    if (zone != null) result.zone = zone;
    if (apiToken != null) result.apiToken = apiToken;
    if (baseUrl != null) result.baseUrl = baseUrl;
    if (fetchHourLocal != null) result.fetchHourLocal = fetchHourLocal;
    if (markupUeurPerKwh != null) result.markupUeurPerKwh = markupUeurPerKwh;
    if (vatPercent != null) result.vatPercent = vatPercent;
    if (feedInUeurPerKwh != null) result.feedInUeurPerKwh = feedInUeurPerKwh;
    return result;
  }

  PricingConfig._();

  factory PricingConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PricingConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PricingConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aOS(2, _omitFieldNames ? '' : 'provider')
    ..aOS(3, _omitFieldNames ? '' : 'zone')
    ..aOS(4, _omitFieldNames ? '' : 'apiToken')
    ..aOS(5, _omitFieldNames ? '' : 'baseUrl')
    ..aI(6, _omitFieldNames ? '' : 'fetchHourLocal',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'markupUeurPerKwh',
        fieldType: $pb.PbFieldType.OS3)
    ..aI(8, _omitFieldNames ? '' : 'vatPercent', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'feedInUeurPerKwh',
        fieldType: $pb.PbFieldType.OS3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PricingConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PricingConfig copyWith(void Function(PricingConfig) updates) =>
      super.copyWith((message) => updates(message as PricingConfig))
          as PricingConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PricingConfig create() => PricingConfig._();
  @$core.override
  PricingConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PricingConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PricingConfig>(create);
  static PricingConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get provider => $_getSZ(1);
  @$pb.TagNumber(2)
  set provider($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get zone => $_getSZ(2);
  @$pb.TagNumber(3)
  set zone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasZone() => $_has(2);
  @$pb.TagNumber(3)
  void clearZone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get apiToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set apiToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasApiToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearApiToken() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get baseUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set baseUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBaseUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearBaseUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get fetchHourLocal => $_getIZ(5);
  @$pb.TagNumber(6)
  set fetchHourLocal($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFetchHourLocal() => $_has(5);
  @$pb.TagNumber(6)
  void clearFetchHourLocal() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get markupUeurPerKwh => $_getIZ(6);
  @$pb.TagNumber(7)
  set markupUeurPerKwh($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMarkupUeurPerKwh() => $_has(6);
  @$pb.TagNumber(7)
  void clearMarkupUeurPerKwh() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get vatPercent => $_getIZ(7);
  @$pb.TagNumber(8)
  set vatPercent($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVatPercent() => $_has(7);
  @$pb.TagNumber(8)
  void clearVatPercent() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get feedInUeurPerKwh => $_getIZ(8);
  @$pb.TagNumber(9)
  set feedInUeurPerKwh($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFeedInUeurPerKwh() => $_has(8);
  @$pb.TagNumber(9)
  void clearFeedInUeurPerKwh() => $_clearField(9);
}

/// One roof plane.
///
/// AZIMUTH CONVENTION: the compass bearing the panel surface FACES, degrees
/// clockwise from true north. 0 = N, 90 = E, 180 = S, 270 = W. (Note this
/// differs from pvlib's solar-azimuth convention and from Forecast.Solar's
/// south-relative -90..+90; the value here is a plain compass bearing.)
class SolarPlane extends $pb.GeneratedMessage {
  factory SolarPlane({
    $core.int? tiltDeg,
    $core.int? azimuthDeg,
    $core.int? kwpW,
  }) {
    final result = create();
    if (tiltDeg != null) result.tiltDeg = tiltDeg;
    if (azimuthDeg != null) result.azimuthDeg = azimuthDeg;
    if (kwpW != null) result.kwpW = kwpW;
    return result;
  }

  SolarPlane._();

  factory SolarPlane.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SolarPlane.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SolarPlane',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'tiltDeg', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'azimuthDeg', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'kwpW', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarPlane clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarPlane copyWith(void Function(SolarPlane) updates) =>
      super.copyWith((message) => updates(message as SolarPlane)) as SolarPlane;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SolarPlane create() => SolarPlane._();
  @$core.override
  SolarPlane createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SolarPlane getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SolarPlane>(create);
  static SolarPlane? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get tiltDeg => $_getIZ(0);
  @$pb.TagNumber(1)
  set tiltDeg($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTiltDeg() => $_has(0);
  @$pb.TagNumber(1)
  void clearTiltDeg() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get azimuthDeg => $_getIZ(1);
  @$pb.TagNumber(2)
  set azimuthDeg($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAzimuthDeg() => $_has(1);
  @$pb.TagNumber(2)
  void clearAzimuthDeg() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get kwpW => $_getIZ(2);
  @$pb.TagNumber(3)
  set kwpW($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKwpW() => $_has(2);
  @$pb.TagNumber(3)
  void clearKwpW() => $_clearField(3);
}

/// GET/POST /solar/config — forecast acquisition + site model (persisted in NVS).
/// Writes are LAN-only, like the other config surfaces (ADR-0012).
class SolarConfig extends $pb.GeneratedMessage {
  factory SolarConfig({
    $core.bool? enabled,
    $core.String? provider,
    $core.int? latitudeUdeg,
    $core.int? longitudeUdeg,
    $core.Iterable<SolarPlane>? planes,
    $core.int? inverterAcW,
    $core.int? systemLossPct,
    $core.int? albedoPct,
    $core.int? tempCoeffPpmPerK,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (provider != null) result.provider = provider;
    if (latitudeUdeg != null) result.latitudeUdeg = latitudeUdeg;
    if (longitudeUdeg != null) result.longitudeUdeg = longitudeUdeg;
    if (planes != null) result.planes.addAll(planes);
    if (inverterAcW != null) result.inverterAcW = inverterAcW;
    if (systemLossPct != null) result.systemLossPct = systemLossPct;
    if (albedoPct != null) result.albedoPct = albedoPct;
    if (tempCoeffPpmPerK != null) result.tempCoeffPpmPerK = tempCoeffPpmPerK;
    return result;
  }

  SolarConfig._();

  factory SolarConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SolarConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SolarConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aOS(2, _omitFieldNames ? '' : 'provider')
    ..aI(3, _omitFieldNames ? '' : 'latitudeUdeg',
        fieldType: $pb.PbFieldType.OS3)
    ..aI(4, _omitFieldNames ? '' : 'longitudeUdeg',
        fieldType: $pb.PbFieldType.OS3)
    ..pPM<SolarPlane>(5, _omitFieldNames ? '' : 'planes',
        subBuilder: SolarPlane.create)
    ..aI(6, _omitFieldNames ? '' : 'inverterAcW',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'systemLossPct',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'albedoPct', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'tempCoeffPpmPerK',
        fieldType: $pb.PbFieldType.OS3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarConfig copyWith(void Function(SolarConfig) updates) =>
      super.copyWith((message) => updates(message as SolarConfig))
          as SolarConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SolarConfig create() => SolarConfig._();
  @$core.override
  SolarConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SolarConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SolarConfig>(create);
  static SolarConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get provider => $_getSZ(1);
  @$pb.TagNumber(2)
  set provider($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get latitudeUdeg => $_getIZ(2);
  @$pb.TagNumber(3)
  set latitudeUdeg($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLatitudeUdeg() => $_has(2);
  @$pb.TagNumber(3)
  void clearLatitudeUdeg() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get longitudeUdeg => $_getIZ(3);
  @$pb.TagNumber(4)
  set longitudeUdeg($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLongitudeUdeg() => $_has(3);
  @$pb.TagNumber(4)
  void clearLongitudeUdeg() => $_clearField(4);

  /// Only planes[0] is modelled today. The field is repeated from day one so
  /// multi-plane (east/west split) support is a firmware change and never a
  /// wire migration.
  @$pb.TagNumber(5)
  $pb.PbList<SolarPlane> get planes => $_getList(4);

  /// Inverter AC clipping limit in watts; 0 = no clipping. Measured arrays are
  /// routinely DC-oversized ~1.4x, and without this clear-sky midday hours
  /// over-predict by ~15%.
  @$pb.TagNumber(6)
  $core.int get inverterAcW => $_getIZ(5);
  @$pb.TagNumber(6)
  set inverterAcW($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInverterAcW() => $_has(5);
  @$pb.TagNumber(6)
  void clearInverterAcW() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get systemLossPct => $_getIZ(6);
  @$pb.TagNumber(7)
  set systemLossPct($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSystemLossPct() => $_has(6);
  @$pb.TagNumber(7)
  void clearSystemLossPct() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get albedoPct => $_getIZ(7);
  @$pb.TagNumber(8)
  set albedoPct($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAlbedoPct() => $_has(7);
  @$pb.TagNumber(8)
  void clearAlbedoPct() => $_clearField(8);

  /// Module power temperature coefficient, ppm per kelvin, negative. 0 =
  /// default -4000 (i.e. -0.40 %/K).
  @$pb.TagNumber(9)
  $core.int get tempCoeffPpmPerK => $_getIZ(8);
  @$pb.TagNumber(9)
  set tempCoeffPpmPerK($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTempCoeffPpmPerK() => $_has(8);
  @$pb.TagNumber(9)
  void clearTempCoeffPpmPerK() => $_clearField(9);
}

/// GET /solar/forecast — predicted AC production per interval. Mirrors PriceCurve
/// so the app can reuse its curve rendering.
class SolarForecast extends $pb.GeneratedMessage {
  factory SolarForecast({
    $fixnum.Int64? startEpoch,
    $core.int? resolutionSeconds,
    $core.Iterable<$core.int>? wattHours,
    $fixnum.Int64? fetchedAt,
    $core.bool? stale,
    $core.int? todayWh,
    $core.int? tomorrowWh,
  }) {
    final result = create();
    if (startEpoch != null) result.startEpoch = startEpoch;
    if (resolutionSeconds != null) result.resolutionSeconds = resolutionSeconds;
    if (wattHours != null) result.wattHours.addAll(wattHours);
    if (fetchedAt != null) result.fetchedAt = fetchedAt;
    if (stale != null) result.stale = stale;
    if (todayWh != null) result.todayWh = todayWh;
    if (tomorrowWh != null) result.tomorrowWh = tomorrowWh;
    return result;
  }

  SolarForecast._();

  factory SolarForecast.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SolarForecast.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SolarForecast',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'startEpoch')
    ..aI(2, _omitFieldNames ? '' : 'resolutionSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..p<$core.int>(3, _omitFieldNames ? '' : 'wattHours', $pb.PbFieldType.KU3)
    ..aInt64(4, _omitFieldNames ? '' : 'fetchedAt')
    ..aOB(5, _omitFieldNames ? '' : 'stale')
    ..aI(6, _omitFieldNames ? '' : 'todayWh', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'tomorrowWh', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarForecast clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SolarForecast copyWith(void Function(SolarForecast) updates) =>
      super.copyWith((message) => updates(message as SolarForecast))
          as SolarForecast;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SolarForecast create() => SolarForecast._();
  @$core.override
  SolarForecast createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SolarForecast getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SolarForecast>(create);
  static SolarForecast? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get startEpoch => $_getI64(0);
  @$pb.TagNumber(1)
  set startEpoch($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartEpoch() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartEpoch() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get resolutionSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set resolutionSeconds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResolutionSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearResolutionSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get wattHours => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get fetchedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set fetchedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFetchedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearFetchedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get stale => $_getBF(4);
  @$pb.TagNumber(5)
  set stale($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStale() => $_has(4);
  @$pb.TagNumber(5)
  void clearStale() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get todayWh => $_getIZ(5);
  @$pb.TagNumber(6)
  set todayWh($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTodayWh() => $_has(5);
  @$pb.TagNumber(6)
  void clearTodayWh() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get tomorrowWh => $_getIZ(6);
  @$pb.TagNumber(7)
  set tomorrowWh($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTomorrowWh() => $_has(6);
  @$pb.TagNumber(7)
  void clearTomorrowWh() => $_clearField(7);
}

class StunServer extends $pb.GeneratedMessage {
  factory StunServer({
    $core.String? host,
    $core.int? port,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    return result;
  }

  StunServer._();

  factory StunServer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StunServer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StunServer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StunServer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StunServer copyWith(void Function(StunServer) updates) =>
      super.copyWith((message) => updates(message as StunServer)) as StunServer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StunServer create() => StunServer._();
  @$core.override
  StunServer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StunServer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StunServer>(create);
  static StunServer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);
}

class TurnServer extends $pb.GeneratedMessage {
  factory TurnServer({
    $core.String? host,
    $core.int? port,
    $core.String? username,
    $core.String? credential,
  }) {
    final result = create();
    if (host != null) result.host = host;
    if (port != null) result.port = port;
    if (username != null) result.username = username;
    if (credential != null) result.credential = credential;
    return result;
  }

  TurnServer._();

  factory TurnServer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TurnServer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TurnServer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'username')
    ..aOS(4, _omitFieldNames ? '' : 'credential')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TurnServer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TurnServer copyWith(void Function(TurnServer) updates) =>
      super.copyWith((message) => updates(message as TurnServer)) as TurnServer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TurnServer create() => TurnServer._();
  @$core.override
  TurnServer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TurnServer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TurnServer>(create);
  static TurnServer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get username => $_getSZ(2);
  @$pb.TagNumber(3)
  set username($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsername() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get credential => $_getSZ(3);
  @$pb.TagNumber(4)
  set credential($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCredential() => $_has(3);
  @$pb.TagNumber(4)
  void clearCredential() => $_clearField(4);
}

/// GET/PUT /remote/config — user-owned STUN/TURN/rendezvous + master enable.
/// Persisted in NVS (ns "flux_remote"); writes are LAN-only (ADR-0012).
class RemoteConfig extends $pb.GeneratedMessage {
  factory RemoteConfig({
    $core.bool? enabled,
    $core.Iterable<StunServer>? stun,
    $core.Iterable<TurnServer>? turn,
    $core.String? rendezvousUrl,
    $core.String? rendezvousCertPin,
    $core.int? cfgGen,
    $core.int? protoMin,
    $core.int? protoMax,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (stun != null) result.stun.addAll(stun);
    if (turn != null) result.turn.addAll(turn);
    if (rendezvousUrl != null) result.rendezvousUrl = rendezvousUrl;
    if (rendezvousCertPin != null) result.rendezvousCertPin = rendezvousCertPin;
    if (cfgGen != null) result.cfgGen = cfgGen;
    if (protoMin != null) result.protoMin = protoMin;
    if (protoMax != null) result.protoMax = protoMax;
    return result;
  }

  RemoteConfig._();

  factory RemoteConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoteConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoteConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..pPM<StunServer>(2, _omitFieldNames ? '' : 'stun',
        subBuilder: StunServer.create)
    ..pPM<TurnServer>(3, _omitFieldNames ? '' : 'turn',
        subBuilder: TurnServer.create)
    ..aOS(4, _omitFieldNames ? '' : 'rendezvousUrl')
    ..aOS(5, _omitFieldNames ? '' : 'rendezvousCertPin')
    ..aI(6, _omitFieldNames ? '' : 'cfgGen', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'protoMin', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'protoMax', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteConfig copyWith(void Function(RemoteConfig) updates) =>
      super.copyWith((message) => updates(message as RemoteConfig))
          as RemoteConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoteConfig create() => RemoteConfig._();
  @$core.override
  RemoteConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoteConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteConfig>(create);
  static RemoteConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<StunServer> get stun => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<TurnServer> get turn => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get rendezvousUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set rendezvousUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRendezvousUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearRendezvousUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get rendezvousCertPin => $_getSZ(4);
  @$pb.TagNumber(5)
  set rendezvousCertPin($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRendezvousCertPin() => $_has(4);
  @$pb.TagNumber(5)
  void clearRendezvousCertPin() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get cfgGen => $_getIZ(5);
  @$pb.TagNumber(6)
  set cfgGen($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCfgGen() => $_has(5);
  @$pb.TagNumber(6)
  void clearCfgGen() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get protoMin => $_getIZ(6);
  @$pb.TagNumber(7)
  set protoMin($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProtoMin() => $_has(6);
  @$pb.TagNumber(7)
  void clearProtoMin() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get protoMax => $_getIZ(7);
  @$pb.TagNumber(8)
  set protoMax($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasProtoMax() => $_has(7);
  @$pb.TagNumber(8)
  void clearProtoMax() => $_clearField(8);
}

class IceSignal extends $pb.GeneratedMessage {
  factory IceSignal({
    IceSignalKind? kind,
    $core.String? sdp,
    $core.List<$core.int>? mac,
    $core.int? protoVersion,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (sdp != null) result.sdp = sdp;
    if (mac != null) result.mac = mac;
    if (protoVersion != null) result.protoVersion = protoVersion;
    return result;
  }

  IceSignal._();

  factory IceSignal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IceSignal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IceSignal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'flux'),
      createEmptyInstance: create)
    ..aE<IceSignalKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: IceSignalKind.values)
    ..aOS(2, _omitFieldNames ? '' : 'sdp')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'mac', $pb.PbFieldType.OY)
    ..aI(4, _omitFieldNames ? '' : 'protoVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IceSignal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IceSignal copyWith(void Function(IceSignal) updates) =>
      super.copyWith((message) => updates(message as IceSignal)) as IceSignal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IceSignal create() => IceSignal._();
  @$core.override
  IceSignal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IceSignal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IceSignal>(create);
  static IceSignal? _defaultInstance;

  @$pb.TagNumber(1)
  IceSignalKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(IceSignalKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sdp => $_getSZ(1);
  @$pb.TagNumber(2)
  set sdp($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSdp() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdp() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get mac => $_getN(2);
  @$pb.TagNumber(3)
  set mac($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMac() => $_has(2);
  @$pb.TagNumber(3)
  void clearMac() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get protoVersion => $_getIZ(3);
  @$pb.TagNumber(4)
  set protoVersion($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProtoVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearProtoVersion() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
