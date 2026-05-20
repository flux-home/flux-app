/// One 15-minute energy consumption bucket.
///
/// [time] is the start of the slot (floored to the nearest 15-min boundary,
/// local time).  [wh] is the net imported energy consumed during the slot in
/// whole watt-hours.
class EnergyBucket {
  const EnergyBucket({required this.time, required this.wh});

  final DateTime time;
  final int      wh;

  Map<String, dynamic> toJson() => {
    't': time.millisecondsSinceEpoch,
    'w': wh,
  };

  factory EnergyBucket.fromJson(Map<String, dynamic> j) => EnergyBucket(
    time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    wh:   j['w'] as int,
  );
}
