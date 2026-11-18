import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Identifiants publics par conception (ils identifient le projet Firebase, ils ne donnent aucun accès).
// La clé privée du compte de service n'est JAMAIS ici : elle vit dans les secrets Supabase.

const vapidKey =
    'BIp0WWH0r-VEigECJC_z4J2bnqSsA2tOb2sCDIw6c0fhcKhMrqNVfFu_VRe8xhHklI86YnzhO3IKWb8Lyi5KpuY';

FirebaseOptions firebaseOptions() {
  if (kIsWeb) {
    return FirebaseOptions(
      apiKey: 'AIzaSyBk7DRybY7ygbCoxdHymYs1MQ9sxGdLrMs',
      authDomain: 'nous-2a440.firebaseapp.com',
      projectId: 'nous-2a440',
      storageBucket: 'nous-2a440.firebasestorage.app',
      messagingSenderId: '106684109373',
      appId: '1:106684109373:web:b8cd700c2f2fba3727d054',
    );
  }
  return FirebaseOptions(
    apiKey: 'AIzaSyCxAhy6xc23CVoZ0A0H0FuMfszsCa72Bz8',
    appId: '1:106684109373:android:7a9b75f6712475c927d054',
    messagingSenderId: '106684109373',
    projectId: 'nous-2a440',
    storageBucket: 'nous-2a440.firebasestorage.app',
  );
}
