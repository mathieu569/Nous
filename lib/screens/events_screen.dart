import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart' show daysBetween;

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.store});
  final AppStore store;

  String _countdown(DateTime date) {
    final n = daysBetween(DateTime.now(), date);
    if (n == 0) return 'Aujourd\'hui !';
    if (n > 0) return 'J-$n';
    return 'Il y a ${-n} j';
  }

  Future<void> _add(BuildContext context) async {
    final c = TextEditingController();
    DateTime? date;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nouvel événement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Ex: Vacances'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: date ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                  );
                  if (p != null) setState(() => date = p);
                },
                child: Text(date == null
                    ? 'Choisir la date'
                    : DateFormat.yMMMMd('fr_FR').format(date!)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final title = c.text.trim();
                if (title.isEmpty || date == null) return;
                await store.addEvent(title, date!);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = [...store.events]
            ..sort((a, b) => a.date.compareTo(b.date));
          if (list.isEmpty) {
            return const Center(child: Text('Aucun événement. Ajoutez-en un.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final e in list)
                Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade200,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => store.removeEvent(e.id),
                  child: Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle:
                          Text(DateFormat.yMMMMd('fr_FR').format(e.date)),
                      trailing: Text(_countdown(e.date),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
