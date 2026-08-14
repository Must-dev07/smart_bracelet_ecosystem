/// Shared widgets: disclaimer banner (Section 0 rule 10), vital tile,
/// connection status chip, severity badge, error-with-retry state.
import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../services/vitals_source.dart';

/// Standard "failed to load, here's why, try again" state — used by every
/// list screen backed by an AsyncValue.error branch (the admin directories,
/// bracelets, etc). Centralised so the retry affordance can't silently go
/// missing from one screen the way it originally did on all five of these
/// before this widget existed (Section 20 UI consistency).
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-diagnostic disclaimer — shown on onboarding and every alert screen.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppConfig.medicalDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class VitalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color? color;

  const VitalTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color ?? AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionStatusChip extends StatelessWidget {
  final BleStatus status;
  const ConnectionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      BleStatus.connected => ('Connected', AppColors.accent, Icons.bluetooth_connected),
      BleStatus.connecting => ('Connecting…', AppColors.info, Icons.bluetooth_searching),
      BleStatus.scanning => ('Scanning…', AppColors.info, Icons.search),
      BleStatus.reconnecting => ('Reconnecting…', AppColors.warning, Icons.sync),
      BleStatus.disconnected => ('Disconnected', AppColors.critical, Icons.bluetooth_disabled),
    };
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final String severity;
  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.severityColor(severity),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
