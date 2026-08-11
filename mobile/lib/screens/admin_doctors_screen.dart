/// Admin: doctor directory (GET /doctors/) with specialty/license, searchable,
/// showing how many patients each doctor currently has (cross-referenced
/// against the babies list — admin-scoped to every baby on the platform).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class AdminDoctorsScreen extends ConsumerStatefulWidget {
  const AdminDoctorsScreen({super.key});
  @override
  ConsumerState<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends ConsumerState<AdminDoctorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsDirectoryProvider);
    final babies = ref.watch(babiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Doctors')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or specialty',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: doctors.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((d) =>
                            d.fullName.toLowerCase().contains(_query) ||
                            d.specialty.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching doctors.'));
                }
                final patientCounts = babies.value == null
                    ? const <int, int>{}
                    : <int, int>{
                        for (final d in list)
                          d.id: babies.value!
                              .where((b) => b.assignedDoctor == d.id)
                              .length,
                      };
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(doctorsDirectoryProvider);
                    ref.invalidate(babiesProvider);
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.medical_services_outlined)),
                        title: Text('Dr. ${d.fullName}'),
                        subtitle: Text(
                          [
                            if (d.specialty.isNotEmpty) d.specialty,
                            'License ${d.licenseNumber}',
                          ].join(' · '),
                        ),
                        trailing: Chip(
                          label: Text('${patientCounts[d.id] ?? 0} patients'),
                          visualDensity: VisualDensity.compact,
                        ),
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
                    Text('Could not load doctors: $e'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(doctorsDirectoryProvider),
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
