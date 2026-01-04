import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../models/preset.dart';
import '../services/api_client.dart';
import '../services/preset_store.dart';
import '../services/settings_store.dart';
import '../utils/image_picker_utils.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  PresetStore? _store;
  List<Preset> _presets = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await PresetStore.load();
    setState(() {
      _store = store;
      _presets = store.list();
    });
  }

  Future<void> _createPreset() async {
    final store = _store;
    if (store == null) return;

    final picked = await ImagePickerUtils.pickFromGallery();
    if (picked == null) return;

    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final api = ApiClient(baseUrl: widget.settings.baseUrl);
      final presetJson = await api.createPreset(
        imageBytes: Uint8List.fromList(picked.bytes),
        filename: picked.filename,
      );
      final preset = Preset(
        id: PresetStore.newId(),
        name: name.trim(),
        presetJson: presetJson,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await store.upsert(preset);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preset saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePreset(Preset p) async {
    final store = _store;
    if (store == null) return;
    await store.remove(p.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _createPreset,
            icon: const Icon(Icons.add),
            tooltip: 'Create preset from photo',
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No presets yet.\nTap + to create one from a reference photo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _presets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _presets[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('Created ${DateTime.fromMillisecondsSinceEpoch(p.createdAtMs)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePreset(p),
                      ),
                    );
                  },
                ),
    );
  }
}

Future<String?> _promptName(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Preset name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Warm Film',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

