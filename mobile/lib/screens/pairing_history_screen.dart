/// History of every pair/unpair cycle for the selected bracelet (Section 5).
/// Backend-scoped: parent sees their own bracelets, doctor sees their
/// patients', admin sees everything.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class PairingHistoryScreen extends ConsumerWidget {
  const PairingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracelet = ref.watch(selectedBraceletProvider);
    if (bracelet == null) {
      return const Scaffold(body: Center(child: Text('No bracelet selected.')));
    }
    final history = ref.watch(pairingHistoryProvider(bracelet.id));

    return Scaffold(
      appBar: AppBar(title: Text('${bracelet.displayName} — pairing history')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pairingHistoryProvider(bracelet.id)),
        child: history.when(
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: Text('Never paired.')),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: Icon(
                        p.isActive ? Icons.link : Icons.link_off,
                        color: p.isActive ? Colors.green : Colors.grey,
                      ),
                      title: Text(p.babyName.isEmpty ? 'Baby #${p.babyId}' : p.babyName),
                      subtitle: Text(
                        'Paired ${p.pairedAt.toLocal().toString().split('.').first}'
                        '${p.unpairedAt != null ? '\nUnpaired ${p.unpairedAt!.toLocal().toString().split('.').first}' : ''}',
                      ),
                      trailing: p.isActive ? const Chip(label: Text('Active')) : null,
                      isThreeLine: p.unpairedAt != null,
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load history: $e')),
        ),
      ),
    );
  }
}
