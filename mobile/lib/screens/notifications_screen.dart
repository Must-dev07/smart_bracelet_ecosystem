/// Notifications inbox (Section 9): category filter chips (alert/bracelet/
/// medical/system, each with a distinct icon), unread count, mark
/// read/mark-all-read, swipe-to-delete, tap = mark read + deep link to the
/// alert when present.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/l10n.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _category;
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final l = L10n.of(context);
    final unreadCount =
        notifications.value?.where((n) => n.isUnread).length ?? 0;

    final filtered = (notifications.value ?? <AppNotification>[])
        .where((n) => _category == null || n.category == _category)
        .where((n) => !_unreadOnly || n.isUnread)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(unreadCount > 0
            ? '${l.t('notifications')} ($unreadCount)'
            : l.t('notifications')),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                FilterChip(
                  label: const Text('Unread'),
                  selected: _unreadOnly,
                  onSelected: (v) => setState(() => _unreadOnly = v),
                ),
                const SizedBox(width: 8),
                for (final c in const [
                  ('alert', 'Alerts', Icons.warning_amber_outlined),
                  ('bracelet', 'Bracelet', Icons.watch_outlined),
                  ('medical', 'Medical', Icons.medical_services_outlined),
                  ('system', 'System', Icons.info_outline),
                ]) ...[
                  ChoiceChip(
                    label: Text(c.$2),
                    avatar: Icon(c.$3, size: 16),
                    selected: _category == c.$1,
                    onSelected: (sel) =>
                        setState(() => _category = sel ? c.$1 : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: notifications.when(
              data: (_) => filtered.isEmpty
                  ? const Center(child: Text('No notifications match this filter.'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(notificationsProvider),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = filtered[i];
                          return Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await ref
                                  .read(notificationRepositoryProvider)
                                  .delete(n.id);
                              ref.invalidate(notificationsProvider);
                            },
                            child: ListTile(
                              leading: Icon(
                                _categoryIcon(n.category),
                                color: n.isUnread ? Colors.red : Colors.grey,
                              ),
                              title: Text(n.title,
                                  style: TextStyle(
                                      fontWeight: n.isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                              subtitle: Text(n.body,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                n.createdAt.toLocal().toString().split(' ').first,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              onTap: () async {
                                await ref
                                    .read(notificationRepositoryProvider)
                                    .markRead(n.id);
                                ref.invalidate(notificationsProvider);
                                if (n.alertId != null && context.mounted) {
                                  Navigator.of(context).pushNamed('/alert-detail',
                                      arguments: n.alertId);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('Could not load notifications (offline?).')),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'alert' => Icons.warning_amber_outlined,
        'bracelet' => Icons.watch_outlined,
        'medical' => Icons.medical_services_outlined,
        _ => Icons.info_outline,
      };
}
