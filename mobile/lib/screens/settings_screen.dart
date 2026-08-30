// Settings (Section 11): dark mode, language, units, sync status, BLE
// simulator toggle, notification preferences, privacy, profile link,
// delete account, logout. Dark mode/language/units/BLE preference persist
// via AppSettingsStore (SharedPreferences); notification preferences are
// server-side (they need to affect what the backend sends regardless of
// which device the user opens next).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/l10n.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _pending = 0;
  int _failed = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final db = ref.read(localDbProvider);
    final pending = await db.pendingCount();
    final failed = await db.failedCount();
    if (mounted) {
      setState(() {
        _pending = pending;
        _failed = failed;
      });
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This deactivates your account — you will be signed out '
                'everywhere and unable to log back in. Your baby\'s medical '
                'records are kept (a doctor or admin may still need them); '
                'contact support if you need them permanently erased.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm your password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (passwordCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Enter your password.');
                  return;
                }
                try {
                  await ref
                      .read(userRepositoryProvider)
                      .deactivateAccount(passwordCtrl.text);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setDialogState(() => error = 'Incorrect password.');
                }
              },
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(darkModeProvider);
    final locale = ref.watch(localeCodeProvider);
    final units = ref.watch(unitsProvider);
    final useSimulator = ref.watch(useSimulatedBleProvider);
    final store = ref.read(settingsStoreProvider);
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l.t('dark_mode')),
            value: dark,
            onChanged: (v) {
              ref.read(darkModeProvider.notifier).state = v;
              store?.setDarkMode(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.t('language')),
            trailing: DropdownButton<String>(
              value: locale,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
              ],
              onChanged: (v) {
                final code = v ?? 'en';
                ref.read(localeCodeProvider.notifier).state = code;
                store?.setLocale(code);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.straighten_outlined),
            title: const Text('Units'),
            trailing: DropdownButton<String>(
              value: units,
              items: const [
                DropdownMenuItem(value: 'metric', child: Text('Metric (kg, °C)')),
                DropdownMenuItem(value: 'imperial', child: Text('Imperial (lb, °F)')),
              ],
              onChanged: (v) {
                final u = v ?? 'metric';
                ref.read(unitsProvider.notifier).state = u;
                store?.setUnits(u);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Pending sync'),
            subtitle: Text('$_pending measurement(s) waiting to upload'),
            trailing: IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              onPressed: _syncing
                  ? null
                  : () async {
                      setState(() => _syncing = true);
                      await ref.read(syncServiceProvider).syncOnce();
                      await _refreshCounts();
                      if (mounted) setState(() => _syncing = false);
                    },
            ),
          ),
          if (_failed > 0)
            ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text('$_failed failed upload(s)',
                  style: const TextStyle(color: Colors.red)),
              subtitle: const Text(
                  'Kept repeatedly failing to sync — tap Retry to try again'),
              trailing: TextButton(
                onPressed: _syncing
                    ? null
                    : () async {
                        setState(() => _syncing = true);
                        await ref.read(syncServiceProvider).retryFailed();
                        await _refreshCounts();
                        if (mounted) setState(() => _syncing = false);
                      },
                child: const Text('Retry'),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.watch_outlined),
            title: const Text('Bracelet information'),
            onTap: () => Navigator.of(context).pushNamed('/bracelet-info'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bluetooth_outlined),
            title: const Text('Use BLE simulator'),
            subtitle: Text(useSimulator
                ? 'Generating realistic vitals — no hardware needed'
                : 'Connecting to a real bracelet over Bluetooth'),
            value: useSimulator,
            onChanged: (v) {
              ref.read(useSimulatedBleProvider.notifier).state = v;
              store?.setUseSimulatedBle(v);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(v
                    ? 'Switched to simulator — reconnect from Pairing to use it.'
                    : 'Switched to real BLE — reconnect from Pairing to use it.'),
              ));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () => Navigator.of(context).pushNamed('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notification preferences'),
            onTap: () =>
                Navigator.of(context).pushNamed('/notification-preferences'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            onTap: () => Navigator.of(context).pushNamed('/privacy'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l.t('logout'),
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Delete account',
                style: TextStyle(color: Colors.red)),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }
}
