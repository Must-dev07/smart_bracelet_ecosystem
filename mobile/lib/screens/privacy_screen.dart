// Privacy (Section 11) — the same practices documented in the parent user
// manual, presented as an in-app screen instead of only a support doc.
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Section(
            icon: Icons.lock_outline,
            title: 'Encryption in transit',
            body:
                'Vitals and account data are sent to the platform server over '
                'HTTPS. The app never talks to the backend over plain HTTP.',
          ),
          _Section(
            icon: Icons.visibility_outlined,
            title: 'Who can see your baby\'s data',
            body:
                'Only you and the doctor assigned to your baby can see your '
                'baby\'s vitals, alerts, and medical history. Access to that '
                'data is logged server-side. A doctor is only assigned after '
                'you request them and they accept, or an administrator '
                'assigns them directly.',
          ),
          _Section(
            icon: Icons.storage_outlined,
            title: 'Offline data',
            body:
                'Measurements collected while your phone had no signal are '
                'queued on-device and uploaded automatically once you\'re back '
                'online. Nothing leaves your phone until it reaches the '
                'server over HTTPS.',
          ),
          _Section(
            icon: Icons.notifications_none,
            title: 'Notifications',
            body:
                'Vitals and device alerts are always delivered — they can\'t '
                'be muted, since they exist to flag your baby\'s safety. Other '
                'notification categories (bracelet, medical, system) can be '
                'turned off individually in Notification preferences.',
          ),
          _Section(
            icon: Icons.logout,
            title: 'Signing out',
            body:
                'Signing out revokes your session on the server immediately — '
                'a stolen device can\'t keep using your old login after that.',
          ),
          _Section(
            icon: Icons.delete_outline,
            title: 'Deleting your account',
            body:
                'Deleting your account deactivates it immediately and signs '
                'you out everywhere; medical records already shared with a '
                'doctor are kept since they may still be needed for your '
                'baby\'s care. Contact support if you need them permanently '
                'erased.',
          ),
          SizedBox(height: 8),
          Text(
            'This app flags abnormal readings for caregiver or medical '
            'follow-up. It does not provide medical diagnoses.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
