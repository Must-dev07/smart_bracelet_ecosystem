/// Settings: dark mode, language, sync status, profile link, logout
/// (logout clears BLE bond + secure storage via AuthRepository).
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

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final n = await ref.read(localDbProvider).unsyncedCount();
    if (mounted) setState(() => _pending = n);
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(darkModeProvider);
    final locale = ref.watch(localeCodeProvider);
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l.t('dark_mode')),
            value: dark,
            onChanged: (v) => ref.read(darkModeProvider.notifier).state = v,
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
              onChanged: (v) =>
                  ref.read(localeCodeProvider.notifier).state = v ?? 'en',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Pending sync'),
            subtitle: Text('$_pending measurement(s) waiting to upload'),
            trailing: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                await ref.read(syncServiceProvider).syncOnce();
                _refreshPending();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.watch_outlined),
            title: const Text('Bracelet information'),
            onTap: () => Navigator.of(context).pushNamed('/bracelet-info'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () => Navigator.of(context).pushNamed('/profile'),
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
        ],
      ),
    );
  }
}
