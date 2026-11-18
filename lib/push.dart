import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_config.dart';

/// Notifications push (Firebase Cloud Messaging).
/// L'envoi se fait côté Supabase (fonction "notify-status"), ici on gère seulement la réception.
class PushService {
  static bool _ready = false;
  static bool _listening = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: firebaseOptions());
      _ready = true;
    } catch (_) {
      _ready = false; // l'appli marche quand même, sans notifications
    }
  }

  /// Vrai si l'autorisation est déjà donnée sur cet appareil.
  static Future<bool> isEnabled() async {
    if (!_ready) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  /// À appeler depuis un clic (obligatoire sur iPhone). Renvoie un message d'erreur, ou null si OK.
  static Future<String?> enable() async {
    if (!_ready) return 'Notifications indisponibles sur cet appareil.';
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      if (s.authorizationStatus != AuthorizationStatus.authorized) {
        return kIsWeb
            ? 'Autorisation refusée. Sur iPhone, ouvre l\'appli depuis l\'icône de l\'écran d\'accueil.'
            : 'Autorisation refusée. Active les notifications dans les réglages du téléphone.';
      }
      await register();
      return null;
    } catch (e) {
      return kIsWeb
          ? 'Impossible d\'activer. Sur iPhone, ouvre l\'appli depuis l\'icône de l\'écran d\'accueil. ($e)'
          : 'Impossible d\'activer : $e';
    }
  }

  /// Envoie le jeton de cet appareil à Supabase pour qu'il puisse nous notifier.
  static Future<void> register() async {
    if (!_ready) return;
    final m = FirebaseMessaging.instance;
    final token = await m.getToken(vapidKey: kIsWeb ? vapidKey : null);
    if (token == null) return;
    await _save(token);
    if (!_listening) {
      _listening = true;
      m.onTokenRefresh.listen(_save);
    }
  }

  static Future<void> _save(String token) async {
    try {
      await Supabase.instance.client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': kIsWeb ? 'web' : 'android',
      });
    } catch (_) {}
  }
}
