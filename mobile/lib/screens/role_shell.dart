// Persistent bottom-navigation shell, one per role. Before this, every
// screen was reached via an AppBar icon button leading to a full-screen
// push — fine for one or two destinations, but with 4+ regularly-used
// sections per role that's a dated pattern. Each role gets its primary
// destinations as bottom tabs instead, plus a distinct nav accent color
// (AppColors.*Accent) so a screenshot alone tells you which role you're
// looking at. Admin's long tail of directory screens (Users/Doctors/
// Parents/Bracelets) stays reachable as quick-access cards on its Home tab
// rather than crowding the nav bar — the "hub" pattern.
//
// Screens not listed here (Settings, admin directories, baby detail, alert
// detail, medical history, …) remain ordinary pushed routes on top of the
// shell — nothing about that navigation changes.
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'admin_home_screen.dart';
import 'alerts_screen.dart';
import 'doctor_home_screen.dart';
import 'doctor_requests_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class RoleShell extends StatefulWidget {
  final String role;
  const RoleShell({super.key, required this.role});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final config = _shellFor(widget.role);
    final baseTheme = Theme.of(context);
    final tintedScheme = baseTheme.colorScheme.copyWith(
      primary: config.accent,
      secondary: config.accent,
    );

    return Theme(
      data: baseTheme.copyWith(colorScheme: tintedScheme),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (final t in config.tabs) t.screen],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: config.accent.withOpacity(0.18),
          destinations: [
            for (final t in config.tabs)
              NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}

class _ShellTab {
  final IconData icon;
  final String label;
  final Widget screen;
  const _ShellTab(this.icon, this.label, this.screen);
}

class _ShellConfig {
  final Color accent;
  final List<_ShellTab> tabs;
  const _ShellConfig(this.accent, this.tabs);
}

_ShellConfig _shellFor(String role) {
  switch (role) {
    case 'doctor':
      return _ShellConfig(AppColors.doctorAccent, const [
        _ShellTab(Icons.people_outline, 'Patients', DoctorHomeScreen()),
        _ShellTab(Icons.warning_amber_outlined, 'Alerts', AlertsScreen()),
        _ShellTab(Icons.inbox_outlined, 'Requests', DoctorRequestsScreen()),
        _ShellTab(Icons.person_outline, 'Profile', ProfileScreen()),
      ]);
    case 'admin':
      return _ShellConfig(AppColors.adminAccent, const [
        _ShellTab(Icons.dashboard_outlined, 'Home', AdminHomeScreen()),
        _ShellTab(Icons.warning_amber_outlined, 'Alerts', AlertsScreen()),
        _ShellTab(Icons.notifications_outlined, 'Inbox', NotificationsScreen()),
        _ShellTab(Icons.person_outline, 'Profile', ProfileScreen()),
      ]);
    case 'parent':
    default:
      return _ShellConfig(AppColors.parentAccent, const [
        _ShellTab(Icons.home_outlined, 'Home', HomeScreen()),
        _ShellTab(Icons.warning_amber_outlined, 'Alerts', AlertsScreen()),
        _ShellTab(Icons.notifications_outlined, 'Inbox', NotificationsScreen()),
        _ShellTab(Icons.person_outline, 'Profile', ProfileScreen()),
      ]);
  }
}
