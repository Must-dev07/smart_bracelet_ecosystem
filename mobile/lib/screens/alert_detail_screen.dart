// Alert detail: full message, triggering value, a lightweight audit trail
// (who acknowledged/resolved and when), acknowledge action (any role) and
// resolve action (doctor/admin only — see Alert.auto_resolves_on_acknowledge:
// vitals-based alerts stay open after a parent acknowledges them), plus the
// mandatory non-diagnostic disclaimer. Deep-link target for push taps.
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
  bool _resolving = false;
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
      if (mounted) setState(() => _acking = false);
    }
  }

  Future<void> _resolve() async {
    if (_alert == null) return;
    setState(() => _resolving = true);
    try {
      final updated = await ref.read(alertRepositoryProvider).resolve(_alert!.id);
      setState(() => _alert = updated);
      ref.invalidate(alertsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not resolve: $e')));
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final role = ref.watch(authProvider).user?.role;
    final canResolve = role == 'doctor' || role == 'admin';

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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ---- Audit trail (Section 8) ----
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Timeline',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            _TimelineRow(
                              icon: Icons.notifications_active_outlined,
                              label: 'Triggered',
                              time: _alert!.triggeredAt,
                            ),
                            _TimelineRow(
                              icon: Icons.visibility_outlined,
                              label: _alert!.acknowledgedByName != null
                                  ? 'Acknowledged by ${_alert!.acknowledgedByName}'
                                  : 'Not yet acknowledged',
                              time: _alert!.acknowledgedAt,
                              muted: _alert!.acknowledgedAt == null,
                            ),
                            _TimelineRow(
                              icon: Icons.check_circle_outline,
                              label: _alert!.resolvedByName != null
                                  ? 'Resolved by ${_alert!.resolvedByName}'
                                  : 'Not yet resolved',
                              time: _alert!.resolvedAt,
                              muted: _alert!.resolvedAt == null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      if (_alert!.acknowledgedAt == null)
                        FilledButton.icon(
                          onPressed: _acking ? null : _acknowledge,
                          icon: const Icon(Icons.check),
                          label: Text(l.t('acknowledge')),
                        ),
                      if (_alert!.isActive &&
                          canResolve &&
                          !_alert!.autoResolvesOnAcknowledge)
                        OutlinedButton.icon(
                          onPressed: _resolving ? null : _resolve,
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Resolve'),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    const DisclaimerBanner(),
                  ],
                ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? time;
  final bool muted;
  const _TimelineRow({
    required this.icon,
    required this.label,
    this.time,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? Colors.grey : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: color))),
          if (time != null)
            Text(
              time!.toLocal().toString().split('.').first,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
