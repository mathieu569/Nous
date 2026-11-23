import 'package:flutter/material.dart';

import '../media.dart';
import '../store.dart';
import 'media_search_screen.dart';

/// Les envies : sa liste, la mienne, ou tout. Un cœur marque les envies communes.
class WishesScreen extends StatefulWidget {
  const WishesScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

enum _View { me, partner, all }

class _WishesScreenState extends State<WishesScreen> {
  _View _view = _View.me;
  MediaKind? _kind;

  AppStore get s => widget.store;

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mediaError(e))));
  }

  Future<void> _actions(MediaItem m) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(m.title), subtitle: Text(m.kind.label)),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Commencer'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await s.start(m);
                  _snack('Ajouté à « Du moment ».');
                } catch (e) {
                  _snack(e);
                }
              },
            ),
            if (s.iWish(m.id))
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: const Text('Retirer de mes envies'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await s.removeWish(m);
                  } catch (e) {
                    _snack(e);
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Ajouter à mes envies'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await s.addWish(MediaHit(
                      kind: m.kind,
                      extId: m.extId,
                      title: m.title,
                      subtitle: m.subtitle,
                      coverUrl: m.coverUrl,
                    ));
                  } catch (e) {
                    _snack(e);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = (s.partner?.name.isNotEmpty ?? false) ? s.partner!.name : 'Elle';
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MediaSearchScreen(store: s)),
        ),
        icon: const Icon(Icons.search),
        label: const Text('Chercher'),
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final items = s.media.where((m) {
            if (m.status != 'wish') return false;
            if (_kind != null && m.kind != _kind) return false;
            return switch (_view) {
              _View.me => s.iWish(m.id),
              _View.partner => s.partnerWishes(m.id),
              _View.all => true,
            };
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<_View>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment<_View>(value: _View.me, label: Text('Moi')),
                    ButtonSegment<_View>(
                        value: _View.partner, label: Text(partnerName)),
                    const ButtonSegment<_View>(
                        value: _View.all, label: Text('Tout')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (v) => setState(() => _view = v.first),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Tout'),
                        selected: _kind == null,
                        onSelected: (_) => setState(() => _kind = null),
                      ),
                    ),
                    for (final k in MediaKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(k.plural),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Aucune envie ici.'))
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          for (final m in items)
                            ListTile(
                              leading:
                                  Cover(url: m.coverUrl, kind: m.kind, height: 56),
                              title: Text(m.title),
                              subtitle: Text([
                                m.kind.label,
                                if (m.subtitle != null && m.subtitle!.isNotEmpty)
                                  m.subtitle!,
                              ].join(' · ')),
                              trailing: (s.iWish(m.id) && s.partnerWishes(m.id))
                                  ? const Tooltip(
                                      message: 'Vous en avez envie tous les deux',
                                      child: Icon(Icons.favorite, color: Colors.pink),
                                    )
                                  : null,
                              onTap: () => _actions(m),
                            ),
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
