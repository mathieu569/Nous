import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart';
import 'category_dialog.dart';
import 'event_edit_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  AppStore get store => widget.store;

  /// null = tous, '' = sans catégorie, sinon id de catégorie.
  String? _filter;

  /// L'événement passe-t-il le filtre de catégorie actuel ?
  bool _matches(CoupleEvent e) {
    if (_filter == null) return true;
    if (_filter == '') return e.categoryId == null;
    return e.categoryId == _filter;
  }

  void _snack(Object e) {
    if (!mounted) return;
    final text = e is String ? e : errorText(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addCategory() async {
    final name = await askCategoryName(context, title: 'Nouvelle catégorie');
    if (name == null) return;
    try {
      final id = await store.addCategory(name);
      setState(() => _filter = id);
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _manage(EventCategory c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(c.name, style: Theme.of(ctx).textTheme.titleMedium)),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Renommer'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Supprimer (les événements restent)'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') {
      if (!mounted) return;
      final name =
          await askCategoryName(context, title: 'Renommer', initial: c.name);
      if (name == null) return;
      try {
        await store.renameCategory(c, name);
      } catch (e) {
        _snack(e);
      }
    } else if (action == 'delete') {
      try {
        await store.removeCategory(c);
        if (_filter == c.id) setState(() => _filter = null);
      } catch (e) {
        _snack(e);
      }
    }
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tous'),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          for (final c in store.categories) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: () => _manage(c),
              child: ChoiceChip(
                label: Text(c.name),
                selected: _filter == c.id,
                onSelected: (_) => setState(() => _filter = c.id),
              ),
            ),
          ],
          if (store.categories.isNotEmpty) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Sans catégorie'),
              selected: _filter == '',
              onSelected: (_) => setState(() => _filter = ''),
            ),
          ],
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Catégorie'),
            onPressed: _addCategory,
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, CoupleEvent? e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditScreen(store: store, event: e),
      ),
    );
  }

  String _countdown(DateTime next, DateTime now) {
    final n = daysBetween(now, next);
    if (n <= 0) return 'Aujourd\'hui';
    if (n == 1) return 'Demain';
    return 'J-$n';
  }

  String _ago(DateTime at, DateTime now) {
    final n = daysBetween(at, now);
    if (n <= 0) return 'Aujourd\'hui';
    if (n == 1) return 'Hier';
    return 'Il y a $n j';
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _card(BuildContext context, CoupleEvent e, DateTime shown, DateTime now,
      bool isPast) {
    final cat = store.categoryName(e.categoryId);
    final photo = store.image(e.photoPath);
    final hasNote = e.note != null && e.note!.isNotEmpty;
    final rep = repeatLabel(e.repeat);
    Widget? leading;
    if (photo != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(photo,
            width: 52, height: 52, fit: BoxFit.cover, gaplessPlayback: true),
      );
    } else if (e.photoPath != null) {
      leading = const SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Card(
      key: ValueKey('${e.id}-${shown.millisecondsSinceEpoch}-$isPast'),
      child: ListTile(
        leading: leading,
        isThreeLine: hasNote,
        title: Text(e.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat.yMMMMd('fr_FR').format(shown)} à '
                '${DateFormat.Hm('fr_FR').format(shown)}'
                '${rep.isEmpty ? '' : ' · $rep'}'
                '${cat == null ? '' : ' · $cat'}'),
            if (hasNote)
              Text(e.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          isPast ? _ago(shown, now) : _countdown(shown, now),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () => _open(context, e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          if (_filter != null &&
              _filter != '' &&
              !store.categories.any((c) => c.id == _filter)) {
            _filter = null;
          }
          final upcoming = <(CoupleEvent, DateTime)>[];
          final past = <(CoupleEvent, DateTime)>[];
          for (final e in store.events.where(_matches)) {
            if (e.repeat == EventRepeat.none) {
              (e.at.isBefore(now) ? past : upcoming).add((e, e.at));
            } else {
              upcoming.add((e, nextOccurrence(e.at, e.repeat, now)));
              for (final o in pastOccurrences(e.at, e.repeat, now)) {
                past.add((e, o));
              }
            }
          }
          upcoming.sort((a, b) => a.$2.compareTo(b.$2));
          past.sort((a, b) => b.$2.compareTo(a.$2));

          if (store.events.isEmpty) {
            return Column(children: [
              _filters(),
              const Expanded(
                  child: Center(child: Text('Aucun événement. Ajoutez-en un.'))),
            ]);
          }
          return Column(
            children: [
              _filters(),
              Expanded(
                child: (upcoming.isEmpty && past.isEmpty)
                    ? const Center(child: Text('Aucun événement ici.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        children: [
                          if (upcoming.isNotEmpty) _header(context, 'À venir'),
                          for (final x in upcoming)
                            _card(context, x.$1, x.$2, now, false),
                          if (past.isNotEmpty) _header(context, 'Passés'),
                          for (final x in past)
                            _card(context, x.$1, x.$2, now, true),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
