/// Graphs: fl_chart time-series of HR / temp / SpO2 with range selector,
/// fed by the aggregated measurements endpoint.
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
  String _range = '24h';
  String _metric = 'heart_rate_avg';
  List<Map<String, dynamic>> _buckets = [];
  bool _loading = false;
  String? _error;

  static const _ranges = {'6h': 6, '24h': 24, '7d': 168, '30d': 720};
  static const _metrics = {
    'heart_rate_avg': ('Heart rate', 'bpm', AppColors.critical),
    'temperature_avg': ('Temperature', '°C', AppColors.warning),
    'spo2_avg': ('SpO₂', '%', AppColors.info),
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
      final hours = _ranges[_range]!;
      final granularity = hours <= 24 ? 'minute' : (hours <= 168 ? 'hour' : 'day');
      final buckets = await ref.read(measurementRepositoryProvider).aggregated(
            baby.id,
            granularity: granularity,
            from: DateTime.now().subtract(Duration(hours: hours)),
          );
      setState(() => _buckets = buckets);
    } catch (e) {
      setState(() => _error = 'Could not load data (offline?).');
    } finally {
      setState(() => _loading = false);
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
                      SegmentedButton<String>(
                        segments: [
                          for (final r in _ranges.keys)
                            ButtonSegment(value: r, label: Text(r)),
                        ],
                        selected: {_range},
                        onSelectionChanged: (s) {
                          setState(() => _range = s.first);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedButton<String>(
                    segments: [
                      for (final e in _metrics.entries)
                        ButtonSegment(value: e.key, label: Text(e.value.$1)),
                    ],
                    selected: {_metric},
                    onSelectionChanged: (s) => setState(() => _metric = s.first),
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
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('$label ($unit)',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
    );
  }
}
