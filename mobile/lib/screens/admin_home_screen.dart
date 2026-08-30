// Admin dashboard: platform-wide counters (users, doctors, parents, babies,
// bracelets, active alerts) as tappable stat cards that open the matching
// directory screen. All the underlying endpoints are already scoped to
// "everything" for an admin (see babies/bracelets/alerts backend querysets),
// so this screen just needs to fetch and summarise them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/providers.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider);
    final doctors = ref.watch(doctorsDirectoryProvider);
    final parents = ref.watch(parentsDirectoryProvider);
    final babies = ref.watch(babiesProvider);
    final bracelets = ref.watch(braceletsProvider);
    final activeAlerts = ref.watch(alertsProvider('active'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allUsersProvider);
          ref.invalidate(doctorsDirectoryProvider);
          ref.invalidate(parentsDirectoryProvider);
          ref.invalidate(babiesProvider);
          ref.invalidate(braceletsProvider);
          ref.invalidate(alertsProvider);
        },
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              icon: Icons.people_alt_outlined,
              label: 'Users',
              async: users,
              count: (l) => l.length,
              onTap: () => Navigator.of(context).pushNamed('/admin-users'),
            ),
            _StatCard(
              icon: Icons.medical_services_outlined,
              label: 'Doctors',
              async: doctors,
              count: (l) => l.length,
              onTap: () => Navigator.of(context).pushNamed('/admin-doctors'),
            ),
            _StatCard(
              icon: Icons.family_restroom_outlined,
              label: 'Parents',
              async: parents,
              count: (l) => l.length,
              onTap: () => Navigator.of(context).pushNamed('/admin-parents'),
            ),
            _StatCard(
              icon: Icons.child_care_outlined,
              label: 'Babies',
              async: babies,
              count: (l) => l.length,
              onTap: () => Navigator.of(context).pushNamed('/admin-babies'),
            ),
            _StatCard(
              icon: Icons.watch_outlined,
              label: 'Bracelets',
              async: bracelets,
              count: (l) => l.length,
              onTap: () => Navigator.of(context).pushNamed('/admin-bracelets'),
            ),
            _StatCard(
              icon: Icons.warning_amber_outlined,
              label: 'Active alerts',
              async: activeAlerts,
              count: (l) => l.length,
              highlight: true,
              onTap: () => Navigator.of(context).pushNamed('/alerts'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final AsyncValue<List<T>> async;
  final int Function(List<T>) count;
  final VoidCallback onTap;
  final bool highlight;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.async,
    required this.count,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = async.when(
      data: (l) => '${count(l)}',
      loading: () => '…',
      error: (_, __) => '—',
    );
    final isAlert = highlight && async.value != null && count(async.value!) > 0;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon,
                  size: 28,
                  color: isAlert ? AppColors.critical : AppColors.primary),
              const Spacer(),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
