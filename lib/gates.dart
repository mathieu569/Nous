import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/events_screen.dart';
import 'screens/finished_screen.dart';
import 'screens/home_screen.dart';
import 'screens/now_screen.dart';
import 'screens/pair_screen.dart';
import 'screens/wishes_screen.dart';
import 'store.dart';

/// Pas connecté -> écran de connexion. Connecté -> on charge le couple.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final session = auth.currentSession;
        if (session == null) return const AuthScreen();
        return CoupleGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Charge les données. Pas encore de couple -> appairage. Sinon -> l'app.
class CoupleGate extends StatefulWidget {
  const CoupleGate({super.key});

  @override
  State<CoupleGate> createState() => _CoupleGateState();
}

class _CoupleGateState extends State<CoupleGate> with WidgetsBindingObserver {
  final AppStore _store = AppStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _store.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        if (!_store.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (_store.error != null && !_store.hasCouple) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Impossible de charger tes données.'),
                    const SizedBox(height: 8),
                    Text(_store.error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _store.refresh,
                        child: const Text('Réessayer')),
                    TextButton(
                        onPressed: _store.signOut,
                        child: const Text('Se déconnecter')),
                  ],
                ),
              ),
            ),
          );
        }
        if (!_store.hasCouple) return PairScreen(store: _store);
        return HomeShell(store: _store);
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(store: widget.store),
      EventsScreen(store: widget.store),
      NowScreen(store: widget.store),
      WishesScreen(store: widget.store),
      FinishedScreen(store: widget.store),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Nous'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Événements'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Du moment'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'Envies'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Finis'),
        ],
      ),
    );
  }
}
