// This is a generated file - do not edit.
//
// Generated from flux.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use connectivityStateDescriptor instead')
const ConnectivityState$json = {
  '1': 'ConnectivityState',
  '2': [
    {'1': 'CONNECTIVITY_UNKNOWN', '2': 0},
    {'1': 'CONNECTIVITY_DISCOVERING', '2': 1},
    {'1': 'CONNECTIVITY_SUBSCRIBED', '2': 2},
    {'1': 'CONNECTIVITY_RETRYING', '2': 3},
  ],
};

/// Descriptor for `ConnectivityState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List connectivityStateDescriptor = $convert.base64Decode(
    'ChFDb25uZWN0aXZpdHlTdGF0ZRIYChRDT05ORUNUSVZJVFlfVU5LTk9XThAAEhwKGENPTk5FQ1'
    'RJVklUWV9ESVNDT1ZFUklORxABEhsKF0NPTk5FQ1RJVklUWV9TVUJTQ1JJQkVEEAISGQoVQ09O'
    'TkVDVElWSVRZX1JFVFJZSU5HEAM=');

@$core.Deprecated('Use deviceKindDescriptor instead')
const DeviceKind$json = {
  '1': 'DeviceKind',
  '2': [
    {'1': 'DEVICE_KIND_UNKNOWN', '2': 0},
    {'1': 'DEVICE_KIND_MATTER', '2': 1},
    {'1': 'DEVICE_KIND_MODBUS', '2': 2},
    {'1': 'DEVICE_KIND_CLOUD', '2': 3},
  ],
};

/// Descriptor for `DeviceKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceKindDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VLaW5kEhcKE0RFVklDRV9LSU5EX1VOS05PV04QABIWChJERVZJQ0VfS0lORF9NQV'
    'RURVIQARIWChJERVZJQ0VfS0lORF9NT0RCVVMQAhIVChFERVZJQ0VfS0lORF9DTE9VRBAD');

@$core.Deprecated('Use energyRoleDescriptor instead')
const EnergyRole$json = {
  '1': 'EnergyRole',
  '2': [
    {'1': 'ENERGY_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'ENERGY_ROLE_GRID', '2': 1},
    {'1': 'ENERGY_ROLE_PV', '2': 2},
    {'1': 'ENERGY_ROLE_CAR_CHARGER', '2': 3},
    {'1': 'ENERGY_ROLE_HEAT_PUMP', '2': 4},
    {'1': 'ENERGY_ROLE_HOME_BATTERY', '2': 5},
    {'1': 'ENERGY_ROLE_LOAD', '2': 6},
    {'1': 'ENERGY_ROLE_HOME_CONSUMER', '2': 7},
  ],
};

/// Descriptor for `EnergyRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List energyRoleDescriptor = $convert.base64Decode(
    'CgpFbmVyZ3lSb2xlEhsKF0VORVJHWV9ST0xFX1VOU1BFQ0lGSUVEEAASFAoQRU5FUkdZX1JPTE'
    'VfR1JJRBABEhIKDkVORVJHWV9ST0xFX1BWEAISGwoXRU5FUkdZX1JPTEVfQ0FSX0NIQVJHRVIQ'
    'AxIZChVFTkVSR1lfUk9MRV9IRUFUX1BVTVAQBBIcChhFTkVSR1lfUk9MRV9IT01FX0JBVFRFUl'
    'kQBRIUChBFTkVSR1lfUk9MRV9MT0FEEAYSHQoZRU5FUkdZX1JPTEVfSE9NRV9DT05TVU1FUhAH');

@$core.Deprecated('Use modbusProfileDescriptor instead')
const ModbusProfile$json = {
  '1': 'ModbusProfile',
  '2': [
    {'1': 'MODBUS_PROFILE_SUNSPEC', '2': 0},
    {'1': 'MODBUS_PROFILE_UNKNOWN', '2': 1},
    {'1': 'MODBUS_PROFILE_VM3P75CT', '2': 2},
    {'1': 'MODBUS_PROFILE_VICTRON_VENUS', '2': 3},
    {'1': 'MODBUS_PROFILE_SHELLY_PRO3EM', '2': 4},
  ],
};

/// Descriptor for `ModbusProfile`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List modbusProfileDescriptor = $convert.base64Decode(
    'Cg1Nb2RidXNQcm9maWxlEhoKFk1PREJVU19QUk9GSUxFX1NVTlNQRUMQABIaChZNT0RCVVNfUF'
    'JPRklMRV9VTktOT1dOEAESGwoXTU9EQlVTX1BST0ZJTEVfVk0zUDc1Q1QQAhIgChxNT0RCVVNf'
    'UFJPRklMRV9WSUNUUk9OX1ZFTlVTEAMSIAocTU9EQlVTX1BST0ZJTEVfU0hFTExZX1BSTzNFTR'
    'AE');

@$core.Deprecated('Use modbusTransportDescriptor instead')
const ModbusTransport$json = {
  '1': 'ModbusTransport',
  '2': [
    {'1': 'MODBUS_TRANSPORT_TCP', '2': 0},
    {'1': 'MODBUS_TRANSPORT_UDP', '2': 1},
  ],
};

/// Descriptor for `ModbusTransport`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List modbusTransportDescriptor = $convert.base64Decode(
    'Cg9Nb2RidXNUcmFuc3BvcnQSGAoUTU9EQlVTX1RSQU5TUE9SVF9UQ1AQABIYChRNT0RCVVNfVF'
    'JBTlNQT1JUX1VEUBAB');

@$core.Deprecated('Use deviceEventTypeDescriptor instead')
const DeviceEventType$json = {
  '1': 'DeviceEventType',
  '2': [
    {'1': 'DEVICE_EVENT_ESTABLISHED', '2': 0},
    {'1': 'DEVICE_EVENT_ATTRS_UPDATE', '2': 1},
    {'1': 'DEVICE_EVENT_ERROR', '2': 2},
    {'1': 'DEVICE_EVENT_RESUBSCRIBING', '2': 3},
    {'1': 'DEVICE_EVENT_DISCOVERING', '2': 4},
  ],
};

/// Descriptor for `DeviceEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceEventTypeDescriptor = $convert.base64Decode(
    'Cg9EZXZpY2VFdmVudFR5cGUSHAoYREVWSUNFX0VWRU5UX0VTVEFCTElTSEVEEAASHQoZREVWSU'
    'NFX0VWRU5UX0FUVFJTX1VQREFURRABEhYKEkRFVklDRV9FVkVOVF9FUlJPUhACEh4KGkRFVklD'
    'RV9FVkVOVF9SRVNVQlNDUklCSU5HEAMSHAoYREVWSUNFX0VWRU5UX0RJU0NPVkVSSU5HEAQ=');

@$core.Deprecated('Use energyClassDescriptor instead')
const EnergyClass$json = {
  '1': 'EnergyClass',
  '2': [
    {'1': 'ENERGY_CLASS_UNKNOWN', '2': 0},
    {'1': 'ENERGY_CLASS_GRID', '2': 1},
    {'1': 'ENERGY_CLASS_PV', '2': 2},
    {'1': 'ENERGY_CLASS_LOAD', '2': 3},
    {'1': 'ENERGY_CLASS_BATTERY', '2': 4},
  ],
};

/// Descriptor for `EnergyClass`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List energyClassDescriptor = $convert.base64Decode(
    'CgtFbmVyZ3lDbGFzcxIYChRFTkVSR1lfQ0xBU1NfVU5LTk9XThAAEhUKEUVORVJHWV9DTEFTU1'
    '9HUklEEAESEwoPRU5FUkdZX0NMQVNTX1BWEAISFQoRRU5FUkdZX0NMQVNTX0xPQUQQAxIYChRF'
    'TkVSR1lfQ0xBU1NfQkFUVEVSWRAE');

@$core.Deprecated('Use priceUnitDescriptor instead')
const PriceUnit$json = {
  '1': 'PriceUnit',
  '2': [
    {'1': 'PRICE_UNIT_UEUR_PER_KWH', '2': 0},
    {'1': 'PRICE_UNIT_EUR_PER_MWH', '2': 1},
  ],
};

/// Descriptor for `PriceUnit`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List priceUnitDescriptor = $convert.base64Decode(
    'CglQcmljZVVuaXQSGwoXUFJJQ0VfVU5JVF9VRVVSX1BFUl9LV0gQABIaChZQUklDRV9VTklUX0'
    'VVUl9QRVJfTVdIEAE=');

@$core.Deprecated('Use iceSignalKindDescriptor instead')
const IceSignalKind$json = {
  '1': 'IceSignalKind',
  '2': [
    {'1': 'ICE_OFFER', '2': 0},
    {'1': 'ICE_ANSWER', '2': 1},
    {'1': 'ICE_CANDIDATE', '2': 2},
  ],
};

/// Descriptor for `IceSignalKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List iceSignalKindDescriptor = $convert.base64Decode(
    'Cg1JY2VTaWduYWxLaW5kEg0KCUlDRV9PRkZFUhAAEg4KCklDRV9BTlNXRVIQARIRCg1JQ0VfQ0'
    'FORElEQVRFEAI=');

@$core.Deprecated('Use controllerInfoDescriptor instead')
const ControllerInfo$json = {
  '1': 'ControllerInfo',
  '2': [
    {'1': 'firmware_version', '3': 1, '4': 1, '5': 9, '10': 'firmwareVersion'},
    {'1': 'hostname', '3': 2, '4': 1, '5': 9, '10': 'hostname'},
    {'1': 'ethernet_ip', '3': 3, '4': 1, '5': 9, '10': 'ethernetIp'},
    {'1': 'ethernet_up', '3': 4, '4': 1, '5': 8, '10': 'ethernetUp'},
    {'1': 'fabric_id', '3': 5, '4': 1, '5': 4, '10': 'fabricId'},
    {'1': 'uptime_seconds', '3': 6, '4': 1, '5': 13, '10': 'uptimeSeconds'},
    {'1': 'serial_number', '3': 7, '4': 1, '5': 9, '10': 'serialNumber'},
  ],
};

/// Descriptor for `ControllerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerInfoDescriptor = $convert.base64Decode(
    'Cg5Db250cm9sbGVySW5mbxIpChBmaXJtd2FyZV92ZXJzaW9uGAEgASgJUg9maXJtd2FyZVZlcn'
    'Npb24SGgoIaG9zdG5hbWUYAiABKAlSCGhvc3RuYW1lEh8KC2V0aGVybmV0X2lwGAMgASgJUgpl'
    'dGhlcm5ldElwEh8KC2V0aGVybmV0X3VwGAQgASgIUgpldGhlcm5ldFVwEhsKCWZhYnJpY19pZB'
    'gFIAEoBFIIZmFicmljSWQSJQoOdXB0aW1lX3NlY29uZHMYBiABKA1SDXVwdGltZVNlY29uZHMS'
    'IwoNc2VyaWFsX251bWJlchgHIAEoCVIMc2VyaWFsTnVtYmVy');

@$core.Deprecated('Use threadDatasetDescriptor instead')
const ThreadDataset$json = {
  '1': 'ThreadDataset',
  '2': [
    {'1': 'tlv', '3': 1, '4': 1, '5': 12, '10': 'tlv'},
    {'1': 'network_name', '3': 2, '4': 1, '5': 9, '10': 'networkName'},
    {'1': 'channel', '3': 3, '4': 1, '5': 13, '10': 'channel'},
    {'1': 'pan_id', '3': 4, '4': 1, '5': 13, '10': 'panId'},
    {'1': 'role', '3': 5, '4': 1, '5': 9, '10': 'role'},
    {'1': 'neighbor_count', '3': 6, '4': 1, '5': 13, '10': 'neighborCount'},
    {'1': 'rloc16', '3': 7, '4': 1, '5': 13, '10': 'rloc16'},
    {'1': 'partition_id', '3': 8, '4': 1, '5': 13, '10': 'partitionId'},
  ],
};

/// Descriptor for `ThreadDataset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadDatasetDescriptor = $convert.base64Decode(
    'Cg1UaHJlYWREYXRhc2V0EhAKA3RsdhgBIAEoDFIDdGx2EiEKDG5ldHdvcmtfbmFtZRgCIAEoCV'
    'ILbmV0d29ya05hbWUSGAoHY2hhbm5lbBgDIAEoDVIHY2hhbm5lbBIVCgZwYW5faWQYBCABKA1S'
    'BXBhbklkEhIKBHJvbGUYBSABKAlSBHJvbGUSJQoObmVpZ2hib3JfY291bnQYBiABKA1SDW5laW'
    'doYm9yQ291bnQSFgoGcmxvYzE2GAcgASgNUgZybG9jMTYSIQoMcGFydGl0aW9uX2lkGAggASgN'
    'UgtwYXJ0aXRpb25JZA==');

@$core.Deprecated('Use threadEphemeralKeyRequestDescriptor instead')
const ThreadEphemeralKeyRequest$json = {
  '1': 'ThreadEphemeralKeyRequest',
  '2': [
    {'1': 'timeout_seconds', '3': 1, '4': 1, '5': 13, '10': 'timeoutSeconds'},
  ],
};

/// Descriptor for `ThreadEphemeralKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadEphemeralKeyRequestDescriptor =
    $convert.base64Decode(
        'ChlUaHJlYWRFcGhlbWVyYWxLZXlSZXF1ZXN0EicKD3RpbWVvdXRfc2Vjb25kcxgBIAEoDVIOdG'
        'ltZW91dFNlY29uZHM=');

@$core.Deprecated('Use threadEphemeralKeyResultDescriptor instead')
const ThreadEphemeralKeyResult$json = {
  '1': 'ThreadEphemeralKeyResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'otpc', '3': 2, '4': 1, '5': 9, '10': 'otpc'},
    {'1': 'udp_port', '3': 3, '4': 1, '5': 13, '10': 'udpPort'},
    {'1': 'state', '3': 4, '4': 1, '5': 9, '10': 'state'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ThreadEphemeralKeyResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadEphemeralKeyResultDescriptor = $convert.base64Decode(
    'ChhUaHJlYWRFcGhlbWVyYWxLZXlSZXN1bHQSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxISCg'
    'RvdHBjGAIgASgJUgRvdHBjEhkKCHVkcF9wb3J0GAMgASgNUgd1ZHBQb3J0EhQKBXN0YXRlGAQg'
    'ASgJUgVzdGF0ZRIUCgVlcnJvchgFIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use threadJoinRequestDescriptor instead')
const ThreadJoinRequest$json = {
  '1': 'ThreadJoinRequest',
  '2': [
    {'1': 'target_addr', '3': 1, '4': 1, '5': 9, '10': 'targetAddr'},
    {'1': 'target_port', '3': 2, '4': 1, '5': 13, '10': 'targetPort'},
    {'1': 'ephemeral_key', '3': 3, '4': 1, '5': 9, '10': 'ephemeralKey'},
    {'1': 'apply', '3': 4, '4': 1, '5': 8, '10': 'apply'},
    {'1': 'migrate', '3': 5, '4': 1, '5': 8, '10': 'migrate'},
    {'1': 'delay_ms', '3': 6, '4': 1, '5': 13, '10': 'delayMs'},
  ],
};

/// Descriptor for `ThreadJoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadJoinRequestDescriptor = $convert.base64Decode(
    'ChFUaHJlYWRKb2luUmVxdWVzdBIfCgt0YXJnZXRfYWRkchgBIAEoCVIKdGFyZ2V0QWRkchIfCg'
    't0YXJnZXRfcG9ydBgCIAEoDVIKdGFyZ2V0UG9ydBIjCg1lcGhlbWVyYWxfa2V5GAMgASgJUgxl'
    'cGhlbWVyYWxLZXkSFAoFYXBwbHkYBCABKAhSBWFwcGx5EhgKB21pZ3JhdGUYBSABKAhSB21pZ3'
    'JhdGUSGQoIZGVsYXlfbXMYBiABKA1SB2RlbGF5TXM=');

@$core.Deprecated('Use threadJoinResultDescriptor instead')
const ThreadJoinResult$json = {
  '1': 'ThreadJoinResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'tlv', '3': 2, '4': 1, '5': 12, '10': 'tlv'},
    {'1': 'network_name', '3': 3, '4': 1, '5': 9, '10': 'networkName'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ThreadJoinResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadJoinResultDescriptor = $convert.base64Decode(
    'ChBUaHJlYWRKb2luUmVzdWx0EhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSEAoDdGx2GAIgAS'
    'gMUgN0bHYSIQoMbmV0d29ya19uYW1lGAMgASgJUgtuZXR3b3JrTmFtZRIUCgVlcnJvchgEIAEo'
    'CVIFZXJyb3I=');

@$core.Deprecated('Use threadEphemeralCandidateDescriptor instead')
const ThreadEphemeralCandidate$json = {
  '1': 'ThreadEphemeralCandidate',
  '2': [
    {'1': 'addr', '3': 1, '4': 1, '5': 9, '10': 'addr'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `ThreadEphemeralCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadEphemeralCandidateDescriptor =
    $convert.base64Decode(
        'ChhUaHJlYWRFcGhlbWVyYWxDYW5kaWRhdGUSEgoEYWRkchgBIAEoCVIEYWRkchISCgRwb3J0GA'
        'IgASgNUgRwb3J0EhIKBG5hbWUYAyABKAlSBG5hbWU=');

@$core.Deprecated('Use threadEphemeralListDescriptor instead')
const ThreadEphemeralList$json = {
  '1': 'ThreadEphemeralList',
  '2': [
    {
      '1': 'candidates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.flux.ThreadEphemeralCandidate',
      '10': 'candidates'
    },
  ],
};

/// Descriptor for `ThreadEphemeralList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadEphemeralListDescriptor = $convert.base64Decode(
    'ChNUaHJlYWRFcGhlbWVyYWxMaXN0Ej4KCmNhbmRpZGF0ZXMYASADKAsyHi5mbHV4LlRocmVhZE'
    'VwaGVtZXJhbENhbmRpZGF0ZVIKY2FuZGlkYXRlcw==');

@$core.Deprecated('Use openCommissioningWindowRequestDescriptor instead')
const OpenCommissioningWindowRequest$json = {
  '1': 'OpenCommissioningWindowRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'timeout_s', '3': 2, '4': 1, '5': 13, '10': 'timeoutS'},
    {'1': 'iterations', '3': 3, '4': 1, '5': 13, '10': 'iterations'},
    {'1': 'discriminator', '3': 4, '4': 1, '5': 13, '10': 'discriminator'},
  ],
};

/// Descriptor for `OpenCommissioningWindowRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openCommissioningWindowRequestDescriptor =
    $convert.base64Decode(
        'Ch5PcGVuQ29tbWlzc2lvbmluZ1dpbmRvd1JlcXVlc3QSFwoHbm9kZV9pZBgBIAEoBFIGbm9kZU'
        'lkEhsKCXRpbWVvdXRfcxgCIAEoDVIIdGltZW91dFMSHgoKaXRlcmF0aW9ucxgDIAEoDVIKaXRl'
        'cmF0aW9ucxIkCg1kaXNjcmltaW5hdG9yGAQgASgNUg1kaXNjcmltaW5hdG9y');

@$core.Deprecated('Use openCommissioningWindowResultDescriptor instead')
const OpenCommissioningWindowResult$json = {
  '1': 'OpenCommissioningWindowResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'manual_code', '3': 2, '4': 1, '5': 9, '10': 'manualCode'},
    {'1': 'discriminator', '3': 3, '4': 1, '5': 13, '10': 'discriminator'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `OpenCommissioningWindowResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openCommissioningWindowResultDescriptor =
    $convert.base64Decode(
        'Ch1PcGVuQ29tbWlzc2lvbmluZ1dpbmRvd1Jlc3VsdBIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZX'
        'NzEh8KC21hbnVhbF9jb2RlGAIgASgJUgptYW51YWxDb2RlEiQKDWRpc2NyaW1pbmF0b3IYAyAB'
        'KA1SDWRpc2NyaW1pbmF0b3ISFAoFZXJyb3IYBCABKAlSBWVycm9y');

@$core.Deprecated('Use fabricProvisionDescriptor instead')
const FabricProvision$json = {
  '1': 'FabricProvision',
  '2': [
    {'1': 'fabric_id', '3': 1, '4': 1, '5': 4, '10': 'fabricId'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'root_ca_tlv', '3': 3, '4': 1, '5': 12, '10': 'rootCaTlv'},
    {'1': 'icac_tlv', '3': 4, '4': 1, '5': 12, '10': 'icacTlv'},
    {'1': 'noc_tlv', '3': 5, '4': 1, '5': 12, '10': 'nocTlv'},
    {'1': 'op_priv_key', '3': 6, '4': 1, '5': 12, '10': 'opPrivKey'},
    {'1': 'ipk', '3': 7, '4': 1, '5': 12, '10': 'ipk'},
    {'1': 'vendor_id', '3': 8, '4': 1, '5': 13, '10': 'vendorId'},
    {'1': 'rcac_priv_key', '3': 9, '4': 1, '5': 12, '10': 'rcacPrivKey'},
  ],
};

/// Descriptor for `FabricProvision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fabricProvisionDescriptor = $convert.base64Decode(
    'Cg9GYWJyaWNQcm92aXNpb24SGwoJZmFicmljX2lkGAEgASgEUghmYWJyaWNJZBIXCgdub2RlX2'
    'lkGAIgASgEUgZub2RlSWQSHgoLcm9vdF9jYV90bHYYAyABKAxSCXJvb3RDYVRsdhIZCghpY2Fj'
    'X3RsdhgEIAEoDFIHaWNhY1RsdhIXCgdub2NfdGx2GAUgASgMUgZub2NUbHYSHgoLb3BfcHJpdl'
    '9rZXkYBiABKAxSCW9wUHJpdktleRIQCgNpcGsYByABKAxSA2lwaxIbCgl2ZW5kb3JfaWQYCCAB'
    'KA1SCHZlbmRvcklkEiIKDXJjYWNfcHJpdl9rZXkYCSABKAxSC3JjYWNQcml2S2V5');

@$core.Deprecated('Use fabricProvisionResultDescriptor instead')
const FabricProvisionResult$json = {
  '1': 'FabricProvisionResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'fabric_index', '3': 2, '4': 1, '5': 13, '10': 'fabricIndex'},
    {
      '1': 'compressed_fabric_id',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'compressedFabricId'
    },
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `FabricProvisionResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fabricProvisionResultDescriptor = $convert.base64Decode(
    'ChVGYWJyaWNQcm92aXNpb25SZXN1bHQSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIhCgxmYW'
    'JyaWNfaW5kZXgYAiABKA1SC2ZhYnJpY0luZGV4EjAKFGNvbXByZXNzZWRfZmFicmljX2lkGAMg'
    'ASgEUhJjb21wcmVzc2VkRmFicmljSWQSFAoFZXJyb3IYBCABKAlSBWVycm9y');

@$core.Deprecated('Use mfgProvisionDescriptor instead')
const MfgProvision$json = {
  '1': 'MfgProvision',
  '2': [
    {'1': 'rcac_priv_key', '3': 1, '4': 1, '5': 12, '10': 'rcacPrivKey'},
    {'1': 'serial_number', '3': 2, '4': 1, '5': 9, '10': 'serialNumber'},
    {'1': 'rcac_cert_der', '3': 3, '4': 1, '5': 12, '10': 'rcacCertDer'},
    {'1': 'psk', '3': 4, '4': 1, '5': 12, '10': 'psk'},
  ],
};

/// Descriptor for `MfgProvision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mfgProvisionDescriptor = $convert.base64Decode(
    'CgxNZmdQcm92aXNpb24SIgoNcmNhY19wcml2X2tleRgBIAEoDFILcmNhY1ByaXZLZXkSIwoNc2'
    'VyaWFsX251bWJlchgCIAEoCVIMc2VyaWFsTnVtYmVyEiIKDXJjYWNfY2VydF9kZXIYAyABKAxS'
    'C3JjYWNDZXJ0RGVyEhAKA3BzaxgEIAEoDFIDcHNr');

@$core.Deprecated('Use mfgProvisionResultDescriptor instead')
const MfgProvisionResult$json = {
  '1': 'MfgProvisionResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `MfgProvisionResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mfgProvisionResultDescriptor = $convert.base64Decode(
    'ChJNZmdQcm92aXNpb25SZXN1bHQSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIUCgVlcnJvch'
    'gCIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use commissionRequestDescriptor instead')
const CommissionRequest$json = {
  '1': 'CommissionRequest',
  '2': [
    {'1': 'passcode', '3': 1, '4': 1, '5': 13, '10': 'passcode'},
    {'1': 'discriminator', '3': 2, '4': 1, '5': 13, '10': 'discriminator'},
    {'1': 'node_id', '3': 3, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'vendor_id', '3': 5, '4': 1, '5': 13, '10': 'vendorId'},
    {'1': 'product_id', '3': 6, '4': 1, '5': 13, '10': 'productId'},
    {'1': 'device_type', '3': 7, '4': 1, '5': 13, '10': 'deviceType'},
    {
      '1': 'short_discriminator',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'shortDiscriminator'
    },
  ],
  '9': [
    {'1': 8, '2': 9},
    {'1': 9, '2': 10},
  ],
  '10': ['device_address', 'device_port'],
};

/// Descriptor for `CommissionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commissionRequestDescriptor = $convert.base64Decode(
    'ChFDb21taXNzaW9uUmVxdWVzdBIaCghwYXNzY29kZRgBIAEoDVIIcGFzc2NvZGUSJAoNZGlzY3'
    'JpbWluYXRvchgCIAEoDVINZGlzY3JpbWluYXRvchIXCgdub2RlX2lkGAMgASgEUgZub2RlSWQS'
    'EgoEbmFtZRgEIAEoCVIEbmFtZRIbCgl2ZW5kb3JfaWQYBSABKA1SCHZlbmRvcklkEh0KCnByb2'
    'R1Y3RfaWQYBiABKA1SCXByb2R1Y3RJZBIfCgtkZXZpY2VfdHlwZRgHIAEoDVIKZGV2aWNlVHlw'
    'ZRIvChNzaG9ydF9kaXNjcmltaW5hdG9yGAogASgIUhJzaG9ydERpc2NyaW1pbmF0b3JKBAgIEA'
    'lKBAgJEApSDmRldmljZV9hZGRyZXNzUgtkZXZpY2VfcG9ydA==');

@$core.Deprecated('Use commissionResultDescriptor instead')
const CommissionResult$json = {
  '1': 'CommissionResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'fabric_id', '3': 3, '4': 1, '5': 4, '10': 'fabricId'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `CommissionResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commissionResultDescriptor = $convert.base64Decode(
    'ChBDb21taXNzaW9uUmVzdWx0EhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSFwoHbm9kZV9pZB'
    'gCIAEoBFIGbm9kZUlkEhsKCWZhYnJpY19pZBgDIAEoBFIIZmFicmljSWQSFAoFZXJyb3IYBCAB'
    'KAlSBWVycm9y');

@$core.Deprecated('Use commissionEventDescriptor instead')
const CommissionEvent$json = {
  '1': 'CommissionEvent',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 13, '10': 'seq'},
    {'1': 'stage', '3': 2, '4': 1, '5': 9, '10': 'stage'},
    {'1': 'failed', '3': 3, '4': 1, '5': 8, '10': 'failed'},
    {'1': 'detail', '3': 4, '4': 1, '5': 9, '10': 'detail'},
  ],
};

/// Descriptor for `CommissionEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commissionEventDescriptor = $convert.base64Decode(
    'Cg9Db21taXNzaW9uRXZlbnQSEAoDc2VxGAEgASgNUgNzZXESFAoFc3RhZ2UYAiABKAlSBXN0YW'
    'dlEhYKBmZhaWxlZBgDIAEoCFIGZmFpbGVkEhYKBmRldGFpbBgEIAEoCVIGZGV0YWls');

@$core.Deprecated('Use deviceDescriptor instead')
const Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'reachable', '3': 3, '4': 1, '5': 8, '10': 'reachable'},
    {'1': 'vendor_id', '3': 4, '4': 1, '5': 13, '10': 'vendorId'},
    {'1': 'product_id', '3': 5, '4': 1, '5': 13, '10': 'productId'},
    {'1': 'device_type', '3': 6, '4': 1, '5': 13, '10': 'deviceType'},
    {
      '1': 'connectivity',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.flux.ConnectivityState',
      '10': 'connectivity'
    },
    {
      '1': 'kind',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
    {'1': 'room_id', '3': 9, '4': 1, '5': 13, '10': 'roomId'},
    {
      '1': 'energy_role',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.flux.EnergyRole',
      '10': 'energyRole'
    },
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USFwoHbm9kZV9pZBgBIAEoBFIGbm9kZUlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHA'
    'oJcmVhY2hhYmxlGAMgASgIUglyZWFjaGFibGUSGwoJdmVuZG9yX2lkGAQgASgNUgh2ZW5kb3JJ'
    'ZBIdCgpwcm9kdWN0X2lkGAUgASgNUglwcm9kdWN0SWQSHwoLZGV2aWNlX3R5cGUYBiABKA1SCm'
    'RldmljZVR5cGUSOwoMY29ubmVjdGl2aXR5GAcgASgOMhcuZmx1eC5Db25uZWN0aXZpdHlTdGF0'
    'ZVIMY29ubmVjdGl2aXR5EiQKBGtpbmQYCCABKA4yEC5mbHV4LkRldmljZUtpbmRSBGtpbmQSFw'
    'oHcm9vbV9pZBgJIAEoDVIGcm9vbUlkEjEKC2VuZXJneV9yb2xlGAogASgOMhAuZmx1eC5FbmVy'
    'Z3lSb2xlUgplbmVyZ3lSb2xl');

@$core.Deprecated('Use deviceListDescriptor instead')
const DeviceList$json = {
  '1': 'DeviceList',
  '2': [
    {
      '1': 'devices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.flux.Device',
      '10': 'devices'
    },
  ],
};

/// Descriptor for `DeviceList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceListDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VMaXN0EiYKB2RldmljZXMYASADKAsyDC5mbHV4LkRldmljZVIHZGV2aWNlcw==');

@$core.Deprecated('Use roomDescriptor instead')
const Room$json = {
  '1': 'Room',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 13, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `Room`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roomDescriptor = $convert
    .base64Decode('CgRSb29tEg4KAmlkGAEgASgNUgJpZBISCgRuYW1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use roomListDescriptor instead')
const RoomList$json = {
  '1': 'RoomList',
  '2': [
    {'1': 'rooms', '3': 1, '4': 3, '5': 11, '6': '.flux.Room', '10': 'rooms'},
  ],
};

/// Descriptor for `RoomList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roomListDescriptor = $convert.base64Decode(
    'CghSb29tTGlzdBIgCgVyb29tcxgBIAMoCzIKLmZsdXguUm9vbVIFcm9vbXM=');

@$core.Deprecated('Use deviceMetaDescriptor instead')
const DeviceMeta$json = {
  '1': 'DeviceMeta',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {
      '1': 'room_id',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'roomId',
      '17': true
    },
    {
      '1': 'energy_role',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.flux.EnergyRole',
      '9': 2,
      '10': 'energyRole',
      '17': true
    },
  ],
  '8': [
    {'1': '_name'},
    {'1': '_room_id'},
    {'1': '_energy_role'},
  ],
};

/// Descriptor for `DeviceMeta`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceMetaDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VNZXRhEhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIkCgRraW5kGAIgASgOMhAuZm'
    'x1eC5EZXZpY2VLaW5kUgRraW5kEhcKBG5hbWUYAyABKAlIAFIEbmFtZYgBARIcCgdyb29tX2lk'
    'GAQgASgNSAFSBnJvb21JZIgBARI2CgtlbmVyZ3lfcm9sZRgFIAEoDjIQLmZsdXguRW5lcmd5Um'
    '9sZUgCUgplbmVyZ3lSb2xliAEBQgcKBV9uYW1lQgoKCF9yb29tX2lkQg4KDF9lbmVyZ3lfcm9s'
    'ZQ==');

@$core.Deprecated('Use renameDeviceRequestDescriptor instead')
const RenameDeviceRequest$json = {
  '1': 'RenameDeviceRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'kind',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `RenameDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameDeviceRequestDescriptor = $convert.base64Decode(
    'ChNSZW5hbWVEZXZpY2VSZXF1ZXN0EhcKB25vZGVfaWQYASABKARSBm5vZGVJZBISCgRuYW1lGA'
    'IgASgJUgRuYW1lEiQKBGtpbmQYAyABKA4yEC5mbHV4LkRldmljZUtpbmRSBGtpbmQ=');

@$core.Deprecated('Use registerNodeRequestDescriptor instead')
const RegisterNodeRequest$json = {
  '1': 'RegisterNodeRequest',
  '2': [
    {'1': 'fabric_id', '3': 1, '4': 1, '5': 4, '10': 'fabricId'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'vendor_id', '3': 4, '4': 1, '5': 13, '10': 'vendorId'},
    {'1': 'product_id', '3': 5, '4': 1, '5': 13, '10': 'productId'},
    {'1': 'device_type', '3': 6, '4': 1, '5': 13, '10': 'deviceType'},
  ],
};

/// Descriptor for `RegisterNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerNodeRequestDescriptor = $convert.base64Decode(
    'ChNSZWdpc3Rlck5vZGVSZXF1ZXN0EhsKCWZhYnJpY19pZBgBIAEoBFIIZmFicmljSWQSFwoHbm'
    '9kZV9pZBgCIAEoBFIGbm9kZUlkEhIKBG5hbWUYAyABKAlSBG5hbWUSGwoJdmVuZG9yX2lkGAQg'
    'ASgNUgh2ZW5kb3JJZBIdCgpwcm9kdWN0X2lkGAUgASgNUglwcm9kdWN0SWQSHwoLZGV2aWNlX3'
    'R5cGUYBiABKA1SCmRldmljZVR5cGU=');

@$core.Deprecated('Use modbusDeviceConfigDescriptor instead')
const ModbusDeviceConfig$json = {
  '1': 'ModbusDeviceConfig',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'unit_id', '3': 3, '4': 1, '5': 13, '10': 'unitId'},
    {
      '1': 'profile',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.flux.ModbusProfile',
      '10': 'profile'
    },
    {'1': 'poll_seconds', '3': 5, '4': 1, '5': 13, '10': 'pollSeconds'},
    {'1': 'name', '3': 6, '4': 1, '5': 9, '10': 'name'},
    {'1': 'node_id', '3': 7, '4': 1, '5': 4, '10': 'nodeId'},
    {
      '1': 'transport',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.flux.ModbusTransport',
      '10': 'transport'
    },
  ],
};

/// Descriptor for `ModbusDeviceConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modbusDeviceConfigDescriptor = $convert.base64Decode(
    'ChJNb2RidXNEZXZpY2VDb25maWcSEgoEaG9zdBgBIAEoCVIEaG9zdBISCgRwb3J0GAIgASgNUg'
    'Rwb3J0EhcKB3VuaXRfaWQYAyABKA1SBnVuaXRJZBItCgdwcm9maWxlGAQgASgOMhMuZmx1eC5N'
    'b2RidXNQcm9maWxlUgdwcm9maWxlEiEKDHBvbGxfc2Vjb25kcxgFIAEoDVILcG9sbFNlY29uZH'
    'MSEgoEbmFtZRgGIAEoCVIEbmFtZRIXCgdub2RlX2lkGAcgASgEUgZub2RlSWQSMwoJdHJhbnNw'
    'b3J0GAggASgOMhUuZmx1eC5Nb2RidXNUcmFuc3BvcnRSCXRyYW5zcG9ydA==');

@$core.Deprecated('Use modbusCandidateDescriptor instead')
const ModbusCandidate$json = {
  '1': 'ModbusCandidate',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {
      '1': 'profile',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.flux.ModbusProfile',
      '10': 'profile'
    },
    {'1': 'serial', '3': 3, '4': 1, '5': 9, '10': 'serial'},
    {'1': 'model', '3': 4, '4': 1, '5': 9, '10': 'model'},
    {
      '1': 'transport',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.flux.ModbusTransport',
      '10': 'transport'
    },
  ],
};

/// Descriptor for `ModbusCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modbusCandidateDescriptor = $convert.base64Decode(
    'Cg9Nb2RidXNDYW5kaWRhdGUSEgoEaG9zdBgBIAEoCVIEaG9zdBItCgdwcm9maWxlGAIgASgOMh'
    'MuZmx1eC5Nb2RidXNQcm9maWxlUgdwcm9maWxlEhYKBnNlcmlhbBgDIAEoCVIGc2VyaWFsEhQK'
    'BW1vZGVsGAQgASgJUgVtb2RlbBIzCgl0cmFuc3BvcnQYBSABKA4yFS5mbHV4Lk1vZGJ1c1RyYW'
    '5zcG9ydFIJdHJhbnNwb3J0');

@$core.Deprecated('Use modbusDiscoveredDescriptor instead')
const ModbusDiscovered$json = {
  '1': 'ModbusDiscovered',
  '2': [
    {
      '1': 'candidates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.flux.ModbusCandidate',
      '10': 'candidates'
    },
  ],
};

/// Descriptor for `ModbusDiscovered`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modbusDiscoveredDescriptor = $convert.base64Decode(
    'ChBNb2RidXNEaXNjb3ZlcmVkEjUKCmNhbmRpZGF0ZXMYASADKAsyFS5mbHV4Lk1vZGJ1c0Nhbm'
    'RpZGF0ZVIKY2FuZGlkYXRlcw==');

@$core.Deprecated('Use modbusRawDumpDescriptor instead')
const ModbusRawDump$json = {
  '1': 'ModbusRawDump',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'unit_id', '3': 2, '4': 1, '5': 13, '10': 'unitId'},
    {
      '1': 'transport',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.flux.ModbusTransport',
      '10': 'transport'
    },
    {'1': 'base_addr', '3': 4, '4': 1, '5': 13, '10': 'baseAddr'},
    {'1': 'reg_count', '3': 5, '4': 1, '5': 13, '10': 'regCount'},
    {'1': 'registers', '3': 6, '4': 1, '5': 12, '10': 'registers'},
    {'1': 'truncated', '3': 7, '4': 1, '5': 8, '10': 'truncated'},
    {'1': 'error', '3': 8, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ModbusRawDump`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modbusRawDumpDescriptor = $convert.base64Decode(
    'Cg1Nb2RidXNSYXdEdW1wEhIKBGhvc3QYASABKAlSBGhvc3QSFwoHdW5pdF9pZBgCIAEoDVIGdW'
    '5pdElkEjMKCXRyYW5zcG9ydBgDIAEoDjIVLmZsdXguTW9kYnVzVHJhbnNwb3J0Ugl0cmFuc3Bv'
    'cnQSGwoJYmFzZV9hZGRyGAQgASgNUghiYXNlQWRkchIbCglyZWdfY291bnQYBSABKA1SCHJlZ0'
    'NvdW50EhwKCXJlZ2lzdGVycxgGIAEoDFIJcmVnaXN0ZXJzEhwKCXRydW5jYXRlZBgHIAEoCFIJ'
    'dHJ1bmNhdGVkEhQKBWVycm9yGAggASgJUgVlcnJvcg==');

@$core.Deprecated('Use attrDescriptor instead')
const Attr$json = {
  '1': 'Attr',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'bool_val', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'boolVal'},
    {'1': 'int_val', '3': 3, '4': 1, '5': 17, '9': 0, '10': 'intVal'},
    {'1': 'long_val', '3': 4, '4': 1, '5': 18, '9': 0, '10': 'longVal'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `Attr`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attrDescriptor = $convert.base64Decode(
    'CgRBdHRyEhAKA2tleRgBIAEoCVIDa2V5EhsKCGJvb2xfdmFsGAIgASgISABSB2Jvb2xWYWwSGQ'
    'oHaW50X3ZhbBgDIAEoEUgAUgZpbnRWYWwSGwoIbG9uZ192YWwYBCABKBJIAFIHbG9uZ1ZhbEIH'
    'CgV2YWx1ZQ==');

@$core.Deprecated('Use attrsUpdateDescriptor instead')
const AttrsUpdate$json = {
  '1': 'AttrsUpdate',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'attrs', '3': 2, '4': 3, '5': 11, '6': '.flux.Attr', '10': 'attrs'},
    {
      '1': 'kind',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `AttrsUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attrsUpdateDescriptor = $convert.base64Decode(
    'CgtBdHRyc1VwZGF0ZRIXCgdub2RlX2lkGAEgASgEUgZub2RlSWQSIAoFYXR0cnMYAiADKAsyCi'
    '5mbHV4LkF0dHJSBWF0dHJzEiQKBGtpbmQYAyABKA4yEC5mbHV4LkRldmljZUtpbmRSBGtpbmQ=');

@$core.Deprecated('Use deviceStateEventDescriptor instead')
const DeviceStateEvent$json = {
  '1': 'DeviceStateEvent',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceEventType',
      '10': 'type'
    },
    {
      '1': 'update',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.flux.AttrsUpdate',
      '10': 'update'
    },
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'kind',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `DeviceStateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceStateEventDescriptor = $convert.base64Decode(
    'ChBEZXZpY2VTdGF0ZUV2ZW50EhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIpCgR0eXBlGAIgAS'
    'gOMhUuZmx1eC5EZXZpY2VFdmVudFR5cGVSBHR5cGUSKQoGdXBkYXRlGAMgASgLMhEuZmx1eC5B'
    'dHRyc1VwZGF0ZVIGdXBkYXRlEhQKBWVycm9yGAQgASgJUgVlcnJvchIkCgRraW5kGAUgASgOMh'
    'AuZmx1eC5EZXZpY2VLaW5kUgRraW5k');

@$core.Deprecated('Use commandArgDescriptor instead')
const CommandArg$json = {
  '1': 'CommandArg',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'bool_val', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'boolVal'},
    {'1': 'uint_val', '3': 3, '4': 1, '5': 13, '9': 0, '10': 'uintVal'},
    {'1': 'int_val', '3': 4, '4': 1, '5': 17, '9': 0, '10': 'intVal'},
    {'1': 'str_val', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'strVal'},
    {'1': 'tag', '3': 6, '4': 1, '5': 13, '10': 'tag'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `CommandArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandArgDescriptor = $convert.base64Decode(
    'CgpDb21tYW5kQXJnEhIKBG5hbWUYASABKAlSBG5hbWUSGwoIYm9vbF92YWwYAiABKAhIAFIHYm'
    '9vbFZhbBIbCgh1aW50X3ZhbBgDIAEoDUgAUgd1aW50VmFsEhkKB2ludF92YWwYBCABKBFIAFIG'
    'aW50VmFsEhkKB3N0cl92YWwYBSABKAlIAFIGc3RyVmFsEhAKA3RhZxgGIAEoDVIDdGFnQgcKBX'
    'ZhbHVl');

@$core.Deprecated('Use deviceCommandDescriptor instead')
const DeviceCommand$json = {
  '1': 'DeviceCommand',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'endpoint_id', '3': 2, '4': 1, '5': 13, '10': 'endpointId'},
    {'1': 'cluster_id', '3': 3, '4': 1, '5': 13, '10': 'clusterId'},
    {'1': 'command_id', '3': 4, '4': 1, '5': 13, '10': 'commandId'},
    {
      '1': 'args',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.flux.CommandArg',
      '10': 'args'
    },
    {
      '1': 'kind',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `DeviceCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceCommandDescriptor = $convert.base64Decode(
    'Cg1EZXZpY2VDb21tYW5kEhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIfCgtlbmRwb2ludF9pZB'
    'gCIAEoDVIKZW5kcG9pbnRJZBIdCgpjbHVzdGVyX2lkGAMgASgNUgljbHVzdGVySWQSHQoKY29t'
    'bWFuZF9pZBgEIAEoDVIJY29tbWFuZElkEiQKBGFyZ3MYBSADKAsyEC5mbHV4LkNvbW1hbmRBcm'
    'dSBGFyZ3MSJAoEa2luZBgGIAEoDjIQLmZsdXguRGV2aWNlS2luZFIEa2luZA==');

@$core.Deprecated('Use writeAttrRequestDescriptor instead')
const WriteAttrRequest$json = {
  '1': 'WriteAttrRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'endpoint_id', '3': 2, '4': 1, '5': 13, '10': 'endpointId'},
    {'1': 'cluster_id', '3': 3, '4': 1, '5': 13, '10': 'clusterId'},
    {'1': 'attr_id', '3': 4, '4': 1, '5': 13, '10': 'attrId'},
    {'1': 'bool_val', '3': 5, '4': 1, '5': 8, '9': 0, '10': 'boolVal'},
    {'1': 'int_val', '3': 6, '4': 1, '5': 17, '9': 0, '10': 'intVal'},
    {'1': 'json_val', '3': 7, '4': 1, '5': 9, '10': 'jsonVal'},
    {
      '1': 'kind',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `WriteAttrRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeAttrRequestDescriptor = $convert.base64Decode(
    'ChBXcml0ZUF0dHJSZXF1ZXN0EhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIfCgtlbmRwb2ludF'
    '9pZBgCIAEoDVIKZW5kcG9pbnRJZBIdCgpjbHVzdGVyX2lkGAMgASgNUgljbHVzdGVySWQSFwoH'
    'YXR0cl9pZBgEIAEoDVIGYXR0cklkEhsKCGJvb2xfdmFsGAUgASgISABSB2Jvb2xWYWwSGQoHaW'
    '50X3ZhbBgGIAEoEUgAUgZpbnRWYWwSGQoIanNvbl92YWwYByABKAlSB2pzb25WYWwSJAoEa2lu'
    'ZBgIIAEoDjIQLmZsdXguRGV2aWNlS2luZFIEa2luZEIHCgV2YWx1ZQ==');

@$core.Deprecated('Use readRequestDescriptor instead')
const ReadRequest$json = {
  '1': 'ReadRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'endpoint_ids', '3': 2, '4': 3, '5': 13, '10': 'endpointIds'},
    {'1': 'cluster_ids', '3': 3, '4': 3, '5': 13, '10': 'clusterIds'},
    {'1': 'attr_ids', '3': 4, '4': 3, '5': 13, '10': 'attrIds'},
    {
      '1': 'kind',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `ReadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readRequestDescriptor = $convert.base64Decode(
    'CgtSZWFkUmVxdWVzdBIXCgdub2RlX2lkGAEgASgEUgZub2RlSWQSIQoMZW5kcG9pbnRfaWRzGA'
    'IgAygNUgtlbmRwb2ludElkcxIfCgtjbHVzdGVyX2lkcxgDIAMoDVIKY2x1c3RlcklkcxIZCghh'
    'dHRyX2lkcxgEIAMoDVIHYXR0cklkcxIkCgRraW5kGAUgASgOMhAuZmx1eC5EZXZpY2VLaW5kUg'
    'RraW5k');

@$core.Deprecated('Use boolResultDescriptor instead')
const BoolResult$json = {
  '1': 'BoolResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `BoolResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List boolResultDescriptor = $convert.base64Decode(
    'CgpCb29sUmVzdWx0EhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSFAoFZXJyb3IYAiABKAlSBW'
    'Vycm9y');

@$core.Deprecated('Use statusResponseDescriptor instead')
const StatusResponse$json = {
  '1': 'StatusResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 13, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `StatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusResponseDescriptor = $convert.base64Decode(
    'Cg5TdGF0dXNSZXNwb25zZRISCgRjb2RlGAEgASgNUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB2'
    '1lc3NhZ2U=');

@$core.Deprecated('Use energyBucketDescriptor instead')
const EnergyBucket$json = {
  '1': 'EnergyBucket',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 13, '10': 'index'},
    {'1': 'grid_import_wh', '3': 2, '4': 1, '5': 13, '10': 'gridImportWh'},
    {'1': 'grid_export_wh', '3': 3, '4': 1, '5': 13, '10': 'gridExportWh'},
    {'1': 'pv_wh', '3': 4, '4': 1, '5': 13, '10': 'pvWh'},
    {'1': 'load_wh', '3': 5, '4': 1, '5': 13, '10': 'loadWh'},
    {
      '1': 'battery_charge_wh',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'batteryChargeWh'
    },
    {
      '1': 'battery_discharge_wh',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'batteryDischargeWh'
    },
  ],
};

/// Descriptor for `EnergyBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyBucketDescriptor = $convert.base64Decode(
    'CgxFbmVyZ3lCdWNrZXQSFAoFaW5kZXgYASABKA1SBWluZGV4EiQKDmdyaWRfaW1wb3J0X3doGA'
    'IgASgNUgxncmlkSW1wb3J0V2gSJAoOZ3JpZF9leHBvcnRfd2gYAyABKA1SDGdyaWRFeHBvcnRX'
    'aBITCgVwdl93aBgEIAEoDVIEcHZXaBIXCgdsb2FkX3doGAUgASgNUgZsb2FkV2gSKgoRYmF0dG'
    'VyeV9jaGFyZ2Vfd2gYBiABKA1SD2JhdHRlcnlDaGFyZ2VXaBIwChRiYXR0ZXJ5X2Rpc2NoYXJn'
    'ZV93aBgHIAEoDVISYmF0dGVyeURpc2NoYXJnZVdo');

@$core.Deprecated('Use energyDeviceSeriesDescriptor instead')
const EnergyDeviceSeries$json = {
  '1': 'EnergyDeviceSeries',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {
      '1': 'cls',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.flux.EnergyClass',
      '10': 'cls'
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'wh', '3': 4, '4': 3, '5': 13, '10': 'wh'},
    {
      '1': 'kind',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `EnergyDeviceSeries`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyDeviceSeriesDescriptor = $convert.base64Decode(
    'ChJFbmVyZ3lEZXZpY2VTZXJpZXMSFwoHbm9kZV9pZBgBIAEoBFIGbm9kZUlkEiMKA2NscxgCIA'
    'EoDjIRLmZsdXguRW5lcmd5Q2xhc3NSA2NscxISCgRuYW1lGAMgASgJUgRuYW1lEg4KAndoGAQg'
    'AygNUgJ3aBIkCgRraW5kGAUgASgOMhAuZmx1eC5EZXZpY2VLaW5kUgRraW5k');

@$core.Deprecated('Use batterySocSeriesDescriptor instead')
const BatterySocSeries$json = {
  '1': 'BatterySocSeries',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'soc_pct', '3': 3, '4': 1, '5': 12, '10': 'socPct'},
    {
      '1': 'kind',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.flux.DeviceKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `BatterySocSeries`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batterySocSeriesDescriptor = $convert.base64Decode(
    'ChBCYXR0ZXJ5U29jU2VyaWVzEhcKB25vZGVfaWQYASABKARSBm5vZGVJZBISCgRuYW1lGAIgAS'
    'gJUgRuYW1lEhcKB3NvY19wY3QYAyABKAxSBnNvY1BjdBIkCgRraW5kGAQgASgOMhAuZmx1eC5E'
    'ZXZpY2VLaW5kUgRraW5k');

@$core.Deprecated('Use energyHistoryDescriptor instead')
const EnergyHistory$json = {
  '1': 'EnergyHistory',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 3, '10': 'start'},
    {'1': 'bucket_seconds', '3': 2, '4': 1, '5': 13, '10': 'bucketSeconds'},
    {'1': 'from', '3': 3, '4': 1, '5': 3, '10': 'from'},
    {'1': 'to', '3': 4, '4': 1, '5': 3, '10': 'to'},
    {'1': 'time_synced', '3': 5, '4': 1, '5': 8, '10': 'timeSynced'},
    {'1': 'truncated', '3': 6, '4': 1, '5': 8, '10': 'truncated'},
    {
      '1': 'buckets',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.flux.EnergyBucket',
      '10': 'buckets'
    },
    {
      '1': 'device_series',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.flux.EnergyDeviceSeries',
      '10': 'deviceSeries'
    },
    {
      '1': 'battery_soc',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.flux.BatterySocSeries',
      '10': 'batterySoc'
    },
  ],
};

/// Descriptor for `EnergyHistory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyHistoryDescriptor = $convert.base64Decode(
    'Cg1FbmVyZ3lIaXN0b3J5EhQKBXN0YXJ0GAEgASgDUgVzdGFydBIlCg5idWNrZXRfc2Vjb25kcx'
    'gCIAEoDVINYnVja2V0U2Vjb25kcxISCgRmcm9tGAMgASgDUgRmcm9tEg4KAnRvGAQgASgDUgJ0'
    'bxIfCgt0aW1lX3N5bmNlZBgFIAEoCFIKdGltZVN5bmNlZBIcCgl0cnVuY2F0ZWQYBiABKAhSCX'
    'RydW5jYXRlZBIsCgdidWNrZXRzGAcgAygLMhIuZmx1eC5FbmVyZ3lCdWNrZXRSB2J1Y2tldHMS'
    'PQoNZGV2aWNlX3NlcmllcxgIIAMoCzIYLmZsdXguRW5lcmd5RGV2aWNlU2VyaWVzUgxkZXZpY2'
    'VTZXJpZXMSNwoLYmF0dGVyeV9zb2MYCSADKAsyFi5mbHV4LkJhdHRlcnlTb2NTZXJpZXNSCmJh'
    'dHRlcnlTb2M=');

@$core.Deprecated('Use priceCurveDescriptor instead')
const PriceCurve$json = {
  '1': 'PriceCurve',
  '2': [
    {'1': 'start_epoch', '3': 1, '4': 1, '5': 3, '10': 'startEpoch'},
    {
      '1': 'resolution_seconds',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'resolutionSeconds'
    },
    {'1': 'currency', '3': 3, '4': 1, '5': 9, '10': 'currency'},
    {
      '1': 'unit',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.flux.PriceUnit',
      '10': 'unit'
    },
    {'1': 'prices', '3': 5, '4': 3, '5': 17, '10': 'prices'},
    {'1': 'fetched_at', '3': 6, '4': 1, '5': 3, '10': 'fetchedAt'},
    {'1': 'stale', '3': 7, '4': 1, '5': 8, '10': 'stale'},
  ],
};

/// Descriptor for `PriceCurve`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List priceCurveDescriptor = $convert.base64Decode(
    'CgpQcmljZUN1cnZlEh8KC3N0YXJ0X2Vwb2NoGAEgASgDUgpzdGFydEVwb2NoEi0KEnJlc29sdX'
    'Rpb25fc2Vjb25kcxgCIAEoDVIRcmVzb2x1dGlvblNlY29uZHMSGgoIY3VycmVuY3kYAyABKAlS'
    'CGN1cnJlbmN5EiMKBHVuaXQYBCABKA4yDy5mbHV4LlByaWNlVW5pdFIEdW5pdBIWCgZwcmljZX'
    'MYBSADKBFSBnByaWNlcxIdCgpmZXRjaGVkX2F0GAYgASgDUglmZXRjaGVkQXQSFAoFc3RhbGUY'
    'ByABKAhSBXN0YWxl');

@$core.Deprecated('Use pricingConfigDescriptor instead')
const PricingConfig$json = {
  '1': 'PricingConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'provider', '3': 2, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'zone', '3': 3, '4': 1, '5': 9, '10': 'zone'},
    {'1': 'api_token', '3': 4, '4': 1, '5': 9, '10': 'apiToken'},
    {'1': 'base_url', '3': 5, '4': 1, '5': 9, '10': 'baseUrl'},
    {'1': 'fetch_hour_local', '3': 6, '4': 1, '5': 13, '10': 'fetchHourLocal'},
    {
      '1': 'markup_ueur_per_kwh',
      '3': 7,
      '4': 1,
      '5': 17,
      '10': 'markupUeurPerKwh'
    },
    {'1': 'vat_percent', '3': 8, '4': 1, '5': 13, '10': 'vatPercent'},
    {
      '1': 'feed_in_ueur_per_kwh',
      '3': 9,
      '4': 1,
      '5': 17,
      '10': 'feedInUeurPerKwh'
    },
  ],
};

/// Descriptor for `PricingConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pricingConfigDescriptor = $convert.base64Decode(
    'Cg1QcmljaW5nQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSGgoIcHJvdmlkZXIYAi'
    'ABKAlSCHByb3ZpZGVyEhIKBHpvbmUYAyABKAlSBHpvbmUSGwoJYXBpX3Rva2VuGAQgASgJUghh'
    'cGlUb2tlbhIZCghiYXNlX3VybBgFIAEoCVIHYmFzZVVybBIoChBmZXRjaF9ob3VyX2xvY2FsGA'
    'YgASgNUg5mZXRjaEhvdXJMb2NhbBItChNtYXJrdXBfdWV1cl9wZXJfa3doGAcgASgRUhBtYXJr'
    'dXBVZXVyUGVyS3doEh8KC3ZhdF9wZXJjZW50GAggASgNUgp2YXRQZXJjZW50Ei4KFGZlZWRfaW'
    '5fdWV1cl9wZXJfa3doGAkgASgRUhBmZWVkSW5VZXVyUGVyS3do');

@$core.Deprecated('Use solarPlaneDescriptor instead')
const SolarPlane$json = {
  '1': 'SolarPlane',
  '2': [
    {'1': 'tilt_deg', '3': 1, '4': 1, '5': 13, '10': 'tiltDeg'},
    {'1': 'azimuth_deg', '3': 2, '4': 1, '5': 13, '10': 'azimuthDeg'},
    {'1': 'kwp_w', '3': 3, '4': 1, '5': 13, '10': 'kwpW'},
  ],
};

/// Descriptor for `SolarPlane`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List solarPlaneDescriptor = $convert.base64Decode(
    'CgpTb2xhclBsYW5lEhkKCHRpbHRfZGVnGAEgASgNUgd0aWx0RGVnEh8KC2F6aW11dGhfZGVnGA'
    'IgASgNUgphemltdXRoRGVnEhMKBWt3cF93GAMgASgNUgRrd3BX');

@$core.Deprecated('Use solarConfigDescriptor instead')
const SolarConfig$json = {
  '1': 'SolarConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'provider', '3': 2, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'latitude_udeg', '3': 3, '4': 1, '5': 17, '10': 'latitudeUdeg'},
    {'1': 'longitude_udeg', '3': 4, '4': 1, '5': 17, '10': 'longitudeUdeg'},
    {
      '1': 'planes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.flux.SolarPlane',
      '10': 'planes'
    },
    {'1': 'inverter_ac_w', '3': 6, '4': 1, '5': 13, '10': 'inverterAcW'},
    {'1': 'system_loss_pct', '3': 7, '4': 1, '5': 13, '10': 'systemLossPct'},
    {'1': 'albedo_pct', '3': 8, '4': 1, '5': 13, '10': 'albedoPct'},
    {
      '1': 'temp_coeff_ppm_per_k',
      '3': 9,
      '4': 1,
      '5': 17,
      '10': 'tempCoeffPpmPerK'
    },
  ],
};

/// Descriptor for `SolarConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List solarConfigDescriptor = $convert.base64Decode(
    'CgtTb2xhckNvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEhoKCHByb3ZpZGVyGAIgAS'
    'gJUghwcm92aWRlchIjCg1sYXRpdHVkZV91ZGVnGAMgASgRUgxsYXRpdHVkZVVkZWcSJQoObG9u'
    'Z2l0dWRlX3VkZWcYBCABKBFSDWxvbmdpdHVkZVVkZWcSKAoGcGxhbmVzGAUgAygLMhAuZmx1eC'
    '5Tb2xhclBsYW5lUgZwbGFuZXMSIgoNaW52ZXJ0ZXJfYWNfdxgGIAEoDVILaW52ZXJ0ZXJBY1cS'
    'JgoPc3lzdGVtX2xvc3NfcGN0GAcgASgNUg1zeXN0ZW1Mb3NzUGN0Eh0KCmFsYmVkb19wY3QYCC'
    'ABKA1SCWFsYmVkb1BjdBIuChR0ZW1wX2NvZWZmX3BwbV9wZXJfaxgJIAEoEVIQdGVtcENvZWZm'
    'UHBtUGVySw==');

@$core.Deprecated('Use solarForecastDescriptor instead')
const SolarForecast$json = {
  '1': 'SolarForecast',
  '2': [
    {'1': 'start_epoch', '3': 1, '4': 1, '5': 3, '10': 'startEpoch'},
    {
      '1': 'resolution_seconds',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'resolutionSeconds'
    },
    {'1': 'watt_hours', '3': 3, '4': 3, '5': 13, '10': 'wattHours'},
    {'1': 'fetched_at', '3': 4, '4': 1, '5': 3, '10': 'fetchedAt'},
    {'1': 'stale', '3': 5, '4': 1, '5': 8, '10': 'stale'},
    {'1': 'today_wh', '3': 6, '4': 1, '5': 13, '10': 'todayWh'},
    {'1': 'tomorrow_wh', '3': 7, '4': 1, '5': 13, '10': 'tomorrowWh'},
  ],
};

/// Descriptor for `SolarForecast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List solarForecastDescriptor = $convert.base64Decode(
    'Cg1Tb2xhckZvcmVjYXN0Eh8KC3N0YXJ0X2Vwb2NoGAEgASgDUgpzdGFydEVwb2NoEi0KEnJlc2'
    '9sdXRpb25fc2Vjb25kcxgCIAEoDVIRcmVzb2x1dGlvblNlY29uZHMSHQoKd2F0dF9ob3VycxgD'
    'IAMoDVIJd2F0dEhvdXJzEh0KCmZldGNoZWRfYXQYBCABKANSCWZldGNoZWRBdBIUCgVzdGFsZR'
    'gFIAEoCFIFc3RhbGUSGQoIdG9kYXlfd2gYBiABKA1SB3RvZGF5V2gSHwoLdG9tb3Jyb3dfd2gY'
    'ByABKA1SCnRvbW9ycm93V2g=');

@$core.Deprecated('Use stunServerDescriptor instead')
const StunServer$json = {
  '1': 'StunServer',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
  ],
};

/// Descriptor for `StunServer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stunServerDescriptor = $convert.base64Decode(
    'CgpTdHVuU2VydmVyEhIKBGhvc3QYASABKAlSBGhvc3QSEgoEcG9ydBgCIAEoDVIEcG9ydA==');

@$core.Deprecated('Use turnServerDescriptor instead')
const TurnServer$json = {
  '1': 'TurnServer',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
    {'1': 'credential', '3': 4, '4': 1, '5': 9, '10': 'credential'},
  ],
};

/// Descriptor for `TurnServer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List turnServerDescriptor = $convert.base64Decode(
    'CgpUdXJuU2VydmVyEhIKBGhvc3QYASABKAlSBGhvc3QSEgoEcG9ydBgCIAEoDVIEcG9ydBIaCg'
    'h1c2VybmFtZRgDIAEoCVIIdXNlcm5hbWUSHgoKY3JlZGVudGlhbBgEIAEoCVIKY3JlZGVudGlh'
    'bA==');

@$core.Deprecated('Use remoteConfigDescriptor instead')
const RemoteConfig$json = {
  '1': 'RemoteConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'stun',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.flux.StunServer',
      '10': 'stun'
    },
    {
      '1': 'turn',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.flux.TurnServer',
      '10': 'turn'
    },
    {'1': 'rendezvous_url', '3': 4, '4': 1, '5': 9, '10': 'rendezvousUrl'},
    {
      '1': 'rendezvous_cert_pin',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'rendezvousCertPin'
    },
    {'1': 'cfg_gen', '3': 6, '4': 1, '5': 13, '10': 'cfgGen'},
    {'1': 'proto_min', '3': 7, '4': 1, '5': 13, '10': 'protoMin'},
    {'1': 'proto_max', '3': 8, '4': 1, '5': 13, '10': 'protoMax'},
  ],
};

/// Descriptor for `RemoteConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteConfigDescriptor = $convert.base64Decode(
    'CgxSZW1vdGVDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBIkCgRzdHVuGAIgAygLMh'
    'AuZmx1eC5TdHVuU2VydmVyUgRzdHVuEiQKBHR1cm4YAyADKAsyEC5mbHV4LlR1cm5TZXJ2ZXJS'
    'BHR1cm4SJQoOcmVuZGV6dm91c191cmwYBCABKAlSDXJlbmRlenZvdXNVcmwSLgoTcmVuZGV6dm'
    '91c19jZXJ0X3BpbhgFIAEoCVIRcmVuZGV6dm91c0NlcnRQaW4SFwoHY2ZnX2dlbhgGIAEoDVIG'
    'Y2ZnR2VuEhsKCXByb3RvX21pbhgHIAEoDVIIcHJvdG9NaW4SGwoJcHJvdG9fbWF4GAggASgNUg'
    'hwcm90b01heA==');

@$core.Deprecated('Use iceSignalDescriptor instead')
const IceSignal$json = {
  '1': 'IceSignal',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.flux.IceSignalKind',
      '10': 'kind'
    },
    {'1': 'sdp', '3': 2, '4': 1, '5': 9, '10': 'sdp'},
    {'1': 'mac', '3': 3, '4': 1, '5': 12, '10': 'mac'},
    {'1': 'proto_version', '3': 4, '4': 1, '5': 13, '10': 'protoVersion'},
  ],
};

/// Descriptor for `IceSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iceSignalDescriptor = $convert.base64Decode(
    'CglJY2VTaWduYWwSJwoEa2luZBgBIAEoDjITLmZsdXguSWNlU2lnbmFsS2luZFIEa2luZBIQCg'
    'NzZHAYAiABKAlSA3NkcBIQCgNtYWMYAyABKAxSA21hYxIjCg1wcm90b192ZXJzaW9uGAQgASgN'
    'Ugxwcm90b1ZlcnNpb24=');
