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
/// Commission-then-handoff (standard Matter multi-admin).  The phone has already
/// BLE-commissioned the device onto a throwaway phone fabric and pushed the hub's
/// Thread credentials, then opened an Enhanced Commissioning Method (ECM) window
/// on the device.  It hands the controller the window's passcode + discriminator;
/// the controller discovers the device over Thread (commissionable DNS-SD),
/// performs PASE, and commissions it onto the controller's *own* fabric with its
/// own CA — so no device CSR ever leaves the controller and /fabric/sign-noc is
/// not needed.  On success the controller has an operational session and registers
/// + subscribes the device itself (no separate /node/register call required).
///
/// The phone then verifies the device's Fabrics attribute shows fabric_id before
/// removing its throwaway fabric (RemoveFabric).  See docs/flows.md.
class CommissionRequest extends $pb.GeneratedMessage {
  factory CommissionRequest({
    $core.int? passcode,
    $core.int? discriminator,
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.int? vendorId,
    $core.int? productId,
    $core.int? deviceType,
    $core.String? deviceAddress,
    $core.int? devicePort,
  }) {
    final result = create();
    if (passcode != null) result.passcode = passcode;
    if (discriminator != null) result.discriminator = discriminator;
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (vendorId != null) result.vendorId = vendorId;
    if (productId != null) result.productId = productId;
    if (deviceType != null) result.deviceType = deviceType;
    if (deviceAddress != null) result.deviceAddress = deviceAddress;
    if (devicePort != null) result.devicePort = devicePort;
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
    ..aOS(8, _omitFieldNames ? '' : 'deviceAddress')
    ..aI(9, _omitFieldNames ? '' : 'devicePort', fieldType: $pb.PbFieldType.OU3)
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

  /// The device's commissionable IPv6 + port, as the phone resolved them from
  /// its own mDNS scan of the open ECM window. When set, the controller PASEs
  /// this address directly and skips DNS-SD discovery — the OTBR's SRP->mDNS
  /// proxy strips the discriminator/CM TXT on the controller's local query, so
  /// controller-side discovery cannot identify the device. Empty = discover.
  @$pb.TagNumber(8)
  $core.String get deviceAddress => $_getSZ(7);
  @$pb.TagNumber(8)
  set deviceAddress($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDeviceAddress() => $_has(7);
  @$pb.TagNumber(8)
  void clearDeviceAddress() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get devicePort => $_getIZ(8);
  @$pb.TagNumber(9)
  set devicePort($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDevicePort() => $_has(8);
  @$pb.TagNumber(9)
  void clearDevicePort() => $_clearField(9);
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

class Device extends $pb.GeneratedMessage {
  factory Device({
    $fixnum.Int64? nodeId,
    $core.String? name,
    $core.bool? reachable,
    $core.int? vendorId,
    $core.int? productId,
    $core.int? deviceType,
    ConnectivityState? connectivity,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
    if (reachable != null) result.reachable = reachable;
    if (vendorId != null) result.vendorId = vendorId;
    if (productId != null) result.productId = productId;
    if (deviceType != null) result.deviceType = deviceType;
    if (connectivity != null) result.connectivity = connectivity;
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

/// POST /devices/{id}/name
class RenameDeviceRequest extends $pb.GeneratedMessage {
  factory RenameDeviceRequest({
    $fixnum.Int64? nodeId,
    $core.String? name,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (name != null) result.name = name;
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
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (attrs != null) result.attrs.addAll(attrs);
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
}

/// Pushed when a subscription changes state or attributes are updated.
class DeviceStateEvent extends $pb.GeneratedMessage {
  factory DeviceStateEvent({
    $fixnum.Int64? nodeId,
    DeviceEventType? type,
    AttrsUpdate? update,
    $core.String? error,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (type != null) result.type = type;
    if (update != null) result.update = update;
    if (error != null) result.error = error;
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
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointId != null) result.endpointId = endpointId;
    if (clusterId != null) result.clusterId = clusterId;
    if (commandId != null) result.commandId = commandId;
    if (args != null) result.args.addAll(args);
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
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointId != null) result.endpointId = endpointId;
    if (clusterId != null) result.clusterId = clusterId;
    if (attrId != null) result.attrId = attrId;
    if (boolVal != null) result.boolVal = boolVal;
    if (intVal != null) result.intVal = intVal;
    if (jsonVal != null) result.jsonVal = jsonVal;
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
}

/// Read one or more cluster attributes.
class ReadRequest extends $pb.GeneratedMessage {
  factory ReadRequest({
    $fixnum.Int64? nodeId,
    $core.Iterable<$core.int>? endpointIds,
    $core.Iterable<$core.int>? clusterIds,
    $core.Iterable<$core.int>? attrIds,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (endpointIds != null) result.endpointIds.addAll(endpointIds);
    if (clusterIds != null) result.clusterIds.addAll(clusterIds);
    if (attrIds != null) result.attrIds.addAll(attrIds);
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
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (gridImportWh != null) result.gridImportWh = gridImportWh;
    if (gridExportWh != null) result.gridExportWh = gridExportWh;
    if (pvWh != null) result.pvWh = pvWh;
    if (loadWh != null) result.loadWh = loadWh;
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
  }) {
    final result = create();
    if (start != null) result.start = start;
    if (bucketSeconds != null) result.bucketSeconds = bucketSeconds;
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (timeSynced != null) result.timeSynced = timeSynced;
    if (truncated != null) result.truncated = truncated;
    if (buckets != null) result.buckets.addAll(buckets);
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
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
