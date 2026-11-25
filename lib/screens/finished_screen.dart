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

  String _day(DateTime d) => DateFormat.yMMMd('fr_FR').format(d);

  /// Ligne d'une personne dans la liste : date de fin et note.
  Widget _personLine(String who, DateTime? date, int? value) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(who, overflow: TextOverflow.ellipsis)),
            if (date == null)
              const Text('pas fini', style: TextStyle(fontSize: 12))
            else ...[
              Text(_day(date), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Stars(value: value, size: 16),
              if (value == null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('pas noté', style: TextStyle(fontSize: 12)),
                ),
            ],
          ],
        ),
      );

  void _err(BuildContext ctx, Object e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(mediaError(e))));
    }
  }

  Future<void> _pickMyDate(BuildContext ctx, MediaItem m) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: ctx,
      initialDate: store.myFinish(m) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59),
      helpText: 'Ma date de fin',
    );
    if (d == null) return;
    try {
      await store.setMyFinishDate(m, d);
    } catch (e) {
      _err(ctx, e);
    }
  }

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
                const Text('Moi'),
                const SizedBox(height: 4),
                if (store.myFinish(cur) == null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.event),
                    label: const Text('J\'ai aussi fini : choisir ma date'),
                    onPressed: () => _pickMyDate(ctx, cur),
                  )
                else ...[
                  TextButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                        'Fini le ${_day(store.myFinish(cur)!)} (modifier)'),
                    onPressed: () => _pickMyDate(ctx, cur),
                  ),
                  Stars(
                    value: store.myRating(m.id),
                    size: 38,
                    onChanged: (v) async {
                      try {
                        await store.setRating(cur, v);
                      } catch (e) {
                        _err(ctx, e);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text(_partnerName),
                const SizedBox(height: 4),
                if (store.partnerFinish(cur) == null)
                  const Text('Pas encore fini')
                else ...[
                  Text('Fini le ${_day(store.partnerFinish(cur)!)}'),
                  const SizedBox(height: 4),
                  Stars(value: store.partnerRating(m.id), size: 24),
                ],
                const SizedBox(height: 8),
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
          ..sort((a, b) => store.lastFinish(b).compareTo(store.lastFinish(a)));
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
                              Text(m.kind.label),
                              const SizedBox(height: 6),
                              _personLine('Moi', store.myFinish(m),
                                  store.myRating(m.id)),
                              _personLine(_partnerName, store.partnerFinish(m),
                                  store.partnerRating(m.id)),
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
