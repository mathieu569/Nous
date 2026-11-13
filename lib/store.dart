import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SentMessage {
  SentMessage(this.text, this.at);
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {'text': text, 'at': at.toIso8601String()};

  factory SentMessage.fromJson(Map<String, dynamic> j) =>
      SentMessage(j['text'] as String, DateTime.parse(j['at'] as String));
}

class CoupleEvent {
  CoupleEvent(this.id, this.title, this.date);
  final String id;
  final String title;
  final DateTime date;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'date': date.toIso8601String()};

  factory CoupleEvent.fromJson(Map<String, dynamic> j) => CoupleEvent(
        j['id'] as String,
        j['title'] as String,
        DateTime.parse(j['date'] as String),
      );
}

/// Stockage local (v0). Le backend partagé arrive à l'étape suivante.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);
  final SharedPreferences _prefs;

  static const _defaultPresets = [
    'Je pense à toi',
    'Je t\'aime fort',
    'Je t\'embrasse',
    'Tu me manques',
    'Bonne nuit mon amour',
  ];

  DateTime? startDate;
  List<String> presets = List.of(_defaultPresets);
  List<SentMessage> history = [];
  List<CoupleEvent> events = [];

  static Future<AppStore> load() async {
    final s = AppStore._(await SharedPreferences.getInstance());
    final start = s._prefs.getString('start');
    if (start != null) s.startDate = DateTime.parse(start);
    final p = s._prefs.getStringList('presets');
    if (p != null) s.presets = p;
    s.history = (s._prefs.getStringList('history') ?? [])
        .map((e) => SentMessage.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    s.events = (s._prefs.getStringList('events') ?? [])
        .map((e) => CoupleEvent.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    return s;
  }

  Future<void> setStartDate(DateTime d) async {
    startDate = d;
    await _prefs.setString('start', d.toIso8601String());
    notifyListeners();
  }

  Future<void> addPreset(String text) async {
    presets = [...presets, text];
    await _prefs.setStringList('presets', presets);
    notifyListeners();
  }

  Future<void> removePreset(String text) async {
    presets = presets.where((e) => e != text).toList();
    await _prefs.setStringList('presets', presets);
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    history = [SentMessage(text, DateTime.now()), ...history];
    await _prefs.setStringList(
        'history', history.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> addEvent(String title, DateTime date) async {
    final e = CoupleEvent(DateTime.now().microsecondsSinceEpoch.toString(),
        title, date);
    events = [...events, e];
    await _saveEvents();
    notifyListeners();
  }

  Future<void> removeEvent(String id) async {
    events = events.where((e) => e.id != id).toList();
    await _saveEvents();
    notifyListeners();
  }

  Future<void> _saveEvents() => _prefs.setStringList(
      'events', events.map((e) => jsonEncode(e.toJson())).toList());
}
