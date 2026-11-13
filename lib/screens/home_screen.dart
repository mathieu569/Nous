import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart';
import 'draw_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _owner = 0; // story affichée dans l'historique

  AppStore get store => widget.store;

  Future<void> _pickDate() async {
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

  Future<void> _pickPhoto(int i) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (x == null) return;
    final Uint8List bytes = await x.readAsBytes();
    await store.updatePerson(i, photo: bytes);
  }

  Future<void> _editStatus(int i) async {
    final t = await askText(context, 'Ton état du moment', store.persons[i].status);
    if (t != null) await store.updatePerson(i, status: t);
  }

  Future<void> _editName(int i) async {
    final t = await askText(context, 'Prénom', store.persons[i].name);
    if (t != null) await store.updatePerson(i, name: t);
  }

  Future<void> _draw() async {
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const DrawScreen()),
    );
    if (bytes == null || !mounted) return;
    final owner = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('Enregistrer dans la story de'),
        children: [
          for (var i = 0; i < 2; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(store.persons[i].name),
            ),
        ],
      ),
    );
    if (owner == null) return;
    await store.addStory(owner, bytes);
    setState(() => _owner = owner);
  }

  Future<void> _view(Story s) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(s.png, gaplessPlayback: true),
            const SizedBox(height: 8),
            Text(DateFormat.yMMMMd('fr_FR').add_Hm().format(s.at)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              store.removeStory(s.id);
              Navigator.pop(ctx);
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

  Widget _person(BuildContext context, int i) {
    final p = store.persons[i];
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 116,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickPhoto(i),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.primary, width: 3),
              ),
              child: ClipOval(
                child: p.photo == null
                    ? Center(
                        child: Icon(Icons.add_a_photo, color: scheme.primary))
                    : Image.memory(p.photo!,
                        fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _editName(i),
            child: Text(p.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _editStatus(i),
            child: Text(
              p.status.isEmpty ? 'Touche pour écrire ton état' : p.status,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: p.status.isEmpty ? Colors.grey : null,
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
        _person(context, 0),
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
        _person(context, 1),
      ],
    );
  }

  Widget _grid(BuildContext context) {
    final list = store.stories.where((s) => s.owner == _owner).toList();
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
              child: Image.memory(s.png, fit: BoxFit.cover, gaplessPlayback: true),
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _daysCard(context),
            const SizedBox(height: 24),
            _bubbles(context),
            const SizedBox(height: 16),
            Center(
              child: IconButton.filled(
                tooltip: 'Dessiner une story',
                iconSize: 32,
                onPressed: _draw,
                icon: const Icon(Icons.add),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < 2; i++)
                    ButtonSegment<int>(value: i, label: Text(store.persons[i].name)),
                ],
                selected: {_owner},
                onSelectionChanged: (s) => setState(() => _owner = s.first),
              ),
            ),
            const SizedBox(height: 12),
            _grid(context),
          ],
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
