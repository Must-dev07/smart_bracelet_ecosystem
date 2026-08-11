/// Graphs (Section 16): fl_chart time-series for HR / temperature / SpO2 /
/// battery / movement, daily/weekly/monthly presets plus a custom date
/// range, pinch-to-zoom/pan (InteractiveViewer), and tap tooltips.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/providers.dart';
import '../utils/l10n.dart';

class GraphsScreen extends ConsumerStatefulWidget {
  const GraphsScreen({super.key});
  @override
  ConsumerState<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends ConsumerState<GraphsScreen> {
  String _range = '24h'; // 6h | 24h | 7d | 30d | custom
  DateTimeRange? _customRange;
  String _metric = 'heart_rate_avg';
  List<Map<String, dynamic>> _buckets = [];
  bool _loading = false;
  String? _error;

  static const _presetRanges = {'6h': 6, '24h': 24, '7d': 168, '30d': 720};
  static const _metrics = {
    'heart_rate_avg': ('Heart rate', 'bpm', AppColors.critical),
    'temperature_avg': ('Temperature', '°C', AppColors.warning),
    'spo2_avg': ('SpO₂', '%', AppColors.info),
    'battery_avg': ('Battery', '%', AppColors.accent),
    'movement_magnitude_avg': ('Movement', 'g', AppColors.primary),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final baby = ref.read(selectedBabyProvider);
    if (baby == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DateTime from;
      final DateTime? to;
      if (_range == 'custom' && _customRange != null) {
        from = _customRange!.start;
        to = _customRange!.end;
      } else {
        final hours = _presetRanges[_range] ?? 24;
        from = DateTime.now().subtract(Duration(hours: hours));
        to = null;
      }
      final spanHours = (to ?? DateTime.now()).difference(from).inHours;
      final granularity =
          spanHours <= 24 ? 'minute' : (spanHours <= 168 ? 'hour' : 'day');
      final buckets = await ref.read(measurementRepositoryProvider).aggregated(
            baby.id,
            granularity: granularity,
            from: from,
            to: to,
          );
      setState(() => _buckets = buckets);
    } catch (e) {
      setState(() => _error = 'Could not load data (offline?).');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 92)),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() {
        _range = 'custom';
        _customRange = picked;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(selectedBabyProvider);
    final l = L10n.of(context);
    final (label, unit, color) = _metrics[_metric]!;

    final spots = <FlSpot>[];
    for (var i = 0; i < _buckets.length; i++) {
      final v = _buckets[i][_metric];
      if (v != null) spots.add(FlSpot(i.toDouble(), (v as num).toDouble()));
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(baby == null ? l.t('graphs') : '${l.t('graphs')} — ${baby.name}')),
      body: baby == null
          ? const Center(child: Text('Select a baby first.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<String>(
                            segments: [
                              for (final r in _presetRanges.keys)
                                ButtonSegment(value: r, label: Text(r)),
                              const ButtonSegment(
                                  value: 'custom', label: Text('Custom')),
                            ],
                            selected: {_range},
                            onSelectionChanged: (s) {
                              if (s.first == 'custom') {
                                _pickCustomRange();
                              } else {
                                setState(() => _range = s.first);
                                _load();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_range == 'custom' && _customRange != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_customRange!.start.toLocal().toString().split(' ').first} '
                        '→ ${_customRange!.end.toLocal().toString().split(' ').first}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: [
                        for (final e in _metrics.entries)
                          ButtonSegment(value: e.key, label: Text(e.value.$1)),
                      ],
                      selected: {_metric},
                      onSelectionChanged: (s) => setState(() => _metric = s.first),
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!))
                          : spots.isEmpty
                              ? const Center(
                                  child: Text('No data in this range yet.'))
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  // Pinch/pan to zoom (Section 16 "Zoom") —
                                  // fl_chart has no built-in zoom, so the
                                  // whole chart is wrapped instead.
                                  child: InteractiveViewer(
                                    minScale: 1,
                                    maxScale: 6,
                                    child: LineChart(
                                      LineChartData(
                                        titlesData: FlTitlesData(
                                          topTitles: const AxisTitles(),
                                          rightTitles: const AxisTitles(),
                                          bottomTitles: const AxisTitles(),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 44),
                                          ),
                                        ),
                                        lineTouchData: LineTouchData(
                                          touchTooltipData: LineTouchTooltipData(
                                            getTooltipItems: (spots) => spots
                                                .map((s) => LineTooltipItem(
                                                      '${s.y.toStringAsFixed(1)} $unit',
                                                      const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: spots,
                                            isCurved: true,
                                            color: color,
                                            dotData: const FlDotData(show: false),
                                            belowBarData: BarAreaData(
                                                show: true,
                                                color: color.withOpacity(.15)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('$label ($unit) — pinch to zoom, tap for values',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
    );
  }
}
