import 'package:flutter/material.dart';

import 'utils.dart';

enum MediaKind { film, serie, livre }

extension MediaKindX on MediaKind {
  String get label => switch (this) {
        MediaKind.film => 'Film',
        MediaKind.serie => 'Série',
        MediaKind.livre => 'Livre',
      };
  String get plural => switch (this) {
        MediaKind.film => 'Films',
        MediaKind.serie => 'Séries',
        MediaKind.livre => 'Livres',
      };
  IconData get icon => switch (this) {
        MediaKind.film => Icons.movie_outlined,
        MediaKind.serie => Icons.tv,
        MediaKind.livre => Icons.menu_book_outlined,
      };
}

MediaKind kindFromDb(String s) =>
    MediaKind.values.firstWhere((k) => k.name == s, orElse: () => MediaKind.film);

/// Un titre du couple : en envie, en cours ou fini.
class MediaItem {
  MediaItem({
    required this.id,
    required this.kind,
    required this.extId,
    required this.title,
    this.subtitle,
    this.coverUrl,
    required this.status,
    this.finishedBy,
    this.finishedAt,
    this.ownerId,
    required this.createdAt,
  });
  final String id;
  final MediaKind kind;
  final String extId;
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final String status; // wish | current | done
  final String? finishedBy;
  final DateTime? finishedAt;
  final String? ownerId; // pour qui c'est en cours ; null = ensemble
  final DateTime createdAt;

  factory MediaItem.fromRow(Map<String, dynamic> r) => MediaItem(
        id: r['id'] as String,
        kind: kindFromDb(r['kind'] as String),
        extId: r['ext_id'] as String,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String?,
        coverUrl: r['cover_url'] as String?,
        status: r['status'] as String,
        finishedBy: r['finished_by'] as String?,
        finishedAt: r['finished_at'] == null
            ? null
            : DateTime.parse(r['finished_at'] as String).toLocal(),
        ownerId: r['owner_id'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

/// Un résultat de recherche (TMDB ou Open Library).
class MediaHit {
  MediaHit({
    required this.kind,
    required this.extId,
    required this.title,
    this.subtitle,
    this.coverUrl,
  });
  final MediaKind kind;
  final String extId;
  final String title;
  final String? subtitle;
  final String? coverUrl;
}

/// Titre simplifié (minuscules, sans accents ni ponctuation) pour repérer les doublons.
String normTitle(String s) {
  const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    final d = i >= 0 ? to[i] : c;
    if (RegExp(r'[a-z0-9]').hasMatch(d)) b.write(d);
  }
  return b.toString();
}

String mediaError(Object e) => e is String ? e : errorText(e);

class Cover extends StatelessWidget {
  const Cover({super.key, required this.url, required this.kind, this.height = 64});
  final String? url;
  final MediaKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * 0.68;
    final placeholder = Container(
      width: w,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(kind.icon),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              key: ValueKey(url),
              width: w,
              height: height,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (_, child, p) => p == null ? child : placeholder,
            ),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars({super.key, this.value, this.size = 18, this.onChanged});
  final int? value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Icon(
              value != null && i <= value! ? Icons.star : Icons.star_border,
              size: size,
              color: value != null
                  ? Colors.amber.shade700
                  : Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
  }
}

/// Demande une note (facultative). Retourne null si annulé, sinon la note (0 = sans note).
Future<int?> askRating(BuildContext context, String title) {
  var value = 0;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('Terminé : $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ta note'),
            const SizedBox(height: 12),
            Stars(
              value: value == 0 ? null : value,
              size: 38,
              onChanged: (v) => setS(() => value = v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, value),
            child: Text(value == 0 ? 'Terminer sans note' : 'Terminer'),
          ),
        ],
      ),
    ),
  );
}
