import 'package:flutter/foundation.dart';
import 'package:matter_home/models/energy_summary.dart';

/// One attributed transfer: [watts] flowing from [from] to [to], right now.
@immutable
class EnergyTransfer {
  const EnergyTransfer(this.from, this.to, this.watts);

  final EnergyEndpoint from;
  final EnergyEndpoint to;
  final double watts;

  @override
  String toString() => '${from.label} -> ${to.label} ${watts.round()}W';
}

/// A participant in the home's energy flow. The label is what the user reads.
enum EnergyEndpoint {
  solar('Solar'),
  grid('Grid'),
  battery('Battery'),
  restOfHome('Rest of home'),
  heatPump('Heat pump'),
  car('Car');

  const EnergyEndpoint(this.label);
  final String label;
}

/// Attributes each source of power to each consumer of it.
///
/// Electricity is fungible — nothing physically marks a watt as "the solar
/// one". What this produces is the conventional reading every solar app uses,
/// and the only one that answers "did my car charge on sunlight?":
///
///   sources are spent in the order **solar → battery → grid**, and
///   consumers are served in the order **house → heat pump → car → battery →
///   export**.
///
/// So solar covers the house first, then the appliances, and only the surplus
/// reaches the battery and the grid; the grid is what pays for whatever is left
/// over. Change the order and you change the story the screen tells, which is
/// why it lives here in one place rather than inside a widget.
///
/// Sources and uses balance exactly (see [EnergySummary.houseLoad]) except when
/// [EnergySummary.restOfHome] has been clamped at zero by measurement skew; the
/// walk then ends with a little source unallocated rather than inventing a
/// consumer for it.
List<EnergyTransfer> attributeEnergy(EnergySummary s) {
  final sources = <(EnergyEndpoint, double)>[
    (EnergyEndpoint.solar, s.pvProduction),
    (EnergyEndpoint.battery, s.batteryDischarge),
    (EnergyEndpoint.grid, s.gridImport),
  ].where((e) => e.$2 > _minWatts).toList();

  final uses = <(EnergyEndpoint, double)>[
    (EnergyEndpoint.restOfHome, s.restOfHome),
    (EnergyEndpoint.heatPump, s.heatPump),
    (EnergyEndpoint.car, s.carCharging),
    (EnergyEndpoint.battery, s.batteryCharge),
    (EnergyEndpoint.grid, s.gridExport),
  ].where((e) => e.$2 > _minWatts).toList();

  final out = <EnergyTransfer>[];
  var si = 0;
  var ui = 0;
  var sLeft = sources.isEmpty ? 0.0 : sources.first.$2;
  var uLeft = uses.isEmpty ? 0.0 : uses.first.$2;

  while (si < sources.length && ui < uses.length) {
    final take = sLeft < uLeft ? sLeft : uLeft;
    if (take > _minWatts) {
      out.add(EnergyTransfer(sources[si].$1, uses[ui].$1, take));
    }
    sLeft -= take;
    uLeft -= take;
    if (sLeft <= _epsilon) {
      si++;
      sLeft = si < sources.length ? sources[si].$2 : 0;
    }
    if (uLeft <= _epsilon) {
      ui++;
      uLeft = ui < uses.length ? uses[ui].$2 : 0;
    }
  }
  return out;
}

/// Below this a transfer is noise, not information — a 3 W trickle would
/// otherwise earn a row of its own next to a 3 kW one.
const _minWatts = 20.0;
const _epsilon = 0.001;

/// Net power for a participant that can flow both ways (the grid, a battery).
///
/// Positive = consuming, negative = supplying, and anything within [deadbandW]
/// of zero is reported as exactly zero.
///
/// The deadband is what makes a zero-feed-in house readable. Such a house
/// regulates the grid to nothing on purpose, so the raw sign flips every few
/// seconds between a few watts of import and a few watts of export — a true
/// reading that carries no information and, drawn honestly, makes the display
/// twitch continuously. Inside the band the answer people actually want is
/// "balanced", so that is what this returns.
double netFlow({
  required double consuming,
  required double supplying,
  double deadbandW = 40,
}) {
  final net = consuming - supplying;
  return net.abs() < deadbandW ? 0 : net;
}
