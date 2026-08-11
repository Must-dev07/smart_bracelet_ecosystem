/// Parent (or admin, on a parent's behalf) requests a doctor for the
/// currently selected baby. Submitting creates a pending
/// DoctorAssignmentRequest — the baby is NOT reassigned until the doctor
/// accepts. If a doctor is already assigned, this is "change doctor": the
/// existing assignment stays in place until the new request is accepted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class RequestDoctorScreen extends ConsumerStatefulWidget {
  const RequestDoctorScreen({super.key});
  @override
  ConsumerState<RequestDoctorScreen> createState() =>
      _RequestDoctorScreenState();
}

class _RequestDoctorScreenState extends ConsumerState<RequestDoctorScreen> {
  final _note = TextEditingController();
  int? _selectedDoctorId;
  bool _saving = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(int babyId) async {
    if (_selectedDoctorId == null) {
      setState(() => _error = 'Choose a doctor first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(doctorAssignmentRepositoryProvider).create(
            babyId,
            _selectedDoctorId!,
            note: _note.text.trim(),
          );
      ref.invalidate(doctorRequestsForBabyProvider(babyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request sent — waiting for the doctor to respond.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Could not send request: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(selectedBabyProvider);
    final doctors = ref.watch(doctorsDirectoryProvider);

    if (baby == null) {
      return const Scaffold(body: Center(child: Text('No baby selected.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Request a doctor for ${baby.name}')),
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
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    return RadioListTile<int>(
                      value: d.id,
                      groupValue: _selectedDoctorId,
                      onChanged: (v) => setState(() => _selectedDoctorId = v),
                      title: Text('Dr. ${d.fullName}'),
                      subtitle:
                          Text(d.specialty.isEmpty ? 'General' : d.specialty),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load doctors: $e')),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note to the doctor (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _submit(baby.id),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send request'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
