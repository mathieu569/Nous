import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart';
import 'event_edit_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.store});
  final AppStore store;

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

  Widget _card(BuildContext context, CoupleEvent e, DateTime now, bool isPast) {
    final shown = isPast ? e.at : nextOccurrence(e.at, e.repeat, now);
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
      child: ListTile(
        leading: leading,
        isThreeLine: hasNote,
        title: Text(e.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat.yMMMMd('fr_FR').format(shown)} à '
                '${DateFormat.Hm('fr_FR').format(shown)}'
                '${rep.isEmpty ? '' : ' · $rep'}'),
            if (hasNote)
              Text(e.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          isPast ? _ago(e.at, now) : _countdown(shown, now),
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
          final upcoming = <CoupleEvent>[];
          final past = <CoupleEvent>[];
          for (final e in store.events) {
            if (e.repeat == EventRepeat.none && e.at.isBefore(now)) {
              past.add(e);
            } else {
              upcoming.add(e);
            }
          }
          upcoming.sort((a, b) => nextOccurrence(a.at, a.repeat, now)
              .compareTo(nextOccurrence(b.at, b.repeat, now)));
          past.sort((a, b) => b.at.compareTo(a.at));

          if (upcoming.isEmpty && past.isEmpty) {
            return const Center(child: Text('Aucun événement. Ajoutez-en un.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            children: [
              if (upcoming.isNotEmpty) _header(context, 'À venir'),
              for (final e in upcoming) _card(context, e, now, false),
              if (past.isNotEmpty) _header(context, 'Passés'),
              for (final e in past) _card(context, e, now, true),
            ],
          );
        },
      ),
    );
  }
}
