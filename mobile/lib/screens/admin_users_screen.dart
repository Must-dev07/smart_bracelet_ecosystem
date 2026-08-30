// Admin-only: every account on the platform (GET /users/), searchable by
// name/email, with a role badge. Read-only here — role changes / account
// deactivation are an admin.py / future workflow, not exposed via this API.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common_widgets.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
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
            child: users.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list
                        .where((u) =>
                            u.fullName.toLowerCase().contains(_query) ||
                            u.email.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching users.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(allUsersProvider),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(_initial(u))),
                        title: Text(u.fullName.isEmpty ? u.email : u.fullName),
                        subtitle: Text(u.email),
                        trailing: _RoleBadge(role: u.role),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                message: 'Could not load users: $e',
                onRetry: () => ref.invalidate(allUsersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initial(User u) =>
      u.firstName.isNotEmpty ? u.firstName[0].toUpperCase() : u.email[0].toUpperCase();
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'admin' => Colors.purple,
      'doctor' => Colors.blue,
      _ => Colors.teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(role,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
