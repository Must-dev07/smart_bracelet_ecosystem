/// Alert detail: full message, triggering value, acknowledge action and the
/// mandatory non-diagnostic disclaimer. Deep-link target for push taps.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/l10n.dart';
import '../widgets/common_widgets.dart';

class AlertDetailScreen extends ConsumerStatefulWidget {
  const AlertDetailScreen({super.key});
  @override
  ConsumerState<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends ConsumerState<AlertDetailScreen> {
  Alert? _alert;
  bool _loading = true;
  bool _acking = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final id = ModalRoute.of(context)!.settings.arguments as int?;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'No alert specified.';
      });
      return;
    }
    try {
      final alert = await ref.read(alertRepositoryProvider).detail(id);
      setState(() => _alert = alert);
    } catch (_) {
      setState(() => _error = 'Could not load the alert (offline?).');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _acknowledge() async {
    if (_alert == null) return;
    setState(() => _acking = true);
    try {
      final updated =
          await ref.read(alertRepositoryProvider).acknowledge(_alert!.id);
      setState(() => _alert = updated);
      ref.invalidate(alertsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not acknowledge — retry.')));
      }
    } finally {
      setState(() => _acking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Alert details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        SeverityBadge(severity: _alert!.severity),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _alert!.type.replaceAll('_', ' ').toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_alert!.message,
                                style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 12),
                            if (_alert!.value != null)
                              Text('Reading: ${_alert!.value}'),
                            Text('Baby: ${_alert!.babyName}'),
                            Text(
                                'Triggered: ${_alert!.triggeredAt.toLocal().toString().split('.').first}'),
                            if (_alert!.resolvedAt != null)
                              Text(
                                  'Resolved: ${_alert!.resolvedAt!.toLocal().toString().split('.').first}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_alert!.isActive)
                      FilledButton.icon(
                        onPressed: _acking ? null : _acknowledge,
                        icon: const Icon(Icons.check),
                        label: Text(l.t('acknowledge')),
                      ),
                    const DisclaimerBanner(),
                  ],
                ),
    );
  }
}
