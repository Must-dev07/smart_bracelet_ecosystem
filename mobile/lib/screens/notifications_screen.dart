/// Notifications inbox: server-recorded notifications, unread markers,
/// tap = mark read + deep link to the alert when present.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/l10n.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('notifications'))),
      body: notifications.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No notifications.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return ListTile(
                      leading: Icon(
                        n.isUnread
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: n.isUnread ? Colors.red : null,
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
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
            child: Text('Could not load notifications (offline?).')),
      ),
    );
  }
}
