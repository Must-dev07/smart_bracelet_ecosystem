/// Admin: every bracelet on the platform (GET /bracelets/, admin-scoped to
/// all), searchable by serial/nickname/baby, filterable by paired/unpaired
/// (Section 15). Tapping a row opens the same bracelet detail/pairing-
/// history screen parents and doctors use.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class AdminBraceletsScreen extends ConsumerStatefulWidget {
  const AdminBraceletsScreen({super.key});
  @override
  ConsumerState<AdminBraceletsScreen> createState() =>
      _AdminBraceletsScreenState();
}

class _AdminBraceletsScreenState extends ConsumerState<AdminBraceletsScreen> {
  String _query = '';
  bool? _pairedFilter; // null = all, true = paired, false = unpaired

  @override
  Widget build(BuildContext context) {
    final bracelets = ref.watch(braceletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bracelets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by serial, nickname, or baby',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _pairedFilter == null,
                  onSelected: (_) => setState(() => _pairedFilter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Paired'),
                  selected: _pairedFilter == true,
                  onSelected: (_) => setState(() => _pairedFilter = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Unpaired'),
                  selected: _pairedFilter == false,
                  onSelected: (_) => setState(() => _pairedFilter = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: bracelets.when(
              data: (list) {
                final filtered = list.where((b) {
                  if (_pairedFilter != null &&
                      (b.babyId != null) != _pairedFilter) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  return b.serialNumber.toLowerCase().contains(_query) ||
                      b.nickname.toLowerCase().contains(_query) ||
                      (b.babyName ?? '').toLowerCase().contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching bracelets.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(braceletsProvider),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: b.babyId != null
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                          child: Icon(Icons.watch_outlined,
                              color:
                                  b.babyId != null ? Colors.green : Colors.grey),
                        ),
                        title: Text(b.displayName),
                        subtitle: Text(
                          b.babyId != null
                              ? 'Paired with ${b.babyName ?? "baby #${b.babyId}"}'
                              : 'Unpaired',
                        ),
                        trailing: b.batteryLevel != null
                            ? Text('${b.batteryLevel!.round()}%')
                            : null,
                        onTap: () {
                          ref.read(selectedBraceletProvider.notifier).state = b;
                          Navigator.of(context).pushNamed('/bracelet-info');
                        },
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
                    Text('Could not load bracelets: $e'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(braceletsProvider),
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
