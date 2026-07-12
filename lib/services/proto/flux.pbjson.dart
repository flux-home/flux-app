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

@$core.Deprecated('Use modbusProfileDescriptor instead')
const ModbusProfile$json = {
  '1': 'ModbusProfile',
  '2': [
    {'1': 'MODBUS_PROFILE_SUNSPEC', '2': 0},
    {'1': 'MODBUS_PROFILE_UNKNOWN', '2': 1},
    {'1': 'MODBUS_PROFILE_VM3P75CT', '2': 2},
  ],
};

/// Descriptor for `ModbusProfile`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List modbusProfileDescriptor = $convert.base64Decode(
    'Cg1Nb2RidXNQcm9maWxlEhoKFk1PREJVU19QUk9GSUxFX1NVTlNQRUMQABIaChZNT0RCVVNfUF'
    'JPRklMRV9VTktOT1dOEAESGwoXTU9EQlVTX1BST0ZJTEVfVk0zUDc1Q1QQAg==');

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
    {'1': 'device_address', '3': 8, '4': 1, '5': 9, '10': 'deviceAddress'},
    {'1': 'device_port', '3': 9, '4': 1, '5': 13, '10': 'devicePort'},
  ],
};

/// Descriptor for `CommissionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commissionRequestDescriptor = $convert.base64Decode(
    'ChFDb21taXNzaW9uUmVxdWVzdBIaCghwYXNzY29kZRgBIAEoDVIIcGFzc2NvZGUSJAoNZGlzY3'
    'JpbWluYXRvchgCIAEoDVINZGlzY3JpbWluYXRvchIXCgdub2RlX2lkGAMgASgEUgZub2RlSWQS'
    'EgoEbmFtZRgEIAEoCVIEbmFtZRIbCgl2ZW5kb3JfaWQYBSABKA1SCHZlbmRvcklkEh0KCnByb2'
    'R1Y3RfaWQYBiABKA1SCXByb2R1Y3RJZBIfCgtkZXZpY2VfdHlwZRgHIAEoDVIKZGV2aWNlVHlw'
    'ZRIlCg5kZXZpY2VfYWRkcmVzcxgIIAEoCVINZGV2aWNlQWRkcmVzcxIfCgtkZXZpY2VfcG9ydB'
    'gJIAEoDVIKZGV2aWNlUG9ydA==');

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
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USFwoHbm9kZV9pZBgBIAEoBFIGbm9kZUlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHA'
    'oJcmVhY2hhYmxlGAMgASgIUglyZWFjaGFibGUSGwoJdmVuZG9yX2lkGAQgASgNUgh2ZW5kb3JJ'
    'ZBIdCgpwcm9kdWN0X2lkGAUgASgNUglwcm9kdWN0SWQSHwoLZGV2aWNlX3R5cGUYBiABKA1SCm'
    'RldmljZVR5cGUSOwoMY29ubmVjdGl2aXR5GAcgASgOMhcuZmx1eC5Db25uZWN0aXZpdHlTdGF0'
    'ZVIMY29ubmVjdGl2aXR5');

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

@$core.Deprecated('Use renameDeviceRequestDescriptor instead')
const RenameDeviceRequest$json = {
  '1': 'RenameDeviceRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `RenameDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameDeviceRequestDescriptor = $convert.base64Decode(
    'ChNSZW5hbWVEZXZpY2VSZXF1ZXN0EhcKB25vZGVfaWQYASABKARSBm5vZGVJZBISCgRuYW1lGA'
    'IgASgJUgRuYW1l');

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
  ],
};

/// Descriptor for `AttrsUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attrsUpdateDescriptor = $convert.base64Decode(
    'CgtBdHRyc1VwZGF0ZRIXCgdub2RlX2lkGAEgASgEUgZub2RlSWQSIAoFYXR0cnMYAiADKAsyCi'
    '5mbHV4LkF0dHJSBWF0dHJz');

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
  ],
};

/// Descriptor for `DeviceStateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceStateEventDescriptor = $convert.base64Decode(
    'ChBEZXZpY2VTdGF0ZUV2ZW50EhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIpCgR0eXBlGAIgAS'
    'gOMhUuZmx1eC5EZXZpY2VFdmVudFR5cGVSBHR5cGUSKQoGdXBkYXRlGAMgASgLMhEuZmx1eC5B'
    'dHRyc1VwZGF0ZVIGdXBkYXRlEhQKBWVycm9yGAQgASgJUgVlcnJvcg==');

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
  ],
};

/// Descriptor for `DeviceCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceCommandDescriptor = $convert.base64Decode(
    'Cg1EZXZpY2VDb21tYW5kEhcKB25vZGVfaWQYASABKARSBm5vZGVJZBIfCgtlbmRwb2ludF9pZB'
    'gCIAEoDVIKZW5kcG9pbnRJZBIdCgpjbHVzdGVyX2lkGAMgASgNUgljbHVzdGVySWQSHQoKY29t'
    'bWFuZF9pZBgEIAEoDVIJY29tbWFuZElkEiQKBGFyZ3MYBSADKAsyEC5mbHV4LkNvbW1hbmRBcm'
    'dSBGFyZ3M=');

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
    '50X3ZhbBgGIAEoEUgAUgZpbnRWYWwSGQoIanNvbl92YWwYByABKAlSB2pzb25WYWxCBwoFdmFs'
    'dWU=');

@$core.Deprecated('Use readRequestDescriptor instead')
const ReadRequest$json = {
  '1': 'ReadRequest',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 4, '10': 'nodeId'},
    {'1': 'endpoint_ids', '3': 2, '4': 3, '5': 13, '10': 'endpointIds'},
    {'1': 'cluster_ids', '3': 3, '4': 3, '5': 13, '10': 'clusterIds'},
    {'1': 'attr_ids', '3': 4, '4': 3, '5': 13, '10': 'attrIds'},
  ],
};

/// Descriptor for `ReadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readRequestDescriptor = $convert.base64Decode(
    'CgtSZWFkUmVxdWVzdBIXCgdub2RlX2lkGAEgASgEUgZub2RlSWQSIQoMZW5kcG9pbnRfaWRzGA'
    'IgAygNUgtlbmRwb2ludElkcxIfCgtjbHVzdGVyX2lkcxgDIAMoDVIKY2x1c3RlcklkcxIZCghh'
    'dHRyX2lkcxgEIAMoDVIHYXR0cklkcw==');

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
  ],
};

/// Descriptor for `EnergyBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyBucketDescriptor = $convert.base64Decode(
    'CgxFbmVyZ3lCdWNrZXQSFAoFaW5kZXgYASABKA1SBWluZGV4EiQKDmdyaWRfaW1wb3J0X3doGA'
    'IgASgNUgxncmlkSW1wb3J0V2gSJAoOZ3JpZF9leHBvcnRfd2gYAyABKA1SDGdyaWRFeHBvcnRX'
    'aBITCgVwdl93aBgEIAEoDVIEcHZXaBIXCgdsb2FkX3doGAUgASgNUgZsb2FkV2g=');

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
  ],
};

/// Descriptor for `EnergyDeviceSeries`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyDeviceSeriesDescriptor = $convert.base64Decode(
    'ChJFbmVyZ3lEZXZpY2VTZXJpZXMSFwoHbm9kZV9pZBgBIAEoBFIGbm9kZUlkEiMKA2NscxgCIA'
    'EoDjIRLmZsdXguRW5lcmd5Q2xhc3NSA2NscxISCgRuYW1lGAMgASgJUgRuYW1lEg4KAndoGAQg'
    'AygNUgJ3aA==');

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
  ],
};

/// Descriptor for `EnergyHistory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List energyHistoryDescriptor = $convert.base64Decode(
    'Cg1FbmVyZ3lIaXN0b3J5EhQKBXN0YXJ0GAEgASgDUgVzdGFydBIlCg5idWNrZXRfc2Vjb25kcx'
    'gCIAEoDVINYnVja2V0U2Vjb25kcxISCgRmcm9tGAMgASgDUgRmcm9tEg4KAnRvGAQgASgDUgJ0'
    'bxIfCgt0aW1lX3N5bmNlZBgFIAEoCFIKdGltZVN5bmNlZBIcCgl0cnVuY2F0ZWQYBiABKAhSCX'
    'RydW5jYXRlZBIsCgdidWNrZXRzGAcgAygLMhIuZmx1eC5FbmVyZ3lCdWNrZXRSB2J1Y2tldHMS'
    'PQoNZGV2aWNlX3NlcmllcxgIIAMoCzIYLmZsdXguRW5lcmd5RGV2aWNlU2VyaWVzUgxkZXZpY2'
    'VTZXJpZXM=');
