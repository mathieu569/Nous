import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media.dart';
import 'utils.dart';

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
    this.caption,
    this.isPhoto = false,
  });
  final String id;
  final String authorId;
  final DateTime createdAt;
  final String imagePath;
  final String? caption;
  final bool isPhoto; // photo ou dessin

  factory Story.fromRow(Map<String, dynamic> r) => Story(
        id: r['id'] as String,
        authorId: r['author_id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        imagePath: r['image_path'] as String,
        caption: r['caption'] as String?,
        isPhoto: r['kind'] == 'photo',
      );
}

class EventCategory {
  EventCategory({required this.id, required this.name});
  final String id;
  final String name;
}

class CoupleEvent {
  CoupleEvent({
    required this.id,
    required this.title,
    required this.at,
    this.note,
    this.photoPath,
    this.repeat = EventRepeat.none,
    this.categoryId,
  });
  final String? categoryId;
  final String id;
  final String title;
  final DateTime at; // date d'origine + heure, en heure locale
  final String? note;
  final String? photoPath;
  final EventRepeat repeat;

  factory CoupleEvent.fromRow(Map<String, dynamic> r) {
    final raw = (r['event_at'] ?? r['event_date']) as String;
    final repeatName = (r['repeat'] as String?) ?? 'none';
    return CoupleEvent(
      id: r['id'] as String,
      title: r['title'] as String,
      at: DateTime.parse(raw).toLocal(),
      note: r['note'] as String?,
      photoPath: r['photo_path'] as String?,
      categoryId: r['category_id'] as String?,
      repeat: EventRepeat.values.firstWhere(
        (v) => v.name == repeatName,
        orElse: () => EventRepeat.none,
      ),
    );
  }
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
  List<EventCategory> categories = [];

  String? categoryName(String? id) =>
      categories.where((c) => c.id == id).map((c) => c.name).firstOrNull;
  List<MediaItem> media = [];
  Map<String, Set<String>> wishes = {}; // media id -> ids des personnes qui en ont envie
  Map<String, Map<String, int>> ratings = {}; // media id -> (user id -> note)
  Map<String, Map<String, DateTime>> finishDates = {}; // media id -> (user id -> date de fin)

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

      try {
        categories = await _fetchCategories();
      } catch (_) {
        categories = []; // SQL des catégories pas encore lancé
      }

      try {
        events = await _fetchEvents();
      } catch (_) {
        events = []; // SQL des événements pas encore lancé : on n'empêche pas l'appli de démarrer
      }

      try {
        await _fetchMedia();
      } catch (_) {
        media = []; // SQL du suivi pas encore lancé
      }

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
      for (final e in events)
        if (e.photoPath != null) e.photoPath!,
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
    for (final t in ['profiles', 'stories', 'events', 'event_categories', 'couples', 'media', 'media_wishes', 'media_ratings']) {
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
  /// [type] : 'drawing' ou 'photo' pour un partage, null pour un changement d'état.
  Future<void> _notifyPartner([String? type]) async {
    try {
      await _db.functions
          .invoke('notify-status', body: type == null ? null : {'type': type});
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

  /// Partage un dessin (PNG) ou une photo (JPEG), avec un commentaire facultatif.
  Future<void> addStory(Uint8List bytes,
      {required bool photo, String? caption}) async {
    final ext = photo ? 'jpg' : 'png';
    final path =
        '$coupleId/story-${DateTime.now().millisecondsSinceEpoch}-$userId.$ext';
    await _db.storage.from('nous').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo ? 'image/jpeg' : 'image/png'),
        );
    final c = caption?.trim();
    final row = await _db
        .from('stories')
        .insert({
          'couple_id': coupleId,
          'author_id': userId,
          'image_path': path,
          'kind': photo ? 'photo' : 'drawing',
          'caption': (c == null || c.isEmpty) ? null : c,
        })
        .select()
        .single();
    _images[path] = bytes;
    stories = [Story.fromRow(row), ...stories];
    notifyListeners();
    unawaited(_notifyPartner(photo ? 'photo' : 'drawing'));
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

  Future<List<EventCategory>> _fetchCategories() async {
    final rows = await _db.from('event_categories').select().order('name');
    return rows
        .map<EventCategory>(
            (r) => EventCategory(id: r['id'] as String, name: r['name'] as String))
        .toList();
  }

  String _catError(PostgrestException e) =>
      e.code == '23505' ? 'Cette catégorie existe déjà.' : errorText(e);

  /// Crée une catégorie et renvoie son id.
  Future<String> addCategory(String name) async {
    try {
      final r = await _db
          .from('event_categories')
          .insert({'couple_id': coupleId, 'name': name.trim()})
          .select()
          .single();
      categories = await _fetchCategories();
      notifyListeners();
      return r['id'] as String;
    } on PostgrestException catch (e) {
      throw _catError(e);
    }
  }

  Future<void> renameCategory(EventCategory c, String name) async {
    try {
      await _db
          .from('event_categories')
          .update({'name': name.trim()}).eq('id', c.id);
    } on PostgrestException catch (e) {
      throw _catError(e);
    }
    categories = await _fetchCategories();
    notifyListeners();
  }

  /// Supprime la catégorie. Ses événements passent « sans catégorie ».
  Future<void> removeCategory(EventCategory c) async {
    await _db.from('event_categories').delete().eq('id', c.id);
    categories = await _fetchCategories();
    events = await _fetchEvents();
    notifyListeners();
  }

  Future<List<CoupleEvent>> _fetchEvents() async {
    final rows = await _db.from('events').select().order('event_at');
    return rows.map<CoupleEvent>((r) => CoupleEvent.fromRow(r)).toList();
  }

  /// Crée (id == null) ou modifie un événement.
  Future<void> saveEvent({
    String? id,
    required String title,
    required DateTime at,
    required EventRepeat repeat,
    String? categoryId,
    String? note,
    Uint8List? newPhoto,
    bool clearPhoto = false,
  }) async {
    final old = id == null ? null : events.where((e) => e.id == id).firstOrNull;
    var photoPath = old?.photoPath;
    String? toDelete;
    if (newPhoto != null) {
      final path =
          '$coupleId/event-${DateTime.now().millisecondsSinceEpoch}-$userId.jpg';
      await _db.storage.from('nous').uploadBinary(
            path,
            newPhoto,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      _images[path] = newPhoto;
      toDelete = photoPath;
      photoPath = path;
    } else if (clearPhoto && photoPath != null) {
      toDelete = photoPath;
      photoPath = null;
    }
    final data = <String, dynamic>{
      'title': title,
      'event_at': at.toUtc().toIso8601String(),
      'repeat': repeat.name,
      'note': (note == null || note.isEmpty) ? null : note,
      'photo_path': photoPath,
      'category_id': categoryId,
    };
    if (id == null) {
      await _db.from('events').insert({...data, 'couple_id': coupleId});
    } else {
      await _db.from('events').update(data).eq('id', id);
    }
    events = await _fetchEvents();
    notifyListeners();
    if (toDelete != null) {
      try {
        await _db.storage.from('nous').remove([toDelete]);
      } catch (_) {}
      _images.remove(toDelete);
    }
  }

  Future<void> removeEvent(CoupleEvent e) async {
    await _db.from('events').delete().eq('id', e.id);
    events = events.where((x) => x.id != e.id).toList();
    notifyListeners();
    final p = e.photoPath;
    if (p != null) {
      try {
        await _db.storage.from('nous').remove([p]);
      } catch (_) {}
      _images.remove(p);
    }
  }

  // ---------- suivi films / séries / livres ----------

  /// Titre en cours pour une personne (son id) ou pour les deux (ownerId == null).
  MediaItem? current(MediaKind k, String? ownerId) => media
      .where((m) =>
          m.kind == k && m.status == 'current' && m.ownerId == ownerId)
      .firstOrNull;

  /// Ce titre est-il déjà "consommé" par cette personne ? (en cours ou fini pour elle, ou ensemble)
  bool consumedBy(MediaItem m, String? uid) =>
      m.status != 'wish' &&
      (m.ownerId == null ||
          m.ownerId == uid ||
          m.finishedBy == uid ||
          (m.status == 'done' && finishDates[m.id]?[uid] != null));

  /// Envie encore ouverte pour cette personne : souhaitée et pas encore consommée par elle.
  bool openWishOf(MediaItem m, String? uid) =>
      uid != null &&
      (wishes[m.id]?.contains(uid) ?? false) &&
      !consumedBy(m, uid);

  String _who(String? uid) => uid == null
      ? 'vous deux'
      : (uid == me?.userId
          ? 'toi'
          : ((partner?.name.isNotEmpty ?? false) ? partner!.name : 'elle'));

  /// Texte d'état d'un titre déjà commencé ou fini ('' pour une simple envie).
  String statusLabel(MediaItem m) {
    if (m.status == 'current') {
      return m.ownerId == null ? 'En cours, ensemble' : 'En cours chez ${_who(m.ownerId)}';
    }
    if (m.status == 'done') {
      final w = m.ownerId == null ? 'vous deux' : _who(m.finishedBy ?? m.ownerId);
      return 'Déjà fini par $w';
    }
    return '';
  }

  bool iWish(String mediaId) => wishes[mediaId]?.contains(userId) ?? false;
  bool partnerWishes(String mediaId) =>
      partner != null && (wishes[mediaId]?.contains(partner!.userId) ?? false);
  int? myRating(String mediaId) => ratings[mediaId]?[userId];
  int? partnerRating(String mediaId) =>
      partner == null ? null : ratings[mediaId]?[partner!.userId];

  /// Date de fin d'une personne : la sienne si elle en a une, sinon celle du titre
  /// pour un titre fini ensemble ou par elle. Null si elle n'a pas fini ce titre.
  DateTime? finishedOn(MediaItem m, String? uid) {
    if (m.status != 'done' || uid == null) return null;
    final own = finishDates[m.id]?[uid];
    if (own != null) return own;
    return (m.ownerId == null || m.finishedBy == uid) ? m.finishedAt : null;
  }

  DateTime? myFinish(MediaItem m) => finishedOn(m, userId);
  DateTime? partnerFinish(MediaItem m) => finishedOn(m, partner?.userId);

  /// Date la plus récente des deux, pour trier « Finis ».
  DateTime lastFinish(MediaItem m) {
    final a = myFinish(m), b = partnerFinish(m);
    final all = [if (a != null) a, if (b != null) b];
    if (all.isEmpty) return m.finishedAt ?? m.createdAt;
    return all.reduce((x, y) => x.isAfter(y) ? x : y);
  }

  int _mediaSeq = 0;

  /// Charge les titres, envies et notes. Si plusieurs chargements se croisent
  /// (ajouts rapides), seul le plus récent est gardé. Renvoie ce qui vient d'être lu.
  Future<List<MediaItem>> _fetchMedia() async {
    final seq = ++_mediaSeq;
    final m = await _db.from('media').select().order('created_at', ascending: false);
    final w = await _db.from('media_wishes').select();
    final r = await _db.from('media_ratings').select();
    final items = m.map<MediaItem>((x) => MediaItem.fromRow(x)).toList();
    if (seq != _mediaSeq) return items; // un chargement plus récent est en cours
    media = items;
    wishes = {};
    for (final x in w) {
      (wishes[x['media_id'] as String] ??= {}).add(x['user_id'] as String);
    }
    ratings = {};
    finishDates = {};
    for (final x in r) {
      final mid = x['media_id'] as String, uid = x['user_id'] as String;
      if (x['rating'] != null) (ratings[mid] ??= {})[uid] = x['rating'] as int;
      if (x['finished_at'] != null) {
        (finishDates[mid] ??= {})[uid] =
            DateTime.parse(x['finished_at'] as String).toLocal();
      }
    }
    return items;
  }

  /// Recharge les titres (à l'ouverture d'un onglet). Sans effet en cas d'erreur.
  Future<void> reloadMedia() async {
    try {
      await _fetchMedia();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _reloadMedia() async {
    await _fetchMedia();
    notifyListeners();
  }

  /// Ajoute un titre à mes envies. Lève un String si le titre est déjà en cours ou fini.
  Future<void> addWish(MediaHit h) async {
    // Même source, ou même livre venu d'une autre source (titre identique).
    MediaItem? find() => media
        .where((m) =>
            m.kind == h.kind &&
            (m.extId == h.extId ||
                (h.kind == MediaKind.livre &&
                    normTitle(m.title) == normTitle(h.title))))
        .firstOrNull;
    var item = find();
    if (item == null) {
      try {
        await _db.from('media').insert({
          'couple_id': coupleId,
          'kind': h.kind.name,
          'ext_id': h.extId,
          'title': h.title,
          'subtitle': h.subtitle,
          'cover_url': h.coverUrl,
        });
      } catch (_) {
        // l'autre vient peut-être de l'ajouter en même temps : on recharge
      }
      final fresh = await _fetchMedia();
      item = fresh.where((m) => m.kind == h.kind && m.extId == h.extId).firstOrNull ??
          find();
      if (item == null) throw 'Ajout impossible. Réessaie.';
    }
    await _db
        .from('media_wishes')
        .upsert({'media_id': item.id, 'user_id': userId}, ignoreDuplicates: true);
    await _reloadMedia();
  }

  Future<void> removeWish(MediaItem m) async {
    await _db
        .from('media_wishes')
        .delete()
        .eq('media_id', m.id)
        .eq('user_id', userId);
    final others = (wishes[m.id] ?? {}).where((u) => u != userId);
    if (others.isEmpty && m.status == 'wish') {
      await _db.from('media').delete().eq('id', m.id);
    }
    await _reloadMedia();
  }

  Future<void> start(MediaItem m, String? ownerId) async {
    if (current(m.kind, ownerId) != null) {
      throw '${m.kind.label} déjà en cours ici. Termine-le ou remets-le en envie.';
    }
    try {
      await _db
          .from('media')
          .update({
        'status': 'current',
        'owner_id': ownerId,
        'finished_by': null,
        'finished_at': null,
      }).eq('id', m.id);
      await _clearDates(m.id);
    } on PostgrestException {
      throw '${m.kind.label} déjà en cours.';
    }
    await _reloadMedia();
  }

  Future<void> backToWish(MediaItem m) async {
    await _db.from('media').update({
      'status': 'wish',
      'owner_id': null,
      'finished_by': null,
      'finished_at': null,
    }).eq('id', m.id);
    await _clearDates(m.id);
    await _db
        .from('media_wishes')
        .upsert({'media_id': m.id, 'user_id': userId}, ignoreDuplicates: true);
    await _reloadMedia();
  }

  Future<void> _clearDates(String mediaId) async {
    try {
      await _db.rpc('clear_finish_dates', params: {'p_media': mediaId});
    } catch (_) {}
  }

  /// Passe en fini. [rating] 1 à 5, ou null / 0 sans note.
  /// Ma date = maintenant. Pour un titre « ensemble », l'autre a la même date par défaut.
  Future<void> finish(MediaItem m, int? rating) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.from('media').update({
      'status': 'done',
      'finished_by': userId,
      'finished_at': now,
    }).eq('id', m.id);
    await _clearDates(m.id);
    await _db.from('media_ratings').upsert({
      'media_id': m.id,
      'user_id': userId,
      'finished_at': now,
      if (rating != null && rating > 0) 'rating': rating,
    }, onConflict: 'media_id,user_id');
    await _reloadMedia();
  }

  /// Remet un titre fini en cours (si le créneau est libre). Les notes sont gardées.
  Future<void> reopen(MediaItem m) async {
    if (current(m.kind, m.ownerId) != null) {
      throw '${m.kind.label} déjà en cours.';
    }
    try {
      await _db.from('media').update({
        'status': 'current',
        'finished_by': null,
        'finished_at': null,
      }).eq('id', m.id);
      await _clearDates(m.id);
    } on PostgrestException {
      throw '${m.kind.label} déjà en cours.';
    }
    await _reloadMedia();
  }

  /// Ma date de fin (midi, heure locale, pour éviter tout décalage de jour).
  /// Sert aussi quand je déclare avoir fini un titre que l'autre a terminé.
  Future<void> setMyFinishDate(MediaItem m, DateTime day) async {
    final d = DateTime(day.year, day.month, day.day, 12);
    await _db.from('media_ratings').upsert({
      'media_id': m.id,
      'user_id': userId,
      'finished_at': d.toUtc().toIso8601String(),
    }, onConflict: 'media_id,user_id');
    await _reloadMedia();
  }

  Future<void> setRating(MediaItem m, int rating) async {
    if (myFinish(m) == null) throw 'Choisis d\'abord ta date de fin.';
    await _upsertRating(m.id, rating);
    await _reloadMedia();
  }

  Future<void> _upsertRating(String mediaId, int rating) => _db
      .from('media_ratings')
      .upsert({'media_id': mediaId, 'user_id': userId, 'rating': rating},
          onConflict: 'media_id,user_id');

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(_db.removeChannel(ch));
    super.dispose();
  }
}
