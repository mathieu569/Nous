import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'media.dart';

/// Cherche un titre. Films et séries : TMDB. Livres : Open Library.
/// Les erreurs sont des String lisibles.
Future<List<MediaHit>> searchMedia(MediaKind kind, String query) async {
  final q = query.trim();
  if (q.isEmpty) return [];
  try {
    return kind == MediaKind.livre ? await _books(q) : await _tmdb(kind, q);
  } on String {
    rethrow;
  } catch (_) {
    throw 'Recherche impossible. Vérifie la connexion.';
  }
}

dynamic _json(http.Response r) => json.decode(utf8.decode(r.bodyBytes));

Future<List<MediaHit>> _tmdb(MediaKind kind, String q) async {
  if (tmdbKey.isEmpty) throw 'Clé TMDB manquante dans config.dart.';
  final isFilm = kind == MediaKind.film;
  final uri = Uri.https('api.themoviedb.org', '/3/search/${isFilm ? 'movie' : 'tv'}', {
    'api_key': tmdbKey,
    'language': 'fr-FR',
    'query': q,
    'include_adult': 'false',
  });
  final r = await http.get(uri).timeout(const Duration(seconds: 15));
  if (r.statusCode == 401) throw 'Clé TMDB invalide.';
  if (r.statusCode != 200) throw 'Recherche impossible (code ${r.statusCode}).';
  final results = (_json(r)['results'] as List).take(15);
  return results.map<MediaHit>((e) {
    final date = ((isFilm ? e['release_date'] : e['first_air_date']) as String?) ?? '';
    final poster = e['poster_path'] as String?;
    return MediaHit(
      kind: kind,
      extId: '${e['id']}',
      title: ((isFilm ? e['title'] : e['name']) as String?) ?? '?',
      subtitle: date.length >= 4 ? date.substring(0, 4) : null,
      coverUrl: poster == null ? null : 'https://image.tmdb.org/t/p/w185$poster',
    );
  }).toList();
}

/// Livres : Google Books (français en priorité) puis Open Library, sans doublons.
Future<List<MediaHit>> _books(String q) async {
  Future<List<MediaHit>?> safe(Future<List<MediaHit>> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  final res = await Future.wait([safe(_google(q)), safe(_openLibrary(q))]);
  if (res[0] == null && res[1] == null) {
    throw 'Recherche impossible. Vérifie la connexion.';
  }
  final seen = <String>{};
  final out = <MediaHit>[];
  for (final list in res) {
    for (final h in list ?? const <MediaHit>[]) {
      final author = (h.subtitle ?? '').split(',').first;
      final key = '${normTitle(h.title)}|${normTitle(author)}';
      if (seen.add(key)) out.add(h);
    }
  }
  return out;
}

Future<List<MediaHit>> _google(String q) async {
  if (googleBooksKey.isEmpty) return [];
  final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
    'q': q,
    'langRestrict': 'fr',
    'printType': 'books',
    'maxResults': '15',
    'key': googleBooksKey,
    'fields': 'items(id,volumeInfo(title,authors,publishedDate,imageLinks/thumbnail))',
  });
  final r = await http.get(uri).timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw 'Google Books ${r.statusCode}';
  final items = (_json(r)['items'] as List?) ?? const [];
  return items.map<MediaHit>((e) {
    final v = (e['volumeInfo'] as Map?) ?? const {};
    final authors = (v['authors'] as List?)?.cast<String>() ?? const [];
    final date = (v['publishedDate'] as String?) ?? '';
    final thumb = (v['imageLinks'] as Map?)?['thumbnail'] as String?;
    return MediaHit(
      kind: MediaKind.livre,
      extId: 'g:${e['id']}',
      title: (v['title'] as String?) ?? '?',
      subtitle: [
        if (authors.isNotEmpty) authors.first,
        if (date.length >= 4) date.substring(0, 4),
      ].join(', '),
      coverUrl: thumb?.replaceFirst('http://', 'https://'),
    );
  }).toList();
}

Future<List<MediaHit>> _openLibrary(String q) async {
  final uri = Uri.https('openlibrary.org', '/search.json', {
    'q': q,
    'limit': '15',
    'fields': 'key,title,author_name,first_publish_year,cover_i',
  });
  final r = await http.get(uri).timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw 'Open Library ${r.statusCode}';
  final docs = (_json(r)['docs'] as List);
  return docs.map<MediaHit>((e) {
    final authors = (e['author_name'] as List?)?.cast<String>() ?? const [];
    final year = e['first_publish_year'];
    final cover = e['cover_i'];
    return MediaHit(
      kind: MediaKind.livre,
      extId: e['key'] as String,
      title: (e['title'] as String?) ?? '?',
      subtitle: [
        if (authors.isNotEmpty) authors.first,
        if (year != null) '$year',
      ].join(', '),
      coverUrl: cover == null ? null : 'https://covers.openlibrary.org/b/id/$cover-M.jpg',
    );
  }).toList();
}
