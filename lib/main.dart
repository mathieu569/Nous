import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'gates.dart';
import 'push.dart';
import 'recovery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  // Le lien du mot de passe oublié arrive sur le site avec "type=recovery" dans l'adresse.
  startedInRecovery = Uri.base.toString().contains('type=recovery');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    // "implicit" : le lien de l'email marche même ouvert dans un autre navigateur ou appareil.
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  await PushService.init();
  runApp(const NousApp());
}

class NousApp extends StatelessWidget {
  const NousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nous',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE0566F)),
      ),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
      // L'adresse du lien email contient un fragment inconnu : on ouvre toujours l'accueil.
      onGenerateInitialRoutes: (_) =>
          [MaterialPageRoute<void>(builder: (_) => const AuthGate())],
    );
  }
}
