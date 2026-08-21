import 'package:flutter/foundation.dart';

import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

/// Predicted AC production per interval, from the controller's own site model.
///
/// The controller fetches irradiance and runs the plane-of-array model on-device,
/// so this is a forecast for *this roof* rather than a generic sky reading. Times
/// are controller epochs, the same basis as the energy log and the price curve —
/// which is what lets all three share one axis without any clock arithmetic.
@immutable
class SolarForecastData {
  const SolarForecastData({
    required this.start,
    required this.resolution,
    required this.wattHours,
    required this.stale,
    required this.todayKwh,
    required this.tomorrowKwh,
    this.fetchedAt,
  });

  final DateTime start;
  final Duration resolution;
  final List<int> wattHours;
  /// True once now has run past the end of coverage: the numbers are a leftover
  /// prediction for hours that have already happened.
  final bool stale;
  final double todayKwh;
  final double tomorrowKwh;
  final DateTime? fetchedAt;

  bool get isEmpty => wattHours.isEmpty;
  DateTime timeAt(int i) => start.add(resolution * i);
  DateTime get end => start.add(resolution * wattHours.length);

  factory SolarForecastData.fromProto($proto.SolarForecast f) {
    final res = f.resolutionSeconds == 0 ? 3600 : f.resolutionSeconds;
    return SolarForecastData(
      start: DateTime.fromMillisecondsSinceEpoch(
          f.startEpoch.toInt() * 1000, isUtc: true).toLocal(),
      resolution: Duration(seconds: res),
      wattHours: List<int>.unmodifiable(f.wattHours),
      stale: f.stale,
      todayKwh: f.todayWh / 1000.0,
      tomorrowKwh: f.tomorrowWh / 1000.0,
      fetchedAt: f.fetchedAt.toInt() == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              f.fetchedAt.toInt() * 1000, isUtc: true).toLocal(),
    );
  }
}
