import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Récurrence d'un événement.
enum EventRepeat { none, weekly, monthly, yearly }

String repeatLabel(EventRepeat r) {
  switch (r) {
    case EventRepeat.weekly:
      return 'chaque semaine';
    case EventRepeat.monthly:
      return 'chaque mois';
    case EventRepeat.yearly:
      return 'chaque année';
    case EventRepeat.none:
      return '';
  }
}

/// Ajoute des mois en gardant l'heure. Un 31 tombe le dernier jour des mois courts, un 29 février le 28.
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(y, m, day, d.hour, d.minute);
}

DateTime _nthOccurrence(DateTime start, EventRepeat r, int k) {
  switch (r) {
    case EventRepeat.weekly:
      return DateTime(
          start.year, start.month, start.day + 7 * k, start.hour, start.minute);
    case EventRepeat.monthly:
      return addMonths(start, k);
    case EventRepeat.yearly:
      return addMonths(start, 12 * k);
    case EventRepeat.none:
      return start;
  }
}

/// Prochaine occurrence à partir de [now]. Sans récurrence : la date d'origine.
DateTime nextOccurrence(DateTime start, EventRepeat r, DateTime now) {
  if (r == EventRepeat.none || !start.isBefore(now)) return start;
  return _nthOccurrence(start, r, _nextIndex(start, r, now));
}

/// Occurrences déjà passées d'un événement récurrent, de la plus récente à la plus ancienne
/// (au plus [limit]). Vide sans récurrence ou si la date d'origine est dans le futur.
List<DateTime> pastOccurrences(DateTime start, EventRepeat r, DateTime now,
    {int limit = 12}) {
  if (r == EventRepeat.none || !start.isBefore(now)) return const [];
  final next = _nextIndex(start, r, now);
  final out = <DateTime>[];
  for (var j = next - 1; j >= 0 && out.length < limit; j--) {
    out.add(_nthOccurrence(start, r, j));
  }
  return out;
}

/// Rang de la prochaine occurrence (0 = la date d'origine).
int _nextIndex(DateTime start, EventRepeat r, DateTime now) {
  var k = 0;
  if (r == EventRepeat.weekly) {
    k = now.difference(start).inDays ~/ 7;
  } else if (r == EventRepeat.monthly) {
    k = (now.year - start.year) * 12 + now.month - start.month;
  } else if (r == EventRepeat.yearly) {
    k = now.year - start.year;
  }
  if (k < 0) k = 0;
  while (_nthOccurrence(start, r, k).isBefore(now)) {
    k++;
  }
  while (k > 0 && !_nthOccurrence(start, r, k - 1).isBefore(now)) {
    k--;
  }
  return k;
}

/// Message d'erreur lisible.
String errorText(Object e) {
  String m;
  if (e is PostgrestException) {
    m = e.message;
  } else if (e is AuthException) {
    m = e.message;
  } else if (e is StorageException) {
    m = e.message;
  } else {
    m = e.toString();
  }
  final l = m.toLowerCase();
  if (l.contains('invalid login credentials')) {
    return 'Email ou mot de passe incorrect.';
  }
  if (l.contains('already registered')) {
    return 'Cet email a déjà un compte. Connecte-toi.';
  }
  if (l.contains('password should be at least')) {
    return 'Mot de passe trop court (6 caractères minimum).';
  }
  if (l.contains('failed host lookup') ||
      l.contains('socketexception') ||
      l.contains('clientexception')) {
    return 'Pas de connexion Internet.';
  }
  return m;
}

/// Petite boîte de dialogue avec un champ texte. Renvoie null si annulé.
Future<String?> askText(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 80,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}
