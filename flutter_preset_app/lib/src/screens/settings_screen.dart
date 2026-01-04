import 'package:flutter/material.dart';

import '../services/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.baseUrl);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _baseUrl.text.trim();
    if (v.isEmpty) return;
    await widget.settings.setBaseUrl(v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend base URL',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://localhost:8000',
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chrome/web tip: use http://localhost:8000 (if the backend runs on the same computer).',
            ),
          ],
        ),
      ),
    );
  }
}

