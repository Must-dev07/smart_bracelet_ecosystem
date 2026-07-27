/// Profile screen: shows the logged-in user (parent or doctor) — the single
/// screen covers both "Doctor Profile" and "Parent Profile" from the spec,
/// branching on role.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
          title: Text(user?.role == 'doctor' ? 'Doctor profile' : 'Parent profile')),
      body: user == null
          ? const Center(child: Text('Not signed in.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 42,
                    child: Text(
                      user.firstName.isNotEmpty
                          ? user.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(children: [
                    ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Name'),
                        subtitle: Text(user.fullName)),
                    ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(user.email)),
                    ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Role'),
                        subtitle: Text(user.role)),
                  ]),
                ),
              ],
            ),
    );
  }
}
