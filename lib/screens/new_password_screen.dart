import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';

/// Choix d'un nouveau mot de passe. [recovery] : arrivé par le lien email (pas de retour possible).
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.recovery, required this.onDone});
  final bool recovery;
  final VoidCallback onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_p1.text.length < 6) {
      setState(() => _error = 'Mot de passe trop court (6 caractères minimum).');
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() => _error = 'Les deux mots de passe sont différents.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _p1.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mot de passe changé.')));
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recovery ? 'Nouveau mot de passe' : 'Changer mon mot de passe'),
        automaticallyImplyLeading: !widget.recovery,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _p1,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _p2,
                  obscureText: true,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                      labelText: 'Confirme le mot de passe',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Enregistrer'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
