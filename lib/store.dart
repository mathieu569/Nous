import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Person {
  Person({required this.name, this.status = '', this.photo});
  String name;
  String status;
  Uint8List? photo;

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'photo': photo == null ? null : base64Encode(photo!),
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        name: j['name'] as String,
        status: (j['status'] as String?) ?? '',
        photo: j['photo'] == null ? null : base64Decode(j['photo'] as String),
      );
}

class Story {
  Story(this.id, this.owner, this.at, this.png);
  final String id;
  final int owner; // 0 ou 1
  final DateTime at;
  final Uint8List png;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner,
        'at': at.toIso8601String(),
        'png': base64Encode(png),
      };

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        j['id'] as String,
        j['owner'] as int,
        DateTime.parse(j['at'] as String),
        base64Decode(j['png'] as String),
      );
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

  DateTime? startDate;
  List<Person> persons = [Person(name: 'Moi'), Person(name: 'Elle')];
  List<Story> stories = []; // les plus récentes d'abord
  List<CoupleEvent> events = [];

  static Future<AppStore> load() async {
    final s = AppStore._(await SharedPreferences.getInstance());
    final start = s._prefs.getString('start');
    if (start != null) s.startDate = DateTime.parse(start);
    for (var i = 0; i < 2; i++) {
      final raw = s._prefs.getString('person$i');
      if (raw != null) {
        s.persons[i] = Person.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    }
    s.stories = (s._prefs.getStringList('stories') ?? [])
        .map((e) => Story.fromJson(jsonDecode(e) as Map<String, dynamic>))
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

  Future<void> updatePerson(int i,
      {String? name, String? status, Uint8List? photo}) async {
    final p = persons[i];
    if (name != null && name.isNotEmpty) p.name = name;
    if (status != null) p.status = status;
    if (photo != null) p.photo = photo;
    await _prefs.setString('person$i', jsonEncode(p.toJson()));
    notifyListeners();
  }

  Future<void> addStory(int owner, Uint8List png) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    stories = [Story(id, owner, DateTime.now(), png), ...stories];
    await _saveStories();
    notifyListeners();
  }

  Future<void> removeStory(String id) async {
    stories = stories.where((s) => s.id != id).toList();
    await _saveStories();
    notifyListeners();
  }

  Future<void> _saveStories() => _prefs.setStringList(
      'stories', stories.map((e) => jsonEncode(e.toJson())).toList());

  Future<void> addEvent(String title, DateTime date) async {
    final e = CoupleEvent(
        DateTime.now().microsecondsSinceEpoch.toString(), title, date);
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
