import 'dart:convert';

class Preset {
  Preset({
    required this.id,
    required this.name,
    required this.presetJson,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  /// JSON returned by backend `/preset`.
  final Map<String, dynamic> presetJson;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'presetJson': presetJson,
        'createdAtMs': createdAtMs,
      };

  static Preset fromJson(Map<String, dynamic> json) {
    return Preset(
      id: json['id'] as String,
      name: json['name'] as String,
      presetJson: (json['presetJson'] as Map).cast<String, dynamic>(),
      createdAtMs: json['createdAtMs'] as int,
    );
  }

  String presetJsonString() => jsonEncode(presetJson);
}

