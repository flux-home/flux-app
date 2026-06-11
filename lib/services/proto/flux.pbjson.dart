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

@$core.Deprecated('Use deviceEventTypeDescriptor instead')
const DeviceEventType$json = {
  '1': 'DeviceEventType',
  '2': [
    {'1': 'DEVICE_EVENT_ESTABLISHED', '2': 0},
    {'1': 'DEVICE_EVENT_ATTRS_UPDATE', '2': 1},
    {'1': 'DEVICE_EVENT_ERROR', '2': 2},
    {'1': 'DEVICE_EVENT_RESUBSCRIBING', '2': 3},
  ],
};

/// Descriptor for `DeviceEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceEventTypeDescriptor = $convert.base64Decode(
    'Cg9EZXZpY2VFdmVudFR5cGUSHAoYREVWSUNFX0VWRU5UX0VTVEFCTElTSEVEEAASHQoZREVWSU'
    'NFX0VWRU5UX0FUVFJTX1VQREFURRABEhYKEkRFVklDRV9FVkVOVF9FUlJPUhACEh4KGkRFVklD'
    'RV9FVkVOVF9SRVNVQlNDUklCSU5HEAM=');

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
  ],
};

/// Descriptor for `ControllerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerInfoDescriptor = $convert.base64Decode(
    'Cg5Db250cm9sbGVySW5mbxIpChBmaXJtd2FyZV92ZXJzaW9uGAEgASgJUg9maXJtd2FyZVZlcn'
    'Npb24SGgoIaG9zdG5hbWUYAiABKAlSCGhvc3RuYW1lEh8KC2V0aGVybmV0X2lwGAMgASgJUgpl'
    'dGhlcm5ldElwEh8KC2V0aGVybmV0X3VwGAQgASgIUgpldGhlcm5ldFVwEhsKCWZhYnJpY19pZB'
    'gFIAEoBFIIZmFicmljSWQSJQoOdXB0aW1lX3NlY29uZHMYBiABKA1SDXVwdGltZVNlY29uZHM=');

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
  ],
};

/// Descriptor for `FabricProvision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fabricProvisionDescriptor = $convert.base64Decode(
    'Cg9GYWJyaWNQcm92aXNpb24SGwoJZmFicmljX2lkGAEgASgEUghmYWJyaWNJZBIXCgdub2RlX2'
    'lkGAIgASgEUgZub2RlSWQSHgoLcm9vdF9jYV90bHYYAyABKAxSCXJvb3RDYVRsdhIZCghpY2Fj'
    'X3RsdhgEIAEoDFIHaWNhY1RsdhIXCgdub2NfdGx2GAUgASgMUgZub2NUbHYSHgoLb3BfcHJpdl'
    '9rZXkYBiABKAxSCW9wUHJpdktleRIQCgNpcGsYByABKAxSA2lwaxIbCgl2ZW5kb3JfaWQYCCAB'
    'KA1SCHZlbmRvcklk');

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
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USFwoHbm9kZV9pZBgBIAEoBFIGbm9kZUlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHA'
    'oJcmVhY2hhYmxlGAMgASgIUglyZWFjaGFibGUSGwoJdmVuZG9yX2lkGAQgASgNUgh2ZW5kb3JJ'
    'ZBIdCgpwcm9kdWN0X2lkGAUgASgNUglwcm9kdWN0SWQSHwoLZGV2aWNlX3R5cGUYBiABKA1SCm'
    'RldmljZVR5cGU=');

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
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `CommandArg`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandArgDescriptor = $convert.base64Decode(
    'CgpDb21tYW5kQXJnEhIKBG5hbWUYASABKAlSBG5hbWUSGwoIYm9vbF92YWwYAiABKAhIAFIHYm'
    '9vbFZhbBIbCgh1aW50X3ZhbBgDIAEoDUgAUgd1aW50VmFsEhkKB2ludF92YWwYBCABKBFIAFIG'
    'aW50VmFsEhkKB3N0cl92YWwYBSABKAlIAFIGc3RyVmFsQgcKBXZhbHVl');

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
