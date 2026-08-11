/// Doctor dashboard: patients assigned to this doctor (server-scoped — the
/// backend's `/babies/` already filters to `assigned_doctor__user=me`, so
/// this screen never needs to know that filtering itself), active alerts
/// summary, and quick access to alerts/notifications/profile/settings.
/// Doctors never see other doctors' patients, and never see the "Add baby"
/// action that belongs to the parent home screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common_widgets.dart';

class DoctorHomeScreen extends ConsumerWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(babiesProvider);
    final activeAlerts = ref.watch(alertsProvider('active'));
    final pendingRequests = ref.watch(doctorRequestInboxProvider('pending'));
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(babiesProvider);
          ref.invalidate(alertsProvider);
          ref.invalidate(doctorRequestInboxProvider('pending'));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null)
              Text('Welcome back, Dr. ${user.lastName.isEmpty ? user.firstName : user.lastName}',
                  style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                patients.when(
                  data: (list) => Chip(
                    avatar: const Icon(Icons.people_outline, size: 18),
                    label: Text('${list.length} patient(s)'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                activeAlerts.when(
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
                pendingRequests.when(
                  data: (list) => list.isEmpty
                      ? const SizedBox.shrink()
                      : ActionChip(
                          avatar: const Icon(Icons.hourglass_top,
                              size: 18, color: Colors.orange),
                          label: Text('${list.length} pending request(s)'),
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/doctor-requests'),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            patients.when(
              data: (list) => list.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 64),
                            SizedBox(height: 12),
                            Text('No patients assigned to you yet.'),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final baby in list) _PatientCard(baby: baby),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('Could not load patients'),
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
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final Baby baby;
  const _PatientCard({required this.baby});

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
            'Born ${baby.birthDate.toLocal().toString().split(' ').first}'
            '${baby.parentName != null && baby.parentName!.isNotEmpty ? ' · parent: ${baby.parentName}' : ''}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(selectedBabyProvider.notifier).state = baby;
          Navigator.of(context).pushNamed('/baby-details');
        },
      ),
    );
  }
}
