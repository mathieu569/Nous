import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../utils.dart';

/// Création et modification d'un événement.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key, required this.store, this.event});
  final AppStore store;
  final CoupleEvent? event; // null = nouvel événement

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date; // date et heure
  late EventRepeat _repeat;
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _busy = false;

  bool get _isPast => _date.isBefore(DateTime.now());

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final now = DateTime.now();
    // Nouvel événement : demain à 12:00 par défaut.
    _date = e?.at ?? DateTime(now.year, now.month, now.day + 1, 12, 0);
    _repeat = e?.repeat ?? EventRepeat.none;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(Object e) {
    if (!mounted) return;
    final text = e is String ? e : errorText(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 20),
    );
    if (p != null) {
      setState(() => _date = DateTime(p.year, p.month, p.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (t != null) {
      setState(() =>
          _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
    }
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Écris un titre.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.saveEvent(
        id: widget.event?.id,
        title: title,
        at: _date,
        repeat: _repeat,
        note: _note.text.trim(),
        // La photo n'existe que pour un événement passé.
        newPhoto: _isPast ? _newPhoto : null,
        clearPhoto: !_isPast || _removePhoto,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.store.removeEvent(widget.event!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoSection(BuildContext context, Uint8List? shown) {
    if (!_isPast) {
      return Text(
        'La photo s\'ajoute une fois l\'événement passé.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shown != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(shown,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(shown == null ? 'Ajouter une photo' : 'Changer la photo'),
            ),
            if (shown != null)
              TextButton(
                onPressed: () => setState(() {
                  _newPhoto = null;
                  _removePhoto = true;
                }),
                child: const Text('Retirer'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.event;
    final oldPath = existing?.photoPath;
    final Uint8List? oldBytes = (oldPath != null && !_removePhoto && _newPhoto == null)
        ? widget.store.image(oldPath)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Nouvel événement' : 'Événement'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            icon: const Icon(Icons.check),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(
                labelText: 'Titre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat.yMMMd('fr_FR').format(_date)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(DateFormat.Hm('fr_FR').format(_date)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Répétition'),
          const SizedBox(height: 8),
          SegmentedButton<EventRepeat>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<EventRepeat>>[
              ButtonSegment<EventRepeat>(
                  value: EventRepeat.none, label: Text('Aucune')),
              ButtonSegment<EventRepeat>(
                  value: EventRepeat.weekly, label: Text('Semaine')),
              ButtonSegment<EventRepeat>(
                  value: EventRepeat.monthly, label: Text('Mois')),
              ButtonSegment<EventRepeat>(
                  value: EventRepeat.yearly, label: Text('Année')),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() => _repeat = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Note (facultatif)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          _photoSection(context, _newPhoto ?? oldBytes),
          if (existing != null) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer l\'événement'),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
