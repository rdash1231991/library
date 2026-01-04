import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/preset.dart';

class PresetStore {
  PresetStore._(this._prefs);

  static const _kPresetsKey = 'presets_v1';

  final SharedPreferences _prefs;

  static Future<PresetStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PresetStore._(prefs);
  }

  List<Preset> list() {
    final raw = _prefs.getString(_kPresetsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Preset.fromJson((e as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  Future<void> upsert(Preset preset) async {
    final presets = list();
    final idx = presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      presets[idx] = preset;
    } else {
      presets.add(preset);
    }
    await _prefs.setString(
      _kPresetsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final presets = list()..removeWhere((p) => p.id == id);
    await _prefs.setString(
      _kPresetsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }

  static String newId() {
    // Simple client-side id; good enough for local presets.
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(1 << 20);
    return '$now-$r';
  }
}

