/// Doctor's inbox of pending patient (doctor-assignment) requests. Accepting
/// assigns the baby to this doctor server-side; declining just closes the
/// request. Both are one-shot actions — the backend rejects a second
/// response to an already-resolved request.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class DoctorRequestsScreen extends ConsumerStatefulWidget {
  const DoctorRequestsScreen({super.key});
  @override
  ConsumerState<DoctorRequestsScreen> createState() =>
      _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends ConsumerState<DoctorRequestsScreen> {
  final _busy = <int>{};

  Future<void> _respond(DoctorAssignmentRequest req, bool accept) async {
    setState(() => _busy.add(req.id));
    try {
      final repo = ref.read(doctorAssignmentRepositoryProvider);
      if (accept) {
        await repo.accept(req.id);
      } else {
        await repo.decline(req.id);
      }
      ref.invalidate(doctorRequestInboxProvider('pending'));
      ref.invalidate(babiesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? 'Accepted — ${req.babyName} added to your patients.'
              : 'Request declined.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not respond: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(req.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(doctorRequestInboxProvider('pending'));

    return Scaffold(
      appBar: AppBar(title: const Text('Patient requests')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(doctorRequestInboxProvider('pending')),
        child: requests.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(
                          child: Text('No pending patient requests.')),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final req = list[i];
                    final busy = _busy.contains(req.id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.babyName,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            if (req.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(req.note),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Requested ${req.createdAt.toLocal().toString().split('.').first}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        busy ? null : () => _respond(req, false),
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed:
                                        busy ? null : () => _respond(req, true),
                                    child: busy
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load requests: $e')),
        ),
      ),
    );
  }
}
