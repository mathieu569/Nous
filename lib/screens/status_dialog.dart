import 'package:flutter/material.dart';

/// États proposés d'un clic. Texte libre possible en dessous.
const statusPresets = [
  'Je pense à toi',
  'Je t\'aime fort',
  'Tu me manques',
  'Je t\'embrasse',
  'Bonne nuit mon amour',
  'Au travail',
  'Je rentre bientôt',
  'Besoin d\'un câlin',
];

/// Renvoie le nouvel état, '' pour l'effacer, ou null si annulé.
Future<String?> askStatus(BuildContext context, String current) {
  final c = TextEditingController(
      text: statusPresets.contains(current) ? '' : current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ton état du moment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in statusPresets)
                  ChoiceChip(
                    label: Text(p),
                    selected: p == current,
                    onSelected: (_) => Navigator.pop(ctx, p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Ou écris le tien',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Effacer')),
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final t = c.text.trim();
            Navigator.pop(ctx, t.isEmpty ? null : t);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
