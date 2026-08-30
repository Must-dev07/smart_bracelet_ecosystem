// Profile screen, covering Section 10 for every role: parents can edit
// address/emergency contact, doctors can edit specialty, and everyone can
// edit their own name/phone. Doctor and parent role-specific fields live on
// the Doctor/Parent model, so editing them goes through
// PATCH /doctors/{id}/ or /parents/{id}/ (self-or-admin permitted); the
// doctor/parent's own id is discovered from /me/'s doctor_profile_id /
// parent_profile_id (see UserSummarySerializer) rather than the admin-only
// list endpoints.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _specialty = TextEditingController();
  final _address = TextEditingController();
  final _emergencyContact = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  String? _error;
  bool _initialised = false;
  String _loadedSpecialty = '';

  void _loadFrom(User user) {
    if (_initialised) return;
    _firstName.text = user.firstName;
    _lastName.text = user.lastName;
    _phone.text = user.phone;
    _initialised = true;
  }

  void _loadSpecialtyIfNeeded(DoctorProfile? mine) {
    if (mine == null || _loadedSpecialty.isNotEmpty) return;
    _loadedSpecialty = mine.specialty;
    _specialty.text = mine.specialty;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _specialty.dispose();
    _address.dispose();
    _emergencyContact.dispose();
    super.dispose();
  }

  Future<void> _save(User user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      if (user.role == 'doctor' && user.doctorProfileId != null) {
        await repo.updateDoctor(
          user.doctorProfileId!,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          specialty: _specialty.text.trim(),
        );
      } else if (user.role == 'parent' && user.parentProfileId != null) {
        await repo.updateParent(
          user.parentProfileId!,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          emergencyContact: _emergencyContact.text.trim(),
        );
      } else {
        await repo.updateMe(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
        );
      }
      // Refresh cached session user (name/phone shown elsewhere in the app)
      // and the doctor directory (specialty shown there too).
      await ref.read(authProvider.notifier).refreshFromServer();
      ref.invalidate(doctorsDirectoryProvider);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }
    _loadFrom(user);

    // Doctor-only: the directory is the only readable source for this
    // doctor's own specialty/license (the endpoint is open to any
    // authenticated user, unlike /parents/ which is admin-only).
    DoctorProfile? mine;
    if (user.role == 'doctor') {
      final doctors = ref.watch(doctorsDirectoryProvider);
      if (doctors.hasValue) {
        for (final d in doctors.value!) {
          if (d.userId == user.id) {
            mine = d;
            break;
          }
        }
        _loadSpecialtyIfNeeded(mine);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (user.role) {
          'doctor' => 'Doctor profile',
          'admin' => 'Admin profile',
          _ => 'Parent profile',
        }),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              label: Text(user.role.toUpperCase()),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
          if (!_editing)
            _ReadOnlyView(
              user: user,
              specialty: _loadedSpecialty,
              licenseNumber: mine?.licenseNumber ?? '',
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  if (user.role == 'doctor') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specialty,
                      decoration: const InputDecoration(labelText: 'Specialty'),
                    ),
                  ],
                  if (user.role == 'parent') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emergencyContact,
                      decoration:
                          const InputDecoration(labelText: 'Emergency contact'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _editing = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : () => _save(user),
                          child: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyView extends StatelessWidget {
  final User user;
  final String specialty;
  final String licenseNumber;
  const _ReadOnlyView({
    required this.user,
    required this.specialty,
    required this.licenseNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Name'),
          subtitle: Text(user.fullName),
        ),
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Email'),
          subtitle: Text(user.email),
        ),
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: const Text('Phone'),
          subtitle: Text(user.phone.isEmpty ? '—' : user.phone),
        ),
        if (user.role == 'doctor') ...[
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: const Text('Specialty'),
            subtitle: Text(specialty.isEmpty ? '—' : specialty),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('License number'),
            subtitle: Text(licenseNumber.isEmpty ? '—' : licenseNumber),
          ),
        ],
      ]),
    );
  }
}
