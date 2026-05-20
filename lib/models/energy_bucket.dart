/// One 15-minute energy bucket.
///
/// [time] is the start of the slot (floored to the nearest 15-min boundary,
/// local time).  [wh] is net imported Wh; [exportedWh] is net exported Wh
/// (0 for devices that don’t export).
class EnergyBucket {
  const EnergyBucket({
    required this.time,
    required this.wh,
    this.exportedWh = 0,
  });

  final DateTime time;
  final int      wh;          // imported Wh
  final int      exportedWh; // exported Wh (0 if n/a)

  Map<String, dynamic> toJson() => {
    't': time.millisecondsSinceEpoch,
    'w': wh,
    if (exportedWh > 0) 'x': exportedWh,
  };

  factory EnergyBucket.fromJson(Map<String, dynamic> j) => EnergyBucket(
    time:       DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    wh:         j['w'] as int,
    exportedWh: (j['x'] as int?) ?? 0,
  );
}
