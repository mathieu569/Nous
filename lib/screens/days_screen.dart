import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';

int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// [années, mois, jours]
List<int> breakdown(DateTime from, DateTime to) {
  var y = to.year - from.year;
  var m = to.month - from.month;
  var d = to.day - from.day;
  if (d < 0) {
    m -= 1;
    d += DateTime(to.year, to.month, 0).day;
  }
  if (m < 0) {
    y -= 1;
    m += 12;
  }
  return [y, m, d];
}

class DaysScreen extends StatelessWidget {
  const DaysScreen({super.key, required this.store});
  final AppStore store;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: store.startDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'Début de votre histoire',
    );
    if (picked != null) await store.setStartDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final start = store.startDate;
        final theme = Theme.of(context);
        if (start == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 64),
                const SizedBox(height: 16),
                const Text('Depuis quand êtes-vous ensemble ?'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _pick(context),
                  child: const Text('Choisir la date'),
                ),
              ],
            ),
          );
        }
        final now = DateTime.now();
        final total = daysBetween(start, now);
        final b = breakdown(start, now);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total',
                  style: theme.textTheme.displayLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(total > 1 ? 'jours ensemble' : 'jour ensemble',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('${b[0]} an(s), ${b[1]} mois, ${b[2]} jour(s)'),
              const SizedBox(height: 4),
              Text('depuis le ${DateFormat.yMMMMd('fr_FR').format(start)}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => _pick(context),
                child: const Text('Modifier la date'),
              ),
            ],
          ),
        );
      },
    );
  }
}
