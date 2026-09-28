import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/models/solar_forecast.dart';
import 'package:matter_home/providers/device_provider.dart';

// Bars keep the flow card's solar amber; grid and battery stay darker so they
// separate from it on lightness, which colour-vision deficiency leaves intact.
const _cSolar    = Color(0xFFF6D08A);
const _cGrid     = Color(0xFFC4483A);
const _cExport   = Color(0xFF6FBF9B);
const _cSoc      = Color(0xFF8FA5E8);
/// The house, in the pink the flow card and the breakdown card already use for
/// it — the same thing should not change colour between cards.
const _cHome     = Color(0xFFF3B8D6);
/// Price is a brighter, cooler green than the export bars it may share a chart
/// with — and it is a LINE where export is a bar, so the two never rely on hue
/// alone to be told apart.
const _cPrice    = Color(0xFF7FE0A6);

/// Which series the chart can draw. The key is what gets persisted, so renaming
/// one silently resets that toggle rather than crashing — acceptable, and the
/// reason the keys are short and stable.
enum _Series {
  solar('solar', 'Solar', _cSolar),
  // ONE series for the grid connection, not two.
  //
  // Import and export are the same meter with the sign flipped — you cannot buy
  // and sell in the same instant — so two chips offered a choice that does not
  // exist and implied two independent things. Direction is already carried by the
  // axis: bought sits above the zero line, sold below it, each in its own colour.
  grid('grid', 'Grid', _cGrid),
  // Key stays 'charge' though the label reads Battery: the key is what is
  // persisted, so renaming it would silently reset the toggle for anyone who had
  // already chosen.
  charge('charge', 'Battery', _cSoc),
  home('home', 'Home', _cHome),
  sun('sun', 'Sun forecast', _cSolar),
  price('price', 'Price', _cPrice);

  const _Series(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;

  static _Series? byKey(String k) {
    for (final s in values) { if (s.key == k) return s; }
    return null;   // a key from a newer version: ignored, not fatal
  }
}

DateTime _hourFloor(DateTime t) => DateTime(t.year, t.month, t.day, t.hour);

/// The time range the chart covers, and where NOW falls inside it.
///
/// Computed once from the same three inputs the painter draws, and used by BOTH
/// the painter and the gesture handler. They must agree: the x axis is mapped by
/// TIME and runs past the measured data into the forecast, so a gesture that maps
/// x to a bucket INDEX cannot address the half of the chart that has no buckets —
/// which is exactly how the crosshair came to stop at NOW however far right you
/// dragged.
@immutable
class _TimeDomain {
  const _TimeDomain(this.start, this.histEnd, this.end);

  final DateTime start;   // left edge: the first drawn hour
  final DateTime histEnd; // end of MEASURED data — this is NOW
  final DateTime end;     // right edge, forecast included

  int get spanSeconds => end.difference(start).inSeconds;

  double x(DateTime t, double plotL, double plotW) =>
      plotL + t.difference(start).inSeconds / spanSeconds * plotW;

  DateTime timeAt(double frac) =>
      start.add(Duration(seconds: (spanSeconds * frac).round()));

  bool isAhead(DateTime t) => !t.isBefore(histEnd);
}

/// Builds the domain for one calendar day.
///
/// The axis is the day itself — midnight to midnight — and no longer stretches to
/// wherever the forecast happens to reach. That was the old horizon clamp, and it
/// existed only because one chart was being asked to hold both the measured past
/// and a 60-hour forecast; with a page per day the forecast lives on the pages
/// whose day it describes, and the clamp has nothing left to do.
///
/// [now] fixes where measurement stops: the whole day on a past page, the moment
/// itself on today's, and the very start on a page that has not happened.
_TimeDomain _domainFor(DateTime dayStart, DateTime dayEnd, DateTime now) {
  var histEnd = now;
  if (histEnd.isBefore(dayStart)) histEnd = dayStart;
  if (histEnd.isAfter(dayEnd)) histEnd = dayEnd;
  return _TimeDomain(dayStart, histEnd, dayEnd);
}

/// One timeline: the last 24 hours and the price forecast on a single time axis,
/// with NOW between them.
///
/// This replaces two cards that each drew their own time axis — and drew some of
/// the same series on both. Sharing one axis is the whole point: the question a
/// dynamic tariff creates is always about a moment ("was that expensive?", "is
/// the cheap window before or after the sun?"), and two charts side by side make
/// the reader align hours by eye.
///
/// Price keeps its own scale, labelled on the right in its own colour. That is a
/// second y axis, which this codebase otherwise avoids — the honest version of it
/// is to label both scales and let the crosshair give exact values, rather than
/// pretending one axis serves both.
class EnergyTimelineCard extends StatefulWidget {
  const EnergyTimelineCard({super.key});

  @override
  State<EnergyTimelineCard> createState() => _EnergyTimelineCardState();
}

class _EnergyTimelineCardState extends State<EnergyTimelineCard> {
  /// What the crosshair is pointing at, as a TIME. An index would only be able
  /// to name a measured bucket, and half this chart is forecast.
  DateTime? _selectedTime;

  /// How far back the pager reaches — the span the bucket cache keeps, since a
  /// page older than that would have nothing to show and no way to get it.
  static const _maxBackDays = 45;
  static const _pageHeight = 262.0;

  late final PageController _pager =
      PageController(initialPage: _maxBackDays);

  /// Page index to day offset. Index rises with time, so swiping left moves
  /// forward — the direction the chevrons already meant.
  int _offsetFor(int index) => _maxBackDays - index;

  /// Keeps the pager on the day the provider holds, for the chevrons and the
  /// "Today" button, which change the day without touching the pager.
  void _syncPager(DeviceProvider p) {
    final want = _maxBackDays - p.historyOffsetDays;
    if (!_pager.hasClients) return;
    final at = _pager.page?.round();
    if (at == null || at == want) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pager.hasClients) return;
      _pager.animateToPage(want,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }
  Set<_Series>? _shown;
  Timer? _refresh;

  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // This card is what ASKS for both data sets. The two cards it replaced each
    // fetched their own on mount and on a timer; merging the views without
    // merging the fetches is why it first rendered "no energy history yet" —
    // nothing had requested any.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    _refresh = Timer.periodic(_refreshInterval, (_) => _fetch());
  }

  void _fetch() {
    if (!mounted) return;
    final p = context.read<DeviceProvider>();
    // A past day does not change; polling it would re-request fixed history
    // every 30 seconds for nothing.
    if (p.historyOffsetDays != 0) return;
    p.fetchEnergyHistory();
    p.fetchEnergyPrices();
    p.fetchSolarForecast();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _pager.dispose();
    super.dispose();
  }

  /// Everything except what the user switched off — so a series added later is
  /// visible without them having to discover a chip and turn it on.
  Set<_Series> _seriesFor(DeviceProvider p) {
    if (_shown != null) return _shown!;
    final hidden = p.chartHidden.map(_Series.byKey).whereType<_Series>().toSet();
    return _Series.values.toSet().difference(hidden);
  }

  void _toggle(DeviceProvider p, _Series s) {
    final next = {..._seriesFor(p)};
    next.contains(s) ? next.remove(s) : next.add(s);
    setState(() => _shown = next);
    p.setChartHidden([
      for (final e in _Series.values)
        if (!next.contains(e)) e.key,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final prices = provider.historyPrices;
    final shown = _seriesFor(provider);
    _syncPager(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text('ENERGY & PRICE', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 2.4,
                  color: cs.onSurfaceVariant)),
              const Spacer(),
              if (provider.historyOffsetDays == 0 &&
                  prices != null && !prices.isEmpty)
                Text(_priceNow(prices), style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The day picker stays OUTSIDE the pager: it is the one thing on
                // the card that must not move while the days slide under it.
                _windowBar(context, provider),
                const SizedBox(height: 6),
                SizedBox(
                  height: _pageHeight,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: _maxBackDays + 1 + provider.maxAheadDays,
                    onPageChanged: (i) =>
                        provider.setHistoryOffsetDays(_offsetFor(i)),
                    itemBuilder: (context, i) =>
                        _page(context, provider, _offsetFor(i), prices, shown),
                  ),
                ),
                const SizedBox(height: 12),
                // Below the chart: the chips are a control for what is above
                // them, and reading order should reach the picture first.
                _chips(context, provider, shown),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One day. Only the day actually on screen has data — the provider holds one
  /// day at a time — so its neighbours render as a hint of themselves rather than
  /// pretending to numbers nobody has fetched.
  Widget _page(BuildContext context, DeviceProvider p, int offset,
      EnergyPrices? prices, Set<_Series> shown) {
    final cs = Theme.of(context).colorScheme;
    if (offset != p.historyOffsetDays) {
      return Center(
        child: Text(_dayLabel(offset),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      );
    }

    final data = p.energyHistory;
    final ahead = offset < 0;
    final measured = data != null && !data.isEmpty;

    // A day ahead is not "no data" — it is a day that has not happened, and it
    // still has a price curve and a forecast worth drawing. Saying "no energy
    // history" there would report a fault where there is none.
    if (!measured && !ahead) {
      return Center(
        child: Text(
            p.energyHistoryLoading ? 'Loading…' : 'No energy history yet.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      );
    }

    final forDrawing = data ?? _emptyDay(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ahead)
          _aheadHero(context, p, prices)
        else ...[
          _hero(context, forDrawing, offset),
          if (p.solarForecast != null && offset == 0) ...[
            const SizedBox(height: 4),
            _sunLine(context, p.solarForecast!),
          ] else if (forDrawing.hasArchivedForecast) ...[
            const SizedBox(height: 4),
            _archivedSunLine(context, forDrawing),
          ],
        ],
        const SizedBox(height: 12),
        _plot(context, forDrawing, prices, shown),
        if (measured && !forDrawing.timeSynced)
          _note(context, 'Times approximate — controller clock not yet synced'),
      ],
    );
  }

  /// A day with no measurement, so the chart has the shape it needs without
  /// anything being invented to fill it.
  EnergyHistoryData _emptyDay(DeviceProvider p) => const EnergyHistoryData(
        points: [],
        bucket: Duration(hours: 1),
        timeSynced: true,
        truncated: false,
        pvKwh: 0,
        gridImportKwh: 0,
        gridExportKwh: 0,
        loadKwh: 0,
      );

  /// The headline for a day that has not happened: what is expected, stated as
  /// an expectation. There is no "used" figure to give, and inventing one from
  /// the forecast would dress a prediction as a measurement.
  Widget _aheadHero(BuildContext context, DeviceProvider p, EnergyPrices? prices) {
    final cs = Theme.of(context).colorScheme;
    final (dayStart, dayEnd) = p.historyDay;
    final f = p.solarForecast;
    var wh = 0;
    if (f != null && !f.isEmpty) {
      for (var k = 0; k < f.wattHours.length; k++) {
        final t = f.timeAt(k);
        if (!t.isBefore(dayStart) && t.isBefore(dayEnd)) wh += f.wattHours[k];
      }
    }
    final avg = prices?.avgCtIn(dayStart, dayEnd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text((wh / 1000.0).toStringAsFixed(1), style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
            const SizedBox(width: 4),
            Text('kWh', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
            const SizedBox(width: 9),
            Text('of sun expected', style: TextStyle(
                fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          avg == null
              ? 'No prices published for this day yet'
              : 'Grid price Ø ${avg.toStringAsFixed(1)} ct · '
                'cheapest ${_cheapestLabel(prices!, dayStart, dayEnd)}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _cheapestLabel(EnergyPrices prices, DateTime from, DateTime to) {
    PricePoint? best;
    for (final p in prices.points) {
      if (p.time.isBefore(from) || !p.time.isBefore(to)) continue;
      if (best == null || p.ctPerKwh < best.ctPerKwh) best = p;
    }
    return best == null
        ? '—'
        : '${best.time.hour.toString().padLeft(2, '0')}:00';
  }

  /// Names the day an offset points at. 0 is today, negative is ahead.
  String _dayLabel(int offset) {
    switch (offset) {
      case 0:  return 'Today';
      case 1:  return 'Yesterday';
      case -1: return 'Tomorrow';
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day - offset);
    return '${d.day} ${months[d.month - 1]}';
  }

  /// Turn a day at a time. The pager does the same thing by swipe; these stay
  /// because a chevron is discoverable and a swipe is not, and because the chart
  /// itself answers a long press, which a page-wide gesture would swallow.
  Widget _windowBar(BuildContext context, DeviceProvider p) {
    final cs = Theme.of(context).colorScheme;
    final off = p.historyOffsetDays;
    final ahead = off < 0;

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left, size: 20),
          tooltip: 'A day earlier',
          onPressed: () => p.setHistoryOffsetDays(off + 1),
        ),
        Text(_dayLabel(off), style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: off == 0 ? cs.onSurfaceVariant : cs.onSurface)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right, size: 20),
          // Forward now goes somewhere: as far as the price curve and the
          // forecast actually reach, and no further.
          onPressed: off <= -p.maxAheadDays
              ? null
              : () => p.setHistoryOffsetDays(off - 1),
          tooltip: 'A day later',
        ),
        if (ahead) ...[
          const SizedBox(width: 6),
          Text('FORECAST', style: TextStyle(
              fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 1.6, color: cs.onSurfaceVariant)),
        ],
        const Spacer(),
        if (off != 0)
          TextButton(
            onPressed: () => p.setHistoryOffsetDays(0),
            child: const Text('Today'),
          ),
      ],
    );
  }

  String _priceNow(EnergyPrices prices) {
    final now = DateTime.now();
    final cur = prices.currentAt(now);
    final avg = prices.avgCtIn(now.subtract(const Duration(hours: 24)), now) ??
        prices.avgCt;
    final nowPart = cur == null ? '—' : '${cur.ctPerKwh.toStringAsFixed(1)} ct';
    return '$nowPart now · Ø ${avg.toStringAsFixed(1)}';
  }

  /// The forecast's own headline. Today's figure is what the roof is expected to
  /// make in total, so partway through a day it will exceed what has been
  /// generated so far — saying "today" rather than "remaining" keeps it
  /// comparable with tomorrow's.
  Widget _sunLine(BuildContext context, SolarForecastData f) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      f.stale
          ? 'Sun forecast out of date'
          : 'Sun forecast · ${f.todayKwh.toStringAsFixed(1)} kWh today · '
            '${f.tomorrowKwh.toStringAsFixed(1)} tomorrow',
      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
    );
  }

  /// How the forecast for a past day compares with what the roof actually made —
  /// the only version of this line that is a claim you can check.
  Widget _archivedSunLine(BuildContext context, EnergyHistoryData data) {
    final cs = Theme.of(context).colorScheme;
    var wh = 0;
    for (final v in data.forecastWh) {
      if (v != null) wh += v;
    }
    final predicted = wh / 1000.0;
    final actual = data.pvKwh;
    final delta = predicted <= 0 ? null : (actual - predicted) / predicted * 100;
    return Text(
      'Sun forecast said ${predicted.toStringAsFixed(1)} kWh · '
      'made ${actual.toStringAsFixed(1)}'
      '${delta == null ? '' : ' (${delta >= 0 ? '+' : ''}${delta.round()}%)'}',
      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
    );
  }

  Widget _hero(BuildContext context, EnergyHistoryData data, int offset) {
    final cs = Theme.of(context).colorScheme;
    // "24 h" was true of a rolling window and is not true of a calendar day.
    final label = offset == 0 ? 'used · today so far' : 'used · full day';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(data.consumptionKwh.toStringAsFixed(1), style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        const SizedBox(width: 4),
        Text('kWh', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant)),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(
            fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  /// The chips ARE the legend: one row of words instead of two saying the same
  /// thing, and tapping the word that names a series is where anyone would look
  /// to turn it off.
  Widget _chips(BuildContext context, DeviceProvider p, Set<_Series> shown) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        for (final s in _Series.values)
          GestureDetector(
            onTap: () => _toggle(p, s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: shown.contains(s)
                        ? s.color
                        : cs.outlineVariant,
                    width: 1.2),
                color: shown.contains(s)
                    ? s.color.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shown.contains(s)
                          ? s.color
                          : cs.onSurfaceVariant.withValues(alpha: 0.35),
                      // The grid chip carries both of its colours: bought above
                      // the line, sold below it, one toggle for the one meter.
                      gradient: s == _Series.grid && shown.contains(s)
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_cGrid, _cExport],
                              stops: [0.5, 0.5],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(s.label, style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: shown.contains(s)
                          ? cs.onSurface
                          : cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _plot(BuildContext context, EnergyHistoryData data,
      EnergyPrices? prices, Set<_Series> shown) {
    final cs = Theme.of(context).colorScheme;
    // Resolved once, and handed to both the gesture and the painter, so the two
    // read the same axis.
    final drawnPrices = shown.contains(_Series.price) ? prices : null;
    final provider = context.watch<DeviceProvider>();
    // The live forecast describes today and the days ahead. On a past page it
    // would be a prediction about a day that has already happened, so that page
    // draws the forecast archived for it instead.
    final drawnSolar = shown.contains(_Series.sun) &&
            provider.historyOffsetDays <= 0
        ? provider.solarForecast
        : null;
    final (dayStart, dayEnd) = provider.historyDay;
    final domain = _domainFor(dayStart, dayEnd, DateTime.now());

    return LayoutBuilder(builder: (context, c) {
      void selectAt(Offset local) {
        final plotL = _TimelinePainter.padLeft;
        final plotR = c.maxWidth - _TimelinePainter.padRight;
        if (plotR <= plotL) return;
        // Clamped to the plot, not to the measured half: dragging into the
        // forecast selects a forecast hour, which is the only way to read the
        // price or the sun that is drawn there.
        final frac = ((local.dx - plotL) / (plotR - plotL)).clamp(0.0, 1.0);
        setState(() => _selectedTime = domain.timeAt(frac));
      }

      // A horizontal drag now belongs to the pager, which is how days are
      // turned. Scrubbing the crosshair is a long press — the gesture that says
      // "I mean this chart, not the page" — and a plain tap still reads one hour.
      return GestureDetector(
        onLongPressStart:      (d) => selectAt(d.localPosition),
        onLongPressMoveUpdate: (d) => selectAt(d.localPosition),
        onLongPressEnd:        (_) => setState(() => _selectedTime = null),
        onLongPressCancel:     ()  => setState(() => _selectedTime = null),
        onTapDown: (d) => selectAt(d.localPosition),
        onTapUp:   (_) => setState(() => _selectedTime = null),
        onTapCancel: ()  => setState(() => _selectedTime = null),
        child: SizedBox(
          height: 168,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TimelinePainter(
              data: data,
              prices: drawnPrices,
              // The LIVE forecast belongs to today only — on a past day it would
              // be tomorrow's guess drawn over what already happened. The past
              // day draws the forecast that was actually made for it, archived
              // bucket by bucket while it was live (see EnergyBucketRow).
              solar: drawnSolar,
              domain: domain,
              archivedForecast: shown.contains(_Series.sun),
              batteryKwh: provider.batteryCapacityKwh,
              shown: shown,
              selectedTime: _selectedTime,
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
              nowColor: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    });
  }

  Widget _note(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text, style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Draws the whole timeline: past on the left, forecast on the right, NOW
/// between them.
///
/// The x mapping is by TIME, not by index, because the two data sets have
/// different cadences — energy comes in 15-minute buckets, price in hours, and
/// the forecast runs past the end of both. Mapping by index would slide them
/// against each other and make the crosshair lie.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.data,
    required this.prices,
    required this.solar,
    required this.archivedForecast,
    required this.domain,
    required this.batteryKwh,
    required this.shown,
    required this.selectedTime,
    required this.axisColor,
    required this.labelColor,
    required this.nowColor,
  });

  final EnergyHistoryData data;
  final EnergyPrices? prices;
  final SolarForecastData? solar;
  /// Draw the per-bucket forecast archived with the history, when there is one
  /// and no live forecast applies to this window.
  final bool archivedForecast;
  /// The axis, shared with the gesture handler — see [_TimeDomain].
  final _TimeDomain domain;

  /// Usable battery capacity in kWh, when known. A charge level is a percentage
  /// of something, and without the something it cannot be compared with anything
  /// else on the chart.
  final double? batteryKwh;
  final Set<_Series> shown;
  final DateTime? selectedTime;
  final Color axisColor;
  final Color labelColor;
  final Color nowColor;

  // Not private: the gesture handler measures the plot with the same numbers,
  // and a second copy of them would drift.
  static const padLeft = 26.0;   // kWh labels
  static const padRight = 30.0;  // ct/kWh labels
  static const _padBottom = 14.0; // time axis

  @override
  void paint(Canvas canvas, Size size) {

    // Bars are aggregated to the hour. At 15-minute buckets across a window that
    // now includes the forecast, each bar came out about two pixels wide — and
    // the price curve this shares an axis with is hourly anyway, so the finer
    // grain bought nothing but noise.
    // May be empty: a day ahead has a price curve and a forecast but nothing
    // measured, and that page still has a chart to draw.
    final pts = _hourly(data);
    const bucket = Duration(hours: 1);
    // The archive is drawn only where no live forecast applies — on today the
    // live one is both newer and forward-looking, and drawing both would put two
    // dashed amber lines on the same hours.
    final drawArchivedForecast = archivedForecast &&
        (solar == null || solar!.isEmpty) &&
        _hourForecastWh.any((v) => v != null);

    // ── time domain ────────────────────────────────────────────────────
    //
    // NOW is the end of MEASURED data, not the phone's clock.
    //
    // Everything here is stamped by the CONTROLLER — energy buckets from
    // EnergyHistory.start, prices from PriceCurve.start_epoch, the forecast from
    // SolarForecast.start_epoch — so all three already agree with each other, and
    // they agree with the controller's clock rather than the phone's. An earlier
    // version of this shifted the price curve by the phone/controller
    // difference, on the mistaken belief that price came from the phone; that
    // displaced it by exactly the clock error it was trying to correct. The only
    // thing the phone's clock is good for here is nothing at all.
    final dom = domain;
    final tStart = dom.start;
    final histEnd = dom.histEnd;
    final tEnd = dom.end;
    final span = dom.spanSeconds;
    if (span <= 0) return;

    final plotL = padLeft;
    final plotR = size.width - padRight;
    final plotW = plotR - plotL;
    final base = size.height - _padBottom;
    final top = 12.0;
    final plotH = base - top;
    double x(DateTime t) =>
        plotL + t.difference(tStart).inSeconds / span * plotW;

    // ── what has not happened yet, tinted ──────────────────────────────
    final nowX = x(histEnd);
    if (nowX < plotR) {
      canvas.drawRect(Rect.fromLTRB(nowX, top, plotR, base),
          Paint()..color = labelColor.withValues(alpha: 0.04));
    }

    // ── kWh scale ──────────────────────────────────────────────────────
    //
    // Each hour is drawn as a PAIR of bars off one baseline: what supplied the
    // house on the left, what used it on the right.
    //
    // A pair rather than one stack, because the house cannot simply be added to
    // the old bar without counting the same kilowatt-hour twice — solar that
    // charges the battery at noon would appear as solar now and as discharge
    // again at nine. The energy balance is
    //   pv + import + discharge  =  home + export + charge
    // so the two bars are equal by definition every hour, and a visible gap
    // between them means something in the house is not being metered.
    const hPerBucket = 1.0;   // hourly bars
    double supply(EnergyHistoryPoint p) =>
        (shown.contains(_Series.solar) ? p.pvW : 0) +
        (shown.contains(_Series.charge) ? p.batteryDischargeW : 0) +
        (shown.contains(_Series.grid) ? p.gridImportW : 0);
    double use(EnergyHistoryPoint p) =>
        (shown.contains(_Series.home) ? p.consumptionW : 0) +
        (shown.contains(_Series.charge) ? p.batteryChargeW : 0) +
        (shown.contains(_Series.grid) ? p.gridExportW : 0);
    // Kept for the crosshair, which reports the hour's consumption.
    double up(EnergyHistoryPoint p) => supply(p);
    final peakUp = pts.fold<double>(
        0, (m, p) => [m, supply(p), use(p)].reduce((a, b) => a > b ? a : b));

    var peakUpKwh = peakUp * hPerBucket / 1000.0;
    // A forecast hour can exceed anything measured — a sunny tomorrow after a
    // dull today — and a scale built only on measurement then puts that bar
    // above the top of the plot. Which is exactly what happened: unclipped, it
    // painted over the rest of the screen.
    if (solar != null && !solar!.isEmpty) {
      for (final e in _forecastByHour().entries) {
        if (e.key.isBefore(tStart) || !e.key.isBefore(tEnd)) continue;
        if (e.value > peakUpKwh) peakUpKwh = e.value;
      }
    } else if (drawArchivedForecast) {
      // An archived forecast sits over the measured day rather than past it, so
      // it can exceed the bars it is drawn against — a day that underperformed
      // its prediction is exactly the case worth seeing, and clipping it would
      // hide the gap that is the whole point.
      for (final wh in _hourForecastWh) {
        if (wh == null) continue;
        final kwh = wh / 1000.0;
        if (kwh > peakUpKwh) peakUpKwh = kwh;
      }
    }
    final step = _niceStep((peakUpKwh <= 0 ? 1 : peakUpKwh) / 2);
    final gridTop = (peakUpKwh / step).ceil().clamp(1, 1000) * step;
    // Nothing hangs below the line any more: export moved into the "used" bar,
    // where it belongs — energy leaving the house is a use of it, not a negative
    // import — so the baseline sits on the floor of the plot.
    final zeroY = top + plotH;
    double yKwh(double kwh) => zeroY - (kwh / gridTop) * (zeroY - top);

    // Everything from here draws inside the plot only. A CustomPaint does not
    // clip on its own, so without this a single out-of-range value escapes the
    // widget entirely and paints across the screen — not a wrong pixel, a
    // corrupted app. The price card learned this the same way.
    // Axis labels live in the GUTTERS, which are outside the clip below — so
    // they are collected here and drawn after it is lifted. Drawing them inside
    // it removed every one of them: a right-aligned label ending at plotL - 4 is
    // entirely to the left of the clip, and the ct labels are entirely to the
    // right of it, so the chart has been running with a bare, unlabelled scale.
    final kwhTicks = <(String, double)>[];
    final ctTicks = <(String, double)>[];

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plotL, 0, plotR, size.height));

    final grid = Paint()..strokeWidth = 1;
    for (var v = step; v <= gridTop + 1e-9; v += step) {
      final gy = yKwh(v);
      canvas.drawLine(Offset(plotL, gy), Offset(plotR, gy),
          grid..color = axisColor.withValues(alpha: 0.16));
      kwhTicks.add((v.toStringAsFixed(step < 1 ? 1 : 0), gy));
    }
    canvas.drawLine(Offset(plotL, zeroY), Offset(plotR, zeroY),
        Paint()..color = axisColor..strokeWidth = 1);

    // ── charge band, behind everything ─────────────────────────────────
    if (shown.contains(_Series.charge) && data.hasSoc) {
      final soc = _hourSoc;
      var i = 0;
      while (i < soc.length) {
        if (soc[i] == null) { i++; continue; }
        var j = i;
        while (j + 1 < soc.length && soc[j + 1] != null) { j++; }
        double socY(double pct) => zeroY - (pct / 100) * (zeroY - top);
        final edge = Path();
        for (var k = i; k <= j; k++) {
          final o = Offset(x(pts[k].time), socY(soc[k]!));
          k == i ? edge.moveTo(o.dx, o.dy) : edge.lineTo(o.dx, o.dy);
        }
        final fill = Path.from(edge)
          ..lineTo(x(pts[j].time), zeroY)
          ..lineTo(x(pts[i].time), zeroY)
          ..close();
        canvas.drawPath(fill, Paint()..color = _cSoc.withValues(alpha: 0.06));
        canvas.drawPath(edge, Paint()
          ..color = _cSoc.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
        i = j + 1;
      }
    }

    // ── bars: supplied | used, one pair an hour ────────────────────────
    final slot = plotW * (bucket.inSeconds / span);
    // Two bars and the air between them share the slot. Capped so a wide screen
    // gets breathing room rather than two fat blocks.
    final bw = (slot * 0.34).clamp(1.5, 12.0);
    const pairGap = 1.5;

    void stack(double left, List<(double, Color)> segs) {
      var y = zeroY;
      final drawn = segs.where((e) => e.$1 > 0).toList();
      for (var k = 0; k < drawn.length; k++) {
        final h = drawn[k].$1 * hPerBucket / 1000.0 / gridTop * (zeroY - top);
        final rect = Rect.fromLTWH(left, y - h, bw, h);
        if (k == drawn.length - 1) {
          final r = Radius.circular((bw / 3).clamp(1.0, 3.0));
          canvas.drawRRect(
              RRect.fromRectAndCorners(rect, topLeft: r, topRight: r),
              Paint()..color = drawn[k].$2);
        } else {
          canvas.drawRect(rect, Paint()..color = drawn[k].$2);
        }
        // A gap in the surface colour separates the segments; a stroke round
        // each one would add ink that is not data.
        y -= h + 1.5;
      }
    }

    for (final p in pts) {
      final gx = x(p.time) + slot / 2 - (bw * 2 + pairGap) / 2;
      // Supplied: generated, drawn from the battery, bought.
      stack(gx, [
        if (shown.contains(_Series.solar)) (p.pvW, _cSolar),
        if (shown.contains(_Series.charge)) (p.batteryDischargeW, _cSoc),
        if (shown.contains(_Series.grid)) (p.gridImportW, _cGrid),
      ]);
      // Used: the house, what went into the battery, what was sold.
      stack(gx + bw + pairGap, [
        if (shown.contains(_Series.home)) (p.consumptionW, _cHome),
        if (shown.contains(_Series.charge)) (p.batteryChargeW, _cSoc),
        if (shown.contains(_Series.grid)) (p.gridExportW, _cExport),
      ]);
    }

    // ── the forecast: a line, in the solar colour, dashed ──────────────
    //
    // Same quantity as the solar bars and therefore the same scale — predicted
    // and measured production are the same thing in the same unit, so they must
    // not be given different axes. What differs is confidence, and the dash says
    // that: solid bars were measured, the dashed line is expected.
    //
    // Drawn across the WHOLE covered range, not just the future. Over the past
    // it lies on top of the bars it predicted, which turns the chart into a check
    // on the forecast itself — cheap to look at, and the thing that decides
    // whether the forecast should ever be trusted to drive a decision.
    if (solar != null && !solar!.isEmpty) {
      final byHour = _forecastByHour().entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final pts2 = <Offset>[];
      for (final e in byHour) {
        if (e.key.isBefore(tStart) || !e.key.isBefore(tEnd)) continue;
        pts2.add(Offset(x(e.key) + slot / 2,
            zeroY - (e.value / gridTop) * (zeroY - top)));
      }
      final paint = Paint()
        ..color = _cSolar.withValues(alpha: solar!.stale ? 0.3 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k + 1 < pts2.length; k++) {
        _dashedLine(canvas, pts2[k], pts2[k + 1], paint);
      }
    } else if (drawArchivedForecast) {
      // The forecast that was made FOR these hours, stored beside them while
      // they were live. Drawn identically to the live one — same colour, same
      // dash, same scale — because it is the same quantity; only its subject is
      // in the past. Laid over the bars it predicted, the chart becomes a score
      // of the forecast rather than an advertisement for it.
      final pts3 = <Offset>[];
      for (var k = 0; k < pts.length && k < _hourForecastWh.length; k++) {
        final wh = _hourForecastWh[k];
        if (wh == null) continue;
        pts3.add(Offset(x(pts[k].time) + slot / 2,
            zeroY - (wh / 1000.0 / gridTop) * (zeroY - top)));
      }
      final paint = Paint()
        ..color = _cSolar.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k + 1 < pts3.length; k++) {
        _dashedLine(canvas, pts3[k], pts3[k + 1], paint);
      }
    }

    // ── price, its own scale, labelled on the right in its own colour ──
    if (prices != null && prices!.points.isNotEmpty) {
      final inView = [
        for (final p in prices!.points)
          if (!p.time.isBefore(tStart) && !p.time.isAfter(tEnd)) p,
      ];
      if (inView.length > 1) {
        var lo = inView.first.ctPerKwh, hi = lo;
        for (final p in inView) {
          if (p.ctPerKwh < lo) lo = p.ctPerKwh;
          if (p.ctPerKwh > hi) hi = p.ctPerKwh;
        }
        if (hi - lo < 1) hi = lo + 1;
        double yCt(double ct) => base - (ct - lo) / (hi - lo) * plotH * 0.92;

        // A step, not a slope. A spot tariff is constant within its interval and
        // jumps at the boundary; drawing a diagonal between two hours invents
        // prices that were never offered, and makes the moment a price changed —
        // the thing you would act on — impossible to locate.
        final path = Path();
        for (var k = 0; k < inView.length; k++) {
          final t0 = inView[k].time;
          final t1 = k + 1 < inView.length
              ? inView[k + 1].time
              : t0.add(const Duration(hours: 1));
          final y = yCt(inView[k].ctPerKwh);
          k == 0 ? path.moveTo(x(t0), y) : path.lineTo(x(t0), y);
          path.lineTo(x(t1), y);
        }
        canvas.drawPath(path, Paint()
          ..color = _cPrice
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);
        for (final v in [lo, hi]) {
          ctTicks.add((v.toStringAsFixed(0), yCt(v)));
        }
      }
    }

    // ── NOW, and the crosshair ─────────────────────────────────────────
    if (nowX > plotL && nowX < plotR) {
      canvas.drawLine(Offset(nowX, top), Offset(nowX, base),
          Paint()..color = nowColor..strokeWidth = 1);
      _tinyLabel(canvas, 'NOW', Offset(nowX + 3, top - 2), nowColor);
    }
    final sel = selectedTime;
    if (sel != null) {
      final hour = _hourFloor(sel);
      final sx = x(hour) + slot / 2;
      canvas.drawLine(Offset(sx, top), Offset(sx, base),
          Paint()..color = labelColor.withValues(alpha: 0.55)..strokeWidth = 1);
      _tinyLabel(canvas, _readout(hour, pts, hPerBucket, up),
          Offset(plotR, top - 2), labelColor, rightAlign: true);
    }

    canvas.restore();

    // ── the two scales, named ──────────────────────────────────────────
    // A number with no unit on a chart carrying kWh on one side and ct/kWh on
    // the other is an invitation to read the wrong one.
    for (final (text, gy) in kwhTicks) {
      _tinyLabel(canvas, text, Offset(plotL - 4, gy - 5), labelColor,
          rightAlign: true, weight: FontWeight.w400);
    }
    // The unit sits on the time-axis row, not above the top gridline: up there it
    // lands on the highest tick and the two print over each other.
    _tinyLabel(canvas, 'kWh', Offset(plotL - 4, base + 3), labelColor,
        rightAlign: true);
    for (final (text, gy) in ctTicks) {
      _tinyLabel(canvas, text, Offset(plotR + 4, gy - 5), _cPrice,
          weight: FontWeight.w400);
    }
    if (ctTicks.isNotEmpty) {
      _tinyLabel(canvas, 'ct', Offset(plotR + 4, base + 3), _cPrice);
    }

    // ── time axis ──────────────────────────────────────────────────────
    // Outside the clip: its labels belong in the gutter under the plot.
    for (var f = 0.0; f < 1.0; f += 0.25) {
      final t = tStart.add(Duration(seconds: (span * f).round()));
      final lx = plotL + f * plotW;
      _tinyLabel(canvas, '${t.hour.toString().padLeft(2, '0')}:00',
          Offset(lx + (f == 0 ? 0 : -12), base + 3), labelColor,
          weight: FontWeight.w400);
    }
  }

  /// What the crosshair says at [hour].
  ///
  /// Behind NOW that is what was measured; ahead of it there is no measurement,
  /// so it is what is drawn there instead — the price, and the sun expected. An
  /// hour with a forecast and a price is the whole reason to look at that half of
  /// the chart, and before this it had no readout at all.
  String _readout(DateTime hour, List<EnergyHistoryPoint> pts, double hPerBucket,
      double Function(EnergyHistoryPoint) up) {
    final hh = '${hour.hour.toString().padLeft(2, '0')}:00';
    final parts = <String>[];

    for (final p in pts) {
      if (p.time == hour) {
        parts.add('${(p.consumptionW * hPerBucket / 1000).toStringAsFixed(2)} '
            'kWh used');
        break;
      }
    }
    if (parts.isEmpty && solar != null && !solar!.isEmpty) {
      // Ahead of now: what the roof is expected to make in this hour — the whole
      // hour, not one of its intervals.
      final kwh = _forecastByHour()[hour];
      if (kwh != null) parts.add('${kwh.toStringAsFixed(2)} kWh sun');
    }
    // The charge level, as an amount rather than a proportion. "78%" cannot be
    // weighed against an hour that used 1.3 kWh; "12.4 kWh" can, and that is the
    // comparison the chart exists to make.
    if (shown.contains(_Series.charge)) {
      for (var i = 0; i < pts.length && i < _hourSoc.length; i++) {
        if (pts[i].time != hour) continue;
        final pct = _hourSoc[i];
        if (pct == null) break;
        final cap = batteryKwh;
        parts.add(cap == null
            ? '${pct.round()}%'
            : '${(pct / 100 * cap).toStringAsFixed(1)} kWh stored');
        break;
      }
    }

    final price = prices?.currentAt(hour);
    if (price != null) parts.add('${price.ctPerKwh.toStringAsFixed(1)} ct');

    return parts.isEmpty ? hh : '$hh  ${parts.join(' · ')}';
  }

  /// Sums the 15-minute buckets into hours, carrying the charge level from the
  /// last sample in each hour — a level is not summed.
  List<EnergyHistoryPoint> _hourly(EnergyHistoryData d) {
    // Cleared per call: paint runs on every frame that touches this widget, and
    // an accumulating list would both grow without bound and slide the charge
    // samples out of step with the bars after the first repaint.
    _hourSoc.clear();
    _hourForecastWh.clear();
    final out = <EnergyHistoryPoint>[];
    final soc = d.socPerBucket;
    final fc = d.forecastWh;
    final perHour = 3600 / d.bucket.inSeconds;
    var i = 0;
    while (i < d.points.length) {
      final hour = DateTime(d.points[i].time.year, d.points[i].time.month,
          d.points[i].time.day, d.points[i].time.hour);
      var pv = 0.0, dis = 0.0, imp = 0.0, exp = 0.0, chg = 0.0, load = 0.0;
      var n = 0;
      double? lastSoc;
      // A forecast is energy, so it SUMS across the hour — unlike the charge
      // level beside it, which is carried.
      int? fcSum;
      while (i < d.points.length) {
        final p = d.points[i];
        final h = DateTime(p.time.year, p.time.month, p.time.day, p.time.hour);
        if (h != hour) break;
        pv += p.pvW; dis += p.batteryDischargeW; imp += p.gridImportW;
        exp += p.gridExportW; chg += p.batteryChargeW; load += p.loadW;
        if (i < soc.length && soc[i] != null) lastSoc = soc[i];
        if (i < fc.length && fc[i] != null) fcSum = (fcSum ?? 0) + fc[i]!;
        n++; i++;
      }
      if (n == 0) break;
      // Mean power over the hour: the painter turns W back into Wh with a
      // one-hour factor, so averaging here keeps the totals honest.
      out.add(EnergyHistoryPoint(
        time: hour,
        pvW: pv / n, gridImportW: imp / n, gridExportW: exp / n,
        loadW: load / n, batteryChargeW: chg / n, batteryDischargeW: dis / n,
      ));
      _hourSoc.add(lastSoc);
      _hourForecastWh.add(fcSum);
      if (n < perHour && i >= d.points.length) break;   // partial trailing hour
    }
    return out;
  }

  /// Charge level per aggregated hour, filled by [_hourly] alongside its result.
  final List<double?> _hourSoc = [];

  /// Forecast Wh per aggregated hour, filled by [_hourly] the same way.
  final List<int?> _hourForecastWh = [];

  /// The live forecast summed into calendar hours.
  ///
  /// The forecast's own interval is whatever the controller chose — 15 minutes at
  /// the time of writing — while this chart's y axis is kWh **per hour**. Plotting
  /// a raw interval value against it drew the forecast at a quarter of its size,
  /// so a day predicted at 41.9 kWh appeared as a curve worth about 10, sitting
  /// far below the bars it was supposed to be predicting. Summing to the hour puts
  /// prediction and measurement in the same unit, which is the only way the two
  /// can be compared at all.
  Map<DateTime, double> _forecastByHour() {
    final out = <DateTime, double>{};
    final f = solar;
    if (f == null || f.isEmpty) return out;
    for (var k = 0; k < f.wattHours.length; k++) {
      final h = _hourFloor(f.timeAt(k));
      out[h] = (out[h] ?? 0) + f.wattHours[k] / 1000.0;
    }
    return out;
  }

  /// Draws one segment as dashes. Flutter has no dashed stroke, and a dashed
  /// path built once would have to be rebuilt on every layout change anyway.
  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final step = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(a + step * t, a + step * end, paint);
      t = end + gap;
    }
  }

  void _tinyLabel(Canvas canvas, String text, Offset at, Color color,
      {bool rightAlign = false, FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          color: color, fontSize: 8.5, fontWeight: weight,
          fontFamily: 'monospace', letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rightAlign ? at.translate(-tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.data != data || old.prices != prices || old.solar != solar ||
      old.selectedTime != selectedTime || old.shown != shown ||
      old.batteryKwh != batteryKwh ||
      old.archivedForecast != archivedForecast;
}

/// Rounds a raw step up to 1/2/5 × a power of ten so gridline labels read as
/// numbers a person would choose.
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  var mag = 1.0;
  while (mag * 10 <= raw) { mag *= 10; }
  while (mag > raw) { mag /= 10; }
  for (final m in [1.0, 2.0, 5.0]) {
    if (mag * m >= raw) return mag * m;
  }
  return mag * 10;
}
