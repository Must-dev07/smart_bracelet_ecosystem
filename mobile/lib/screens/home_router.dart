/// Role-based landing screen. The app has a single '/home' route (used by
/// splash + login redirects); this widget wraps the right role in the
/// persistent bottom-nav shell (see role_shell.dart) so parents, doctors and
/// admins each land on the tabs relevant to them, without duplicating
/// navigation wiring elsewhere.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'role_shell.dart';

class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role ?? 'parent';

    // Side effect, not data: reading this provider constructs (and, per
    // syncServiceProvider, auto-starts) the background sync worker exactly
    // once, cached for the app's lifetime — so queued measurements drain
    // even if the user never opens Live Monitoring directly. Harmless no-op
    // for doctor/admin, whose local queue is always empty.
    ref.watch(syncServiceProvider);

    return RoleShell(role: role);
  }
}
