import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../store.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await widget.store.sendMessage(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enregistré (envoi réel à l\'étape suivante)')),
    );
  }

  Future<void> _addPreset() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau message rapide'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Ajouter')),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) await widget.store.addPreset(text);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Envoyer un petit mot',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in store.presets)
                  GestureDetector(
                    onLongPress: () => store.removePreset(p),
                    child: ActionChip(label: Text(p), onPressed: () => _send(p)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  onPressed: _addPreset,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Appui long sur un message pour le supprimer',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Écrire autre chose...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    await _send(_controller.text);
                    _controller.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Historique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (store.history.isEmpty) const Text('Rien pour l\'instant.'),
            for (final m in store.history)
              ListTile(
                dense: true,
                leading: const Icon(Icons.favorite, size: 18),
                title: Text(m.text),
                subtitle:
                    Text(DateFormat.yMMMd('fr_FR').add_Hm().format(m.at)),
              ),
          ],
        );
      },
    );
  }
}
