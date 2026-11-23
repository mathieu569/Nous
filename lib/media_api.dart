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

Future<List<MediaHit>> _books(String q) async {
  final uri = Uri.https('openlibrary.org', '/search.json', {
    'q': q,
    'limit': '15',
    'fields': 'key,title,author_name,first_publish_year,cover_i',
  });
  final r = await http.get(uri).timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw 'Recherche impossible (code ${r.statusCode}).';
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
