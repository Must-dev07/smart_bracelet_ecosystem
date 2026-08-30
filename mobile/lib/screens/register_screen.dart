// Parent registration (doctors register via the web dashboard/admin).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/l10n.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _emergency = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register({
      'email': _email.text.trim(),
      'password': _password.text,
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'phone': _phone.text.trim(),
      'role': 'parent',
      'emergency_contact': _emergency.text.trim(),
    });
    if (ok && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('register'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.t('email')),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Invalid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: l.t('password'),
                      helperText: 'At least 10 characters'),
                  validator: (v) =>
                      v != null && v.length >= 10 ? null : 'Min 10 characters',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergency,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Emergency contact number'),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.loading ? null : _submit,
                  child: Text(l.t('register')),
                ),
                const DisclaimerBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
