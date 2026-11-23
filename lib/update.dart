import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Numéro de build, fixé par la compilation GitHub. 0 = non défini (site web, essai local).
const appBuild = int.fromEnvironment('APP_BUILD');

const apkUrl =
    'https://github.com/mathieu569/Nous/releases/download/apk-latest/nous.apk';
const _releaseApi =
    'https://api.github.com/repos/mathieu569/Nous/releases/tags/apk-latest';

/// Une mise à jour disponible : numéro de build et texte des nouveautés (peut être vide).
class UpdateInfo {
  UpdateInfo(this.build, this.notes);
  final int build;
  final String notes;
}

/// Renvoie la mise à jour disponible, ou null. Android uniquement, jamais d'erreur.
Future<UpdateInfo?> checkUpdate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || appBuild == 0) {
    return null;
  }
  try {
    final r = await http.get(Uri.parse(_releaseApi), headers: {
      'Accept': 'application/vnd.github+json',
    }).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final body = ((json.decode(utf8.decode(r.bodyBytes))['body'] as String?) ?? '')
        .replaceAll('\r', '');
    final m = RegExp(r'build (\d+)').firstMatch(body);
    if (m == null) return null;
    final build = int.parse(m.group(1)!);
    if (build <= appBuild) return null;
    final lines = body.split('\n');
    final notes = lines.skip(1).join('\n').trim();
    return UpdateInfo(build, notes);
  } catch (_) {
    return null;
  }
}
