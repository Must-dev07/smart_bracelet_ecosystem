// Home dashboard: baby cards, latest vitals snapshot, active alerts count,
// BLE status, quick navigation. Bottom navigation shell for the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/vitals_source.dart';
import '../utils/l10n.dart';
import '../utils/units.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babies = ref.watch(babiesProvider);
    final alerts = ref.watch(alertsProvider('active'));
    final bleStatus = ref.watch(bleStatusProvider).value ?? BleStatus.disconnected;
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('home')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(babiesProvider);
          ref.invalidate(alertsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ConnectionStatusChip(status: bleStatus),
                alerts.when(
                  data: (list) => ActionChip(
                    avatar: Icon(Icons.warning_amber,
                        size: 18,
                        color: list.isEmpty ? Colors.green : Colors.red),
                    label: Text('${list.length} active alert(s)'),
                    onPressed: () => Navigator.of(context).pushNamed('/alerts'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            babies.when(
              data: (list) => list.isEmpty
                  ? _EmptyBabies(l: l)
                  : Column(
                      children: [
                        for (final baby in list) _BabyCard(baby: baby),
                      ],
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('Could not load data'),
                  subtitle: const Text(
                      'You are offline — local monitoring still works.'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(babiesProvider),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const DisclaimerBanner(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(selectedBabyProvider.notifier).state = null;
          Navigator.of(context).pushNamed('/baby-details');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add baby'),
      ),
    );
  }
}

class _BabyCard extends ConsumerWidget {
  final Baby baby;
  const _BabyCard({required this.baby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          child: Icon(
              baby.gender == 'male' ? Icons.child_care : Icons.child_friendly),
        ),
        title: Text(baby.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Born ${baby.birthDate.toLocal().toString().split(' ').first} · '
            '${formatWeight(baby.weightGrams, ref.watch(unitsProvider))}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(selectedBabyProvider.notifier).state = baby;
          Navigator.of(context).pushNamed('/baby-details');
        },
      ),
    );
  }
}

class _EmptyBabies extends ConsumerWidget {
  final L10n l;
  const _EmptyBabies({required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.child_care, size: 64),
            const SizedBox(height: 12),
            const Text('No baby registered yet.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ref.read(selectedBabyProvider.notifier).state = null;
                Navigator.of(context).pushNamed('/baby-details');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add your baby'),
            ),
          ],
        ),
      ),
    );
  }
}
