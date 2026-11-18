import 'package:flutter/material.dart';

import '../store.dart';
import '../utils.dart';

/// Premier lancement : créer l'espace du couple, ou le rejoindre avec un code.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _message = 'Écris d\'abord ton prénom.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bienvenue',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Ton prénom', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tu es le premier ?'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() =>
                            widget.store.createCouple(_name.text.trim())),
                    child: const Text('Créer notre espace'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  const Text('Ton/ta partenaire a déjà créé l\'espace ?'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Code à 6 caractères',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.store
                            .joinCouple(_code.text.trim(), _name.text.trim())),
                    child: const Text('Rejoindre avec le code'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.store.signOut,
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
