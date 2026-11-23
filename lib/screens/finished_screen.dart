import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../media.dart';
import '../store.dart';

/// Tout ce qui est fini, avec les deux notes.
class FinishedScreen extends StatelessWidget {
  const FinishedScreen({super.key, required this.store});
  final AppStore store;

  String get _partnerName =>
      (store.partner?.name.isNotEmpty ?? false) ? store.partner!.name : 'Elle';

  Widget _ratingLine(String who, int? value) => Row(
        children: [
          SizedBox(width: 64, child: Text(who, overflow: TextOverflow.ellipsis)),
          Stars(value: value, size: 16),
          if (value == null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('pas noté', style: TextStyle(fontSize: 12)),
            ),
        ],
      );

  Future<void> _open(BuildContext context, MediaItem m) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          final cur = store.media.firstWhere((x) => x.id == m.id, orElse: () => m);
          return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                const Text('Ma note'),
                const SizedBox(height: 8),
                Stars(
                  value: store.myRating(m.id),
                  size: 38,
                  onChanged: (v) async {
                    try {
                      await store.setRating(m, v);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text(mediaError(e))));
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(cur.finishedAt == null
                      ? 'Date de fin'
                      : 'Fini le ${DateFormat.yMMMd('fr_FR').format(cur.finishedAt!)} (modifier)'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: cur.finishedAt ?? now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(now.year, now.month, now.day, 23, 59),
                      helpText: 'Date de fin',
                    );
                    if (d == null) return;
                    try {
                      await store.setFinishedDate(cur, d);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text(mediaError(e))));
                      }
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Remettre en cours'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await store.reopen(m);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(mediaError(e))));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.media.where((m) => m.status == 'done').toList()
          ..sort((a, b) => (b.finishedAt ?? b.createdAt)
              .compareTo(a.finishedAt ?? a.createdAt));
        if (items.isEmpty) {
          return const Center(child: Text('Rien de fini pour l\'instant.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final m in items)
              Card(
                key: ValueKey('done-${m.id}'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(context, m),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Cover(url: m.coverUrl, kind: m.kind, height: 80),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.title,
                                  style: Theme.of(context).textTheme.titleMedium),
                              Text([
                                m.kind.label,
                                if (m.finishedAt != null)
                                  'fini le ${DateFormat.yMMMd('fr_FR').format(m.finishedAt!)}',
                              ].join(' · ')),
                              const SizedBox(height: 6),
                              _ratingLine('Moi', store.myRating(m.id)),
                              _ratingLine(_partnerName, store.partnerRating(m.id)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
