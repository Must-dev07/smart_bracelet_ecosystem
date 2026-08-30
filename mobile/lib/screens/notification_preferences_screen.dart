// Notification preferences (Section 11): mute bracelet/medical/system
// notifications per-category. Vitals/device alerts are never mutable here
// — they're safety-relevant, so the toggle is shown disabled with an
// explanation rather than just omitted (omitting it would look like a bug,
// not a deliberate safety choice).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  final Set<String> _saving = {};

  Future<void> _toggle(String category, bool value) async {
    setState(() => _saving.add(category));
    try {
      await ref
          .read(notificationRepositoryProvider)
          .updatePreference(category, value);
      ref.invalidate(notificationPreferencesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(category));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: prefs.when(
        data: (p) => ListView(
          children: [
            const ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Alerts'),
              subtitle: Text(
                  'Vitals & device alerts are always delivered — this cannot be turned off.'),
              trailing: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.watch_outlined),
              title: const Text('Bracelet'),
              subtitle: const Text('Pairing, unpairing, and connection events'),
              value: p['bracelet'] ?? true,
              onChanged: _saving.contains('bracelet')
                  ? null
                  : (v) => _toggle('bracelet', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.medical_services_outlined),
              title: const Text('Medical'),
              subtitle: const Text('Doctor requests, acceptances, declines'),
              value: p['medical'] ?? true,
              onChanged: _saving.contains('medical')
                  ? null
                  : (v) => _toggle('medical', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.info_outline),
              title: const Text('System'),
              subtitle: const Text('Account and welcome messages'),
              value: p['system'] ?? true,
              onChanged: _saving.contains('system')
                  ? null
                  : (v) => _toggle('system', v),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load preferences: $e')),
      ),
    );
  }
}
