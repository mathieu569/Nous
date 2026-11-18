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
