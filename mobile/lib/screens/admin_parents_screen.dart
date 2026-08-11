/// Admin: parent directory (GET /parents/) with contact info, searchable,
/// showing how many babies each parent has registered.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class AdminParentsScreen extends ConsumerStatefulWidget {
  const AdminParentsScreen({super.key});
  @override
  ConsumerState<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends ConsumerState<AdminParentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final parents = ref.watch(parentsDirectoryProvider);
    final babies = ref.watch(babiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Parents')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or email',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: parents.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((p) =>
                            p.fullName.toLowerCase().contains(_query) ||
                            p.email.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching parents.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(parentsDirectoryProvider);
                    ref.invalidate(babiesProvider);
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return ExpansionTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.family_restroom_outlined)),
                        title: Text(p.fullName.isEmpty ? p.email : p.fullName),
                        subtitle: Text(p.email),
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.phone_outlined),
                            title: Text(p.phone.isEmpty ? '—' : p.phone),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.home_outlined),
                            title: Text(p.address.isEmpty ? '—' : p.address),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.emergency_outlined),
                            title: Text(p.emergencyContact.isEmpty
                                ? 'No emergency contact on file'
                                : p.emergencyContact),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load parents: $e'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(parentsDirectoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
