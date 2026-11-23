import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Aperçu avant envoi, avec un commentaire facultatif.
/// Renvoie le commentaire ('' si aucun) via Navigator.pop, ou null si on revient en arrière.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, required this.image});
  final Uint8List image;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.memory(widget.image, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLength: 150,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Commentaire (facultatif)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Envoyer'),
            onPressed: () => Navigator.pop(context, _caption.text.trim()),
          ),
        ],
      ),
    );
  }
}
