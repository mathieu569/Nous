import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Numéro de build, fixé par la compilation GitHub. 0 = non défini (site web, essai local).
const appBuild = int.fromEnvironment('APP_BUILD');

const apkUrl =
    'https://github.com/mathieu569/Nous/releases/download/apk-latest/nous.apk';
const _releaseApi =
    'https://api.github.com/repos/mathieu569/Nous/releases/tags/apk-latest';

/// Vrai si une APK plus récente est publiée. Android uniquement, jamais d'erreur.
Future<bool> updateAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || appBuild == 0) {
    return false;
  }
  try {
    final r = await http.get(Uri.parse(_releaseApi), headers: {
      'Accept': 'application/vnd.github+json',
    }).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return false;
    final body = (json.decode(utf8.decode(r.bodyBytes))['body'] as String?) ?? '';
    final m = RegExp(r'build (\d+)').firstMatch(body);
    return m != null && int.parse(m.group(1)!) > appBuild;
  } catch (_) {
    return false;
  }
}
