// Medical history for the currently selected baby (Section 4). Entries are
// append-only: doctors/admins can add new entries, nobody can edit or
// delete a previous one — corrections are made by adding a fresh entry.
// Parents (and doctors) always see the full read-only timeline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class MedicalHistoryScreen extends ConsumerStatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  ConsumerState<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  bool _saving = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit(int babyId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(babyRepositoryProvider).addMedicalHistoryEntry(
            babyId,
            title: _title.text.trim(),
            details: _details.text.trim(),
          );
      _title.clear();
      _details.clear();
      ref.invalidate(medicalHistoryProvider(babyId));
    } catch (e) {
      setState(() => _error = 'Could not save entry: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(selectedBabyProvider);
    final role = ref.watch(authProvider).user?.role;
    final canAppend = role == 'doctor' || role == 'admin';

    if (baby == null) {
      return const Scaffold(
        body: Center(child: Text('No baby selected.')),
      );
    }

    final entries = ref.watch(medicalHistoryProvider(baby.id));

    return Scaffold(
      appBar: AppBar(title: Text('${baby.name} — Medical history')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(medicalHistoryProvider(baby.id)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search entries',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            entries.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((e) =>
                            e.title.toLowerCase().contains(_query) ||
                            e.details.toLowerCase().contains(_query))
                        .toList();
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No history entries yet.')),
                  );
                }
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No entries match your search.')),
                  );
                }
                return Column(
                  children: [
                    for (final e in filtered) _HistoryTile(entry: e),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Could not load history: $err')),
              ),
            ),
            if (canAppend) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('Add entry', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Vaccination — Hep B',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _details,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _submit(baby.id),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_saving ? 'Saving…' : 'Save entry'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final MedicalHistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (entry.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.details),
            ],
            const SizedBox(height: 6),
            Text(
              entry.createdAt.toLocal().toString().split('.').first,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
