import 'package:uuid/uuid.dart';

// ── SwitchLink ───────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SwitchLink — one virtual-switch group on a controller device mapped to
// one or more target devices.
//
// Action mapping is fixed for now:
//   press endpoints → Toggle OnOff on all targets
//   CW endpoints    → Level up  (future)
//   CCW endpoints   → Level down (future)
//
// The endpoint lists are populated at link-creation time from the cluster
// cache so execution does not require the cluster inspector to be open.
//
// Future: when a device gains the Binding cluster, write each link as a
// TargetStruct {nodeId, endpoint, clusterId} instead of executing in-app.
// ─────────────────────────────────────────────────────────────────────────────

class SwitchLink {
  SwitchLink({
    String? id,
    required this.sourceDeviceId,
    required this.switchGroup,
    required this.pressEndpoints,
    required this.cwEndpoints,
    required this.ccwEndpoints,
    required this.targetDeviceIds,
  }) : id = id ?? const Uuid().v4();

  final String       id;
  final String       sourceDeviceId;
  final String       switchGroup;      // semantic-tag group label ("1", "2", "3")
  final List<int>    pressEndpoints;
  final List<int>    cwEndpoints;
  final List<int>    ccwEndpoints;
  final List<String> targetDeviceIds;

  List<int> get allEndpoints => [...pressEndpoints, ...cwEndpoints, ...ccwEndpoints];

  SwitchLink withTargets(List<String> targets) => SwitchLink(
    id:              id,
    sourceDeviceId:  sourceDeviceId,
    switchGroup:     switchGroup,
    pressEndpoints:  pressEndpoints,
    cwEndpoints:     cwEndpoints,
    ccwEndpoints:    ccwEndpoints,
    targetDeviceIds: targets,
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'sourceDeviceId':  sourceDeviceId,
    'switchGroup':     switchGroup,
    'pressEndpoints':  pressEndpoints,
    'cwEndpoints':     cwEndpoints,
    'ccwEndpoints':    ccwEndpoints,
    'targetDeviceIds': targetDeviceIds,
  };

  factory SwitchLink.fromJson(Map<String, dynamic> j) => SwitchLink(
    id:              j['id'] as String,
    sourceDeviceId:  j['sourceDeviceId'] as String,
    switchGroup:     j['switchGroup'] as String,
    pressEndpoints:  List<int>.from(j['pressEndpoints'] as List),
    cwEndpoints:     List<int>.from(j['cwEndpoints'] as List),
    ccwEndpoints:    List<int>.from(j['ccwEndpoints'] as List),
    targetDeviceIds: List<String>.from(j['targetDeviceIds'] as List),
  );
}

// ── ContactLink ───────────────────────────────────────────────────────────────
//
// Triggers in-app commands when a contact sensor (BooleanState 0x0045)
// transitions between open and closed states.
//
// onOpen  — target device IDs to toggle when contact opens  (state → false)
// onClose — target device IDs to toggle when contact closes (state → true)

class ContactLink {
  ContactLink({
    String? id,
    required this.sourceDeviceId,
    List<String>? onOpen,
    List<String>? onClose,
  }) : id = id ?? const Uuid().v4(),
       onOpen  = onOpen  ?? const [],
       onClose = onClose ?? const [];

  final String       id;
  final String       sourceDeviceId;
  final List<String> onOpen;
  final List<String> onClose;

  ContactLink withOpen(List<String> targets) => ContactLink(
    id: id, sourceDeviceId: sourceDeviceId,
    onOpen: targets, onClose: onClose,
  );

  ContactLink withClose(List<String> targets) => ContactLink(
    id: id, sourceDeviceId: sourceDeviceId,
    onOpen: onOpen, onClose: targets,
  );

  Map<String, dynamic> toJson() => {
    'id':             id,
    'sourceDeviceId': sourceDeviceId,
    'onOpen':         onOpen,
    'onClose':        onClose,
  };

  factory ContactLink.fromJson(Map<String, dynamic> j) => ContactLink(
    id:             j['id']             as String,
    sourceDeviceId: j['sourceDeviceId'] as String,
    onOpen:         List<String>.from(j['onOpen']  as List),
    onClose:        List<String>.from(j['onClose'] as List),
  );
}
