/// Thin snapshot of last-known live state persisted alongside [MatterDevice].
///
/// Written only at explicit checkpoints (user action such as toggle/setBrightness
/// and after a successful [DeviceProvider.refreshDevice]).  Never written in
/// the hot path of subscription events.
///
/// Read once at startup to seed [DeviceLiveData] before any subscription
/// arrives, so home-screen tiles show the last-known state immediately.
class PersistedSnapshot {
  final String  deviceId;
  final bool?   isOn;
  final int?    levelRaw;        // 0–254
  final int?    localTempCenti;
  final String? productName;

  const PersistedSnapshot({
    required this.deviceId,
    this.isOn,
    this.levelRaw,
    this.localTempCenti,
    this.productName,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        if (isOn           != null) 'isOn':          isOn,
        if (levelRaw       != null) 'levelRaw':      levelRaw,
        if (localTempCenti != null) 'localTempCenti': localTempCenti,
        if (productName    != null) 'productName':   productName,
      };

  factory PersistedSnapshot.fromJson(Map<String, dynamic> json) =>
      PersistedSnapshot(
        deviceId:       json['deviceId']       as String,
        isOn:           json['isOn']           as bool?,
        levelRaw:       json['levelRaw']       as int?,
        localTempCenti: json['localTempCenti'] as int?,
        productName:    json['productName']    as String?,
      );
}
