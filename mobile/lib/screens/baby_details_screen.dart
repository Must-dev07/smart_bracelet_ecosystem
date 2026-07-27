/// Baby details: view the selected baby or create a new one (parent role).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class BabyDetailsScreen extends ConsumerStatefulWidget {
  const BabyDetailsScreen({super.key});
  @override
  ConsumerState<BabyDetailsScreen> createState() => _BabyDetailsScreenState();
}

class _BabyDetailsScreenState extends ConsumerState<BabyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _weight = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'unspecified';
  bool _saving = false;

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(babyRepositoryProvider).create({
        'name': _name.text.trim(),
        'birth_date': _birthDate!.toIso8601String().split('T').first,
        'weight_grams': int.parse(_weight.text),
        'gender': _gender,
      });
      ref.invalidate(babiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(selectedBabyProvider);

    if (baby != null) {
      // ------- View mode -------
      return Scaffold(
        appBar: AppBar(title: Text(baby.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Birth date'),
                    subtitle: Text(
                        baby.birthDate.toLocal().toString().split(' ').first)),
                ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: const Text('Weight'),
                    subtitle: Text(
                        '${(baby.weightGrams / 1000).toStringAsFixed(2)} kg')),
                ListTile(
                    leading: const Icon(Icons.wc_outlined),
                    title: const Text('Gender'),
                    subtitle: Text(baby.gender)),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/live'),
                icon: const Icon(Icons.monitor_heart),
                label: const Text('Live monitoring'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/graphs'),
                icon: const Icon(Icons.show_chart),
                label: const Text('Graphs'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/history'),
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
            ]),
          ],
        ),
      );
    }

    // ------- Create mode -------
    return Scaffold(
      appBar: AppBar(title: const Text('Add baby')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Weight (grams)', helperText: '300–8000 g'),
                validator: (v) {
                  final g = int.tryParse(v ?? '');
                  return (g != null && g >= 300 && g <= 8000)
                      ? null
                      : 'Enter 300–8000';
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12)),
                title: Text(_birthDate == null
                    ? 'Birth date'
                    : _birthDate!.toIso8601String().split('T').first),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(
                      value: 'unspecified', child: Text('Unspecified')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _create,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
