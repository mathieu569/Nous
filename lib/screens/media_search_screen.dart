import 'package:flutter/material.dart';

import '../media.dart';
import '../media_api.dart';
import '../store.dart';

/// Recherche d'un film, d'une série ou d'un livre pour l'ajouter à ses envies.
class MediaSearchScreen extends StatefulWidget {
  const MediaSearchScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<MediaSearchScreen> createState() => _MediaSearchScreenState();
}

class _MediaSearchScreenState extends State<MediaSearchScreen> {
  final _q = TextEditingController();
  MediaKind _kind = MediaKind.film;
  List<MediaHit> _hits = [];
  bool _busy = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_q.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await searchMedia(_kind, _q.text);
      if (!mounted) return;
      setState(() {
        _hits = r;
        _searched = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = mediaError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(MediaHit h) async {
    try {
      await widget.store.addWish(h);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('« ${h.title} » ajouté aux envies.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mediaError(e))));
    }
  }

  Widget _trailing(MediaHit h) {
    final s = widget.store;
    final existing = s.media
        .where((m) => m.kind == h.kind && m.extId == h.extId)
        .firstOrNull;
    if (existing != null) {
      if (existing.status == 'current') return const Text('En cours');
      if (existing.status == 'done') return const Text('Fini');
      if (s.iWish(existing.id)) {
        return const Icon(Icons.check_circle, color: Colors.green);
      }
    }
    return IconButton(
      tooltip: 'Ajouter aux envies',
      icon: const Icon(Icons.add_circle_outline),
      onPressed: () => _add(h),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chercher')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<MediaKind>(
              showSelectedIcon: false,
              segments: [
                for (final k in MediaKind.values)
                  ButtonSegment<MediaKind>(value: k, label: Text(k.plural)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _hits = [];
                _searched = false;
                _error = null;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Titre',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                if (_searched && _hits.isEmpty && _error == null) {
                  return const Center(child: Text('Aucun résultat.'));
                }
                return ListView(
                  children: [
                    for (final h in _hits)
                      ListTile(
                        leading: Cover(url: h.coverUrl, kind: h.kind, height: 56),
                        title: Text(h.title),
                        subtitle: (h.subtitle == null || h.subtitle!.isEmpty)
                            ? null
                            : Text(h.subtitle!),
                        trailing: _trailing(h),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
