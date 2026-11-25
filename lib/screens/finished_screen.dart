import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../media.dart';
import '../store.dart';

/// Tout ce qui est fini, avec les deux notes.
class FinishedScreen extends StatefulWidget {
  const FinishedScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<FinishedScreen> createState() => _FinishedScreenState();
}

enum _Who { tous, moi, elle, deux }

class _FinishedScreenState extends State<FinishedScreen> {
  AppStore get store => widget.store;

  _Who _who = _Who.tous;
  MediaKind? _kind; // null = tous les types
  bool _byNote = false; // false = tri par date
  bool _asc = false; // false = décroissant

  /// Moyenne des notes données (celle de l'un, de l'autre ou des deux). Null si aucune.
  double? _avg(MediaItem m) {
    final r = [store.myRating(m.id), store.partnerRating(m.id)].whereType<int>();
    if (r.isEmpty) return null;
    return r.reduce((a, b) => a + b) / r.length;
  }

  bool _keep(MediaItem m) {
    if (_kind != null && m.kind != _kind) return false;
    final mine = store.myFinish(m) != null;
    final her = store.partnerFinish(m) != null;
    return switch (_who) {
      _Who.tous => true,
      _Who.moi => mine && !her,
      _Who.elle => her && !mine,
      _Who.deux => mine && her,
    };
  }

  /// Date de tri : celle de la personne concernée, sinon la plus récente des deux.
  DateTime _date(MediaItem m) => switch (_who) {
        _Who.moi => store.myFinish(m) ?? store.lastFinish(m),
        _Who.elle => store.partnerFinish(m) ?? store.lastFinish(m),
        _ => store.lastFinish(m),
      };

  int _compare(MediaItem a, MediaItem b) {
    final byDate = _asc ? _date(a).compareTo(_date(b)) : _date(b).compareTo(_date(a));
    if (!_byNote) return byDate;
    final x = _avg(a), y = _avg(b);
    if (x == null && y == null) return _date(b).compareTo(_date(a));
    if (x == null) return 1; // sans note : toujours à la fin
    if (y == null) return -1;
    final c = _asc ? x.compareTo(y) : y.compareTo(x);
    return c != 0 ? c : _date(b).compareTo(_date(a));
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
            label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('Tous', _who == _Who.tous, () => setState(() => _who = _Who.tous)),
              _chip('Moi seul', _who == _Who.moi, () => setState(() => _who = _Who.moi)),
              _chip('$_partnerName seule', _who == _Who.elle,
                  () => setState(() => _who = _Who.elle)),
              _chip('Les deux', _who == _Who.deux, () => setState(() => _who = _Who.deux)),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('Tous types', _kind == null, () => setState(() => _kind = null)),
              for (final k in MediaKind.values)
                _chip(k.plural, _kind == k, () => setState(() => _kind = k)),
            ]),
          ),
          Row(children: [
            const Text('Tri : '),
            const SizedBox(width: 8),
            _chip('Date', !_byNote, () => setState(() => _byNote = false)),
            _chip('Note', _byNote, () => setState(() => _byNote = true)),
            const Spacer(),
            IconButton(
              tooltip: _asc ? 'Croissant' : 'Décroissant',
              icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () => setState(() => _asc = !_asc),
            ),
          ]),
        ],
      ),
    );
  }

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
        final done = store.media.where((m) => m.status == 'done').toList();
        if (done.isEmpty) {
          return const Center(child: Text('Rien de fini pour l\'instant.'));
        }
        final items = done.where(_keep).toList()..sort(_compare);
        if (items.isEmpty) {
          return Column(children: [
            _controls(),
            const Expanded(child: Center(child: Text('Aucun titre ici.'))),
          ]);
        }
        return Column(children: [
          _controls(),
          Expanded(
            child: ListView(
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
                                if (_byNote && _avg(m) != null)
                                  'moyenne ${_avg(m)!.toStringAsFixed(1).replaceAll('.', ',')}',
                              ].join(' · ')),
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
        ),
          ),
        ]);
      },
    );
  }
}
