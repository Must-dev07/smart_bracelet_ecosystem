/// Admin: every baby on the platform (GET /babies/, admin-scoped to all).
/// Read-only overview with search; tapping a row opens the same baby detail
/// view parents and doctors use (view mode only — admin doesn't get the
/// "Add baby" create form, that stays a parent-only action).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/common_widgets.dart';

class AdminBabiesScreen extends ConsumerStatefulWidget {
  const AdminBabiesScreen({super.key});
  @override
  ConsumerState<AdminBabiesScreen> createState() => _AdminBabiesScreenState();
}

class _AdminBabiesScreenState extends ConsumerState<AdminBabiesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final babies = ref.watch(babiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Babies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or parent',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: babies.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((b) =>
                            b.name.toLowerCase().contains(_query) ||
                            (b.parentName ?? '').toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching babies.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(babiesProvider),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(b.gender == 'male'
                              ? Icons.child_care
                              : Icons.child_friendly),
                        ),
                        title: Text(b.name),
                        subtitle: Text(
                          [
                            if (b.parentName != null && b.parentName!.isNotEmpty)
                              'Parent: ${b.parentName}',
                            b.assignedDoctor == null
                                ? 'No doctor assigned'
                                : 'Doctor assigned',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ref.read(selectedBabyProvider.notifier).state = b;
                          Navigator.of(context).pushNamed('/baby-details');
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                message: 'Could not load babies: $e',
                onRetry: () => ref.invalidate(babiesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
