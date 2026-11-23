import 'package:flutter/material.dart';

import '../media.dart';
import '../store.dart';

/// Ce qu'on regarde ou lit en ce moment : un film, une série, un livre au maximum.
class NowScreen extends StatelessWidget {
  const NowScreen({super.key, required this.store});
  final AppStore store;

  void _snack(BuildContext context, Object e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mediaError(e))));
  }

  Future<void> _pick(BuildContext context, MediaKind kind) async {
    final choices = store.media
        .where((m) => m.kind == kind && m.status == 'wish')
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: choices.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Aucune envie de ce type. Ajoutes-en une dans l\'onglet Envies.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in choices)
                    ListTile(
                      leading: Cover(url: m.coverUrl, kind: m.kind, height: 56),
                      title: Text(m.title),
                      subtitle: m.subtitle == null ? null : Text(m.subtitle!),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await store.start(m);
                        } catch (e) {
                          if (context.mounted) _snack(context, e);
                        }
                      },
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, MediaItem m) async {
    final rating = await askRating(context, m.title);
    if (rating == null) return;
    try {
      await store.finish(m, rating);
    } catch (e) {
      if (context.mounted) _snack(context, e);
    }
  }

  Widget _slot(BuildContext context, MediaKind kind) {
    final m = store.current(kind);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(kind.icon),
              const SizedBox(width: 8),
              Text(kind.label, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            if (m == null) ...[
              const Text('Rien en cours.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => _pick(context, kind),
                child: const Text('Choisir dans nos envies'),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(url: m.coverUrl, kind: kind, height: 96),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (m.subtitle != null) Text(m.subtitle!),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await store.backToWish(m);
                      } catch (e) {
                        if (context.mounted) _snack(context, e);
                      }
                    },
                    child: const Text('Remettre en envie'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _finish(context, m),
                    child: const Text('Terminé'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final k in MediaKind.values) _slot(context, k),
        ],
      ),
    );
  }
}
