import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/preset.dart';
import '../services/api_client.dart';
import '../services/preset_store.dart';
import '../services/settings_store.dart';
import '../utils/image_picker_utils.dart';
import '../utils/save_or_share.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  List<Preset> _presets = [];
  Preset? _selectedPreset;
  PickedImage? _picked;
  Uint8List? _outputPng;
  Map<String, String>? _accuracyStats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final store = await PresetStore.load();
    final presets = store.list();
    setState(() {
      _presets = presets;
      _selectedPreset = presets.isEmpty ? null : presets.first;
    });
  }

  Future<void> _pickTarget() async {
    final p = await ImagePickerUtils.pickFromGallery();
    if (p == null) return;
    setState(() {
      _picked = p;
      _outputPng = null;
      _accuracyStats = null;
    });
  }

  Future<void> _apply() async {
    final picked = _picked;
    final preset = _selectedPreset;
    if (picked == null || preset == null) return;

    setState(() => _busy = true);
    try {
      final api = ApiClient(baseUrl: widget.settings.baseUrl);
      final result = await api.applyPreset(
        imageBytes: Uint8List.fromList(picked.bytes),
        filename: picked.filename,
        presetJson: preset.presetJson,
      );
      setState(() {
        _outputPng = result.imageBytes;
        _accuracyStats = result.headers;
      });
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

  Future<void> _downloadOrShare() async {
    final out = _outputPng;
    if (out == null) return;
    await SaveOrShare.outputPngBytes(out);
  }

  @override
  Widget build(BuildContext context) {
    final canApply = !_busy && _picked != null && _selectedPreset != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _loadPresets,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload presets',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Preset>(
              value: _selectedPreset,
              items: _presets
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name),
                    ),
                  )
                  .toList(),
              onChanged: _busy ? null : (p) => setState(() => _selectedPreset = p),
              decoration: const InputDecoration(
                labelText: 'Preset',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickTarget,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_picked == null ? 'Pick target photo' : 'Pick another photo'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canApply ? _apply : null,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply preset'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _outputPng == null
                  ? const Center(
                      child: Text('Output preview will appear here.'),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _outputPng!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (_accuracyStats != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Match Score: ${(_accuracyStats!['x-accuracy-score'] ?? 'N/A')}\n'
                            'Tone: ${(_accuracyStats!['x-tone-accuracy'] ?? 'N/A')} | '
                            'Color: ${(_accuracyStats!['x-color-accuracy'] ?? 'N/A')}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _downloadOrShare,
                          icon: const Icon(Icons.download),
                          label: const Text('Download / Share'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

