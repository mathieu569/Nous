import 'package:flutter/material.dart';

import '../media.dart';
import '../store.dart';

enum _Who { me, partner, together }

/// Ce qu'on regarde ou lit en ce moment : un film, une série, un livre au maximum,
/// pour moi, pour elle et pour nous deux.
class NowScreen extends StatefulWidget {
  const NowScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  _Who _who = _Who.me;

  AppStore get s => widget.store;

  /// Id du propriétaire des créneaux affichés (null = ensemble).
  String? get _owner => switch (_who) {
        _Who.me => s.userId,
        _Who.partner => s.partner?.userId,
        _Who.together => null,
      };

  bool get _editable => _who != _Who.partner;

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mediaError(e))));
  }

  Future<void> _pick(MediaKind kind) async {
    final choices = s.media
        .where((m) =>
            m.kind == kind &&
            m.status != 'current' &&
            (s.openWishOf(m, s.userId) || s.openWishOf(m, s.partner?.userId)))
        .toList();
    final owner = _owner;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: choices.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Aucune envie de ce type. Ajoutes-en une dans l\'onglet Envies.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in choices)
                    ListTile(
                      leading: Cover(url: m.coverUrl, kind: m.kind, height: 56),
                      title: Text(m.title),
                      subtitle: m.subtitle == null ? null : Text(m.subtitle!),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await s.start(m, owner);
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

  Future<void> _finish(MediaItem m) async {
    final rating = await askRating(context, m.title);
    if (rating == null) return;
    try {
      await s.finish(m, rating);
    } catch (e) {
      _snack(e);
    }
  }

  Widget _slot(MediaKind kind) {
    final m = s.current(kind, _owner);
    return Card(
      key: ValueKey('slot-${kind.name}-${_owner ?? 'ensemble'}-${m?.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(kind.icon),
              const SizedBox(width: 8),
              Text(kind.label, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            if (m == null) ...[
              const Text('Rien en cours.'),
              if (_editable) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => _pick(kind),
                  child: const Text('Choisir dans nos envies'),
                ),
              ],
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(url: m.coverUrl, kind: kind, height: 96),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (m.subtitle != null) Text(m.subtitle!),
                      ],
                    ),
                  ),
                ],
              ),
              if (_editable) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        try {
                          await s.backToWish(m);
                        } catch (e) {
                          _snack(e);
                        }
                      },
                      child: const Text('Remettre en envie'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _finish(m),
                      child: const Text('Terminé'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final partnerName =
            (s.partner?.name.isNotEmpty ?? false) ? s.partner!.name : 'Elle';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<_Who>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment<_Who>(value: _Who.me, label: Text('Moi')),
                ButtonSegment<_Who>(
                    value: _Who.partner, label: Text(partnerName)),
                const ButtonSegment<_Who>(
                    value: _Who.together, label: Text('Ensemble')),
              ],
              selected: {_who},
              onSelectionChanged: (v) => setState(() => _who = v.first),
            ),
            const SizedBox(height: 8),
            if (_who == _Who.partner && s.partner == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Elle n\'a pas encore rejoint le couple.'),
              )
            else
              for (final k in MediaKind.values) _slot(k),
          ],
        );
      },
    );
  }
}
