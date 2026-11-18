import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Profile {
  Profile({
    required this.userId,
    required this.name,
    required this.status,
    this.photoPath,
  });
  final String userId;
  final String name;
  final String status;
  final String? photoPath;

  factory Profile.fromRow(Map<String, dynamic> r) => Profile(
        userId: r['user_id'] as String,
        name: (r['name'] as String?) ?? '',
        status: (r['status'] as String?) ?? '',
        photoPath: r['photo_path'] as String?,
      );

  Profile copyWith({String? name, String? status, String? photoPath}) =>
      Profile(
        userId: userId,
        name: name ?? this.name,
        status: status ?? this.status,
        photoPath: photoPath ?? this.photoPath,
      );
}

class Story {
  Story({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.imagePath,
  });
  final String id;
  final String authorId;
  final DateTime createdAt;
  final String imagePath;

  factory Story.fromRow(Map<String, dynamic> r) => Story(
        id: r['id'] as String,
        authorId: r['author_id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        imagePath: r['image_path'] as String,
      );
}

class CoupleEvent {
  CoupleEvent(this.id, this.title, this.date);
  final String id;
  final String title;
  final DateTime date;

  factory CoupleEvent.fromRow(Map<String, dynamic> r) => CoupleEvent(
        r['id'] as String,
        r['title'] as String,
        DateTime.parse(r['event_date'] as String),
      );
}

/// Données du couple, stockées dans Supabase et partagées entre les deux téléphones.
class AppStore extends ChangeNotifier {
  AppStore();

  SupabaseClient get _db => Supabase.instance.client;
  String get userId => _db.auth.currentUser!.id;

  bool loaded = false; // premier chargement terminé (réussi ou non)
  String? error;
  String? coupleId;
  String? code;
  DateTime? startDate;
  Profile? me;
  Profile? partner;
  List<Story> stories = [];
  List<CoupleEvent> events = [];

  final Map<String, Uint8List> _images = {};
  final Set<String> _loadingImages = {};
  RealtimeChannel? _channel;
  Timer? _debounce;

  bool get hasCouple => coupleId != null;

  Uint8List? image(String? path) => path == null ? null : _images[path];

  // ---------- chargement ----------

  Future<void> refresh() async {
    try {
      final profRows = await _db.from('profiles').select();
      final profiles =
          profRows.map<Profile>((r) => Profile.fromRow(r)).toList();
      me = profiles.where((p) => p.userId == userId).firstOrNull;
      partner = profiles.where((p) => p.userId != userId).firstOrNull;

      if (me == null) {
        coupleId = null;
        error = null;
        loaded = true;
        notifyListeners();
        return;
      }

      final coupleRows = await _db.from('couples').select();
      if (coupleRows.isNotEmpty) {
        final c = coupleRows.first;
        coupleId = c['id'] as String;
        code = c['code'] as String;
        final sd = c['start_date'] as String?;
        startDate = sd == null ? null : DateTime.parse(sd);
      }

      final storyRows = await _db
          .from('stories')
          .select()
          .order('created_at', ascending: false)
          .limit(60);
      stories = storyRows.map<Story>((r) => Story.fromRow(r)).toList();

      final eventRows = await _db.from('events').select().order('event_date');
      events = eventRows.map<CoupleEvent>((r) => CoupleEvent.fromRow(r)).toList();

      error = null;
      loaded = true;
      notifyListeners();
      _subscribe();
      unawaited(_fetchImages());
    } catch (e) {
      error = e.toString();
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> _fetchImages() async {
    final paths = <String>{
      if (me?.photoPath != null) me!.photoPath!,
      if (partner?.photoPath != null) partner!.photoPath!,
      for (final s in stories) s.imagePath,
    }..removeWhere((p) => _images.containsKey(p) || _loadingImages.contains(p));

    await Future.wait(paths.map((p) async {
      _loadingImages.add(p);
      try {
        _images[p] = await _db.storage.from('nous').download(p);
        notifyListeners();
      } catch (_) {
        // image introuvable ou réseau coupé: on réessaiera au prochain refresh
      } finally {
        _loadingImages.remove(p);
      }
    }));
  }

  void _subscribe() {
    if (_channel != null || coupleId == null) return;
    final ch = _db.channel('nous-$coupleId');
    for (final t in ['profiles', 'stories', 'events', 'couples']) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        callback: (_) => _scheduleRefresh(),
      );
    }
    ch.subscribe();
    _channel = ch;
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  // ---------- compte et couple ----------

  Future<void> createCouple(String name) async {
    await _db.rpc('create_couple', params: {'p_name': name});
    await refresh();
  }

  Future<void> joinCouple(String code, String name) async {
    await _db.rpc('join_couple', params: {'p_code': code, 'p_name': name});
    await refresh();
  }

  Future<void> signOut() => _db.auth.signOut();

  // ---------- actions ----------

  Future<void> setStartDate(DateTime d) async {
    await _db.from('couples').update({'start_date': _ymd(d)}).eq('id', coupleId!);
    startDate = d;
    notifyListeners();
  }

  Future<void> updateMe({String? name, String? status}) async {
    final upd = <String, dynamic>{
      if (name != null && name.isNotEmpty) 'name': name,
      if (status != null) 'status': status,
    };
    if (upd.isEmpty) return;
    await _db.from('profiles').update(upd).eq('user_id', userId);
    me = me!.copyWith(
      name: upd['name'] as String?,
      status: upd['status'] as String?,
    );
    notifyListeners();
    final s = upd['status'] as String?;
    if (s != null && s.isNotEmpty) unawaited(_notifyPartner());
  }

  /// Demande à Supabase d'envoyer une notification à l'autre. Sans effet si ça échoue.
  Future<void> _notifyPartner() async {
    try {
      await _db.functions.invoke('notify-status');
    } catch (_) {}
  }

  Future<void> setMyPhoto(Uint8List bytes) async {
    final path =
        '$coupleId/avatar-$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('nous').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    final old = me?.photoPath;
    await _db.from('profiles').update({'photo_path': path}).eq('user_id', userId);
    _images[path] = bytes;
    me = me!.copyWith(photoPath: path);
    notifyListeners();
    if (old != null) {
      try {
        await _db.storage.from('nous').remove([old]);
      } catch (_) {}
      _images.remove(old);
    }
  }

  Future<void> addStory(Uint8List png) async {
    final path =
        '$coupleId/story-${DateTime.now().millisecondsSinceEpoch}-$userId.png';
    await _db.storage.from('nous').uploadBinary(
          path,
          png,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    final row = await _db
        .from('stories')
        .insert({
          'couple_id': coupleId,
          'author_id': userId,
          'image_path': path,
        })
        .select()
        .single();
    _images[path] = png;
    stories = [Story.fromRow(row), ...stories];
    notifyListeners();
  }

  Future<void> removeStory(Story s) async {
    await _db.from('stories').delete().eq('id', s.id);
    stories = stories.where((e) => e.id != s.id).toList();
    notifyListeners();
    try {
      await _db.storage.from('nous').remove([s.imagePath]);
    } catch (_) {}
    _images.remove(s.imagePath);
  }

  Future<void> addEvent(String title, DateTime date) async {
    final row = await _db
        .from('events')
        .insert({
          'couple_id': coupleId,
          'title': title,
          'event_date': _ymd(date),
        })
        .select()
        .single();
    events = [...events, CoupleEvent.fromRow(row)];
    notifyListeners();
  }

  Future<void> removeEvent(String id) async {
    await _db.from('events').delete().eq('id', id);
    events = events.where((e) => e.id != id).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(_db.removeChannel(ch));
    super.dispose();
  }
}
