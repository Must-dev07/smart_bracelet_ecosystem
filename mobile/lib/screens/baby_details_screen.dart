// Baby details: view the selected baby (any role), create a new one (parent
// role only — reached from the parent home screen's "Add baby" action), or
// edit/delete an existing one (parent/admin only — the backend rejects a
// doctor editing registration fields; doctors record clinical notes via
// medical history instead).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/units.dart';

class BabyDetailsScreen extends ConsumerStatefulWidget {
  const BabyDetailsScreen({super.key});
  @override
  ConsumerState<BabyDetailsScreen> createState() => _BabyDetailsScreenState();
}

class _BabyDetailsScreenState extends ConsumerState<BabyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _weight = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'unspecified';
  bool _saving = false;
  bool _editMode = false;

  void _startEdit(Baby baby) {
    _name.text = baby.name;
    _weight.text = baby.weightGrams.toString();
    _birthDate = baby.birthDate;
    _gender = baby.gender;
    setState(() => _editMode = true);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(babyRepositoryProvider).create({
        'name': _name.text.trim(),
        'birth_date': _birthDate!.toIso8601String().split('T').first,
        'weight_grams': int.parse(_weight.text),
        'gender': _gender,
      });
      ref.invalidate(babiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _update(int babyId) async {
    if (!_formKey.currentState!.validate() || _birthDate == null) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(babyRepositoryProvider).update(babyId, {
        'name': _name.text.trim(),
        'birth_date': _birthDate!.toIso8601String().split('T').first,
        'weight_grams': int.parse(_weight.text),
        'gender': _gender,
      });
      ref.invalidate(babiesProvider);
      ref.read(selectedBabyProvider.notifier).state = updated;
      if (mounted) setState(() => _editMode = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Baby baby) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete baby?'),
        content: Text(
            'This permanently deletes ${baby.name}\'s profile, including its '
            'measurement and alert history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(babyRepositoryProvider).delete(baby.id);
      ref.invalidate(babiesProvider);
      ref.read(selectedBabyProvider.notifier).state = null;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(selectedBabyProvider);
    final role = ref.watch(authProvider).user?.role;
    final canManage = role == 'parent' || role == 'admin';

    if (baby != null && !_editMode) {
      // ------- View mode -------
      return Scaffold(
        appBar: AppBar(
          title: Text(baby.name),
          actions: canManage
              ? [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _startEdit(baby),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(baby),
                  ),
                ]
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Birth date'),
                    subtitle: Text(
                        baby.birthDate.toLocal().toString().split(' ').first)),
                ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: const Text('Weight'),
                    subtitle: Text(formatWeight(
                        baby.weightGrams, ref.watch(unitsProvider)))),
                ListTile(
                    leading: const Icon(Icons.wc_outlined),
                    title: const Text('Gender'),
                    subtitle: Text(baby.gender)),
              ]),
            ),
            const SizedBox(height: 16),
            _DoctorAssignmentSection(baby: baby),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/live'),
                icon: const Icon(Icons.monitor_heart),
                label: const Text('Live monitoring'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/graphs'),
                icon: const Icon(Icons.show_chart),
                label: const Text('Graphs'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/history'),
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/medical-history'),
                icon: const Icon(Icons.medical_information_outlined),
                label: const Text('Medical history'),
              ),
            ]),
          ],
        ),
      );
    }

    // ------- Create or Edit mode (same form; Edit is pre-filled) -------
    return Scaffold(
      appBar: AppBar(
        title: Text(_editMode ? 'Edit baby' : 'Add baby'),
        leading: _editMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _editMode = false),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Weight (grams)', helperText: '300–8000 g'),
                validator: (v) {
                  final g = int.tryParse(v ?? '');
                  return (g != null && g >= 300 && g <= 8000)
                      ? null
                      : 'Enter 300–8000';
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12)),
                title: Text(_birthDate == null
                    ? 'Birth date'
                    : _birthDate!.toIso8601String().split('T').first),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(
                      value: 'unspecified', child: Text('Unspecified')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving
                    ? null
                    : (_editMode ? () => _update(baby!.id) : _create),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the baby's current doctor assignment plus role-appropriate actions:
/// - Parent: request a doctor / request a change; see + cancel a pending request.
/// - Doctor: if it's their own assignment, remove themselves.
/// - Admin: assign/change/remove directly (bypasses the request flow).
class _DoctorAssignmentSection extends ConsumerWidget {
  final Baby baby;
  const _DoctorAssignmentSection({required this.baby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    final doctors = ref.watch(doctorsDirectoryProvider);
    final pendingRequests = ref.watch(doctorRequestsForBabyProvider(baby.id));

    DoctorProfile? assignedDoctor;
    if (baby.assignedDoctor != null && doctors.hasValue) {
      for (final d in doctors.value!) {
        if (d.id == baby.assignedDoctor) {
          assignedDoctor = d;
          break;
        }
      }
    }

    DoctorAssignmentRequest? pending;
    if (pendingRequests.hasValue) {
      for (final r in pendingRequests.value!) {
        if (r.isPending) {
          pending = r;
          break;
        }
      }
    }

    Future<void> clearDoctor() async {
      await ref.read(babyRepositoryProvider).setAssignedDoctor(baby.id, null);
      ref.invalidate(babiesProvider);
      ref.read(selectedBabyProvider.notifier).state =
          baby.copyWith(clearAssignedDoctor: true);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined),
                const SizedBox(width: 8),
                Text('Doctor', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (assignedDoctor != null)
              Text('Dr. ${assignedDoctor.fullName}'
                  '${assignedDoctor.specialty.isNotEmpty ? ' · ${assignedDoctor.specialty}' : ''}')
            else
              const Text('No doctor assigned yet.'),
            if (pending != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.hourglass_top, size: 16),
                label: Text('Request pending: Dr. ${pending.doctorName}'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              if (role == 'parent' && pending == null)
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/request-doctor'),
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(assignedDoctor == null
                      ? 'Request a doctor'
                      : 'Request a different doctor'),
                ),
              if (role == 'parent' && pending != null)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(doctorAssignmentRepositoryProvider)
                        .cancel(pending!.id);
                    ref.invalidate(doctorRequestsForBabyProvider(baby.id));
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel request'),
                ),
              if (role == 'doctor' &&
                  assignedDoctor != null &&
                  ref.watch(authProvider).user?.doctorProfileId ==
                      assignedDoctor.id)
                OutlinedButton.icon(
                  onPressed: clearDoctor,
                  icon: const Icon(Icons.person_remove_alt_1),
                  label: const Text('Remove myself from this patient'),
                ),
              if (role == 'admin')
                OutlinedButton.icon(
                  onPressed: () => _showAdminAssignSheet(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                      assignedDoctor == null ? 'Assign doctor' : 'Change doctor'),
                ),
              if (role == 'admin' && assignedDoctor != null)
                TextButton.icon(
                  onPressed: clearDoctor,
                  icon: const Icon(Icons.close),
                  label: const Text('Remove doctor'),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showAdminAssignSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Consumer(
              builder: (context, sheetRef, _) {
                final doctors = sheetRef.watch(doctorsDirectoryProvider);
                return doctors.when(
                  data: (list) => ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return ListTile(
                        leading: const Icon(Icons.medical_services_outlined),
                        title: Text('Dr. ${d.fullName}'),
                        subtitle: Text(
                            d.specialty.isEmpty ? 'General' : d.specialty),
                        onTap: () async {
                          await sheetRef
                              .read(babyRepositoryProvider)
                              .setAssignedDoctor(baby.id, d.id);
                          sheetRef.invalidate(babiesProvider);
                          sheetRef.read(selectedBabyProvider.notifier).state =
                              baby.copyWith(assignedDoctor: d.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
