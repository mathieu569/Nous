import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart';
import 'draw_screen.dart';
import 'status_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _mine = true; // historique affiché : le mien ou celui du/de la partenaire
  bool _busy = false;

  AppStore get store => widget.store;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: store.startDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'Début de votre histoire',
    );
    if (picked != null) await _run(() => store.setStartDate(picked));
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (x == null) return;
    final Uint8List bytes = await x.readAsBytes();
    await _run(() => store.setMyPhoto(bytes));
  }

  Future<void> _editStatus() async {
    final t = await askStatus(context, store.me?.status ?? '');
    if (t != null) await _run(() => store.updateMe(status: t));
  }

  Future<void> _editName() async {
    final t = await askText(context, 'Ton prénom', store.me?.name ?? '');
    if (t != null) await _run(() => store.updateMe(name: t));
  }

  Future<void> _draw() async {
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const DrawScreen()),
    );
    if (bytes == null || !mounted) return;
    await _run(() => store.addStory(bytes));
    if (mounted) setState(() => _mine = true);
  }

  Future<void> _view(Story s) {
    final img = store.image(s.imagePath);
    final isMine = s.authorId == store.me?.userId;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img != null)
              Image.memory(img, gaplessPlayback: true)
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            const SizedBox(height: 8),
            Text(DateFormat.yMMMMd('fr_FR').add_Hm().format(s.createdAt)),
          ],
        ),
        actions: [
          if (isMine)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _run(() => store.removeStory(s));
              },
              child: const Text('Supprimer'),
            ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _daysCard(BuildContext context) {
    final start = store.startDate;
    final theme = Theme.of(context);
    if (start == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('Depuis quand êtes-vous ensemble ?'),
          trailing: const Icon(Icons.edit_calendar),
          onTap: _pickDate,
        ),
      );
    }
    final now = DateTime.now();
    final total = daysBetween(start, now);
    final b = breakdown(start, now);
    return Card(
      child: ListTile(
        leading: Icon(Icons.favorite, color: theme.colorScheme.primary),
        title: Text('$total jour${total > 1 ? 's' : ''} ensemble',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('${b[0]} an(s), ${b[1]} mois, ${b[2]} jour(s)'),
        onTap: _pickDate,
      ),
    );
  }

  Widget _codeCard(BuildContext context) {
    final code = store.code ?? '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.key),
        title: Text('Code à entrer sur l\'autre téléphone : $code'),
        subtitle: const Text('Il disparaît dès que votre couple est complet.'),
        trailing: IconButton(
          tooltip: 'Copier',
          icon: const Icon(Icons.copy),
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
        ),
      ),
    );
  }

  Widget _person(BuildContext context, Profile? p, bool mine) {
    final scheme = Theme.of(context).colorScheme;
    final img = store.image(p?.photoPath);
    final status = p?.status ?? '';
    final String shown = status.isNotEmpty
        ? status
        : (p == null
            ? 'En attente de l\'autre'
            : (mine ? 'Touche pour écrire ton état' : ''));
    return SizedBox(
      width: 116,
      child: Column(
        children: [
          GestureDetector(
            onTap: mine ? _pickPhoto : null,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.primary, width: 3),
              ),
              child: ClipOval(
                child: img != null
                    ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
                    : Center(
                        child: Icon(mine ? Icons.add_a_photo : Icons.person,
                            color: scheme.primary)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: mine ? _editName : null,
            child: Text(p?.name ?? '...',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: mine ? _editStatus : null,
            child: Text(
              shown,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: status.isEmpty ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbles(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _person(context, store.me, true),
        Expanded(
          child: SizedBox(
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: DashPainter(scheme.primary),
                  size: Size.infinite,
                ),
                Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.favorite, size: 18, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
        _person(context, store.partner, false),
      ],
    );
  }

  Widget _grid(BuildContext context, bool mine) {
    final targetId = mine ? store.me?.userId : store.partner?.userId;
    final list = store.stories.where((s) => s.authorId == targetId).toList();
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Aucune story pour l\'instant.')),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3 / 4,
      children: [
        for (final s in list)
          GestureDetector(
            onTap: () => _view(s),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: store.image(s.imagePath) == null
                  ? Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Image.memory(store.image(s.imagePath)!,
                      fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final hasPartner = store.partner != null;
        final mine = _mine || !hasPartner;
        return RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              _daysCard(context),
              if (!hasPartner) _codeCard(context),
              const SizedBox(height: 24),
              _bubbles(context),
              const SizedBox(height: 16),
              Center(
                child: IconButton.filled(
                  tooltip: 'Dessiner une story',
                  iconSize: 32,
                  onPressed: _busy ? null : _draw,
                  icon: const Icon(Icons.add),
                ),
              ),
              const SizedBox(height: 24),
              if (hasPartner)
                Center(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                          value: true, label: Text(store.me?.name ?? 'Moi')),
                      ButtonSegment<bool>(
                          value: false, label: Text(store.partner!.name)),
                    ],
                    selected: {mine},
                    onSelectionChanged: (s) => setState(() => _mine = s.first),
                  ),
                ),
              const SizedBox(height: 12),
              _grid(context, mine),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: store.signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashPainter extends CustomPainter {
  DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset(math.min(x + 6, size.width), y), paint);
      x += 12;
    }
  }

  @override
  bool shouldRepaint(DashPainter oldDelegate) => oldDelegate.color != color;
}
