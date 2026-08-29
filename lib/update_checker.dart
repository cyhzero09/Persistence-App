import 'dart:convert';
import 'package:http/http.dart' as http;

const String _githubRepo = 'cyhzero09/Persistence-App';
const String _apiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';

class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? errorCode; // 'fetch_failed' | 'empty_version' | 'check_failed'
  final String? errorDetail;
  final int? statusCode;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.errorCode,
    this.errorDetail,
    this.statusCode,
  });
}

Future<UpdateCheckResult> checkForUpdates(String currentVersion) async {
  try {
    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {'User-Agent': 'Persistence-App'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return UpdateCheckResult(hasUpdate: false, errorCode: 'fetch_failed', statusCode: response.statusCode);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String?;
    if (tagName == null || tagName.isEmpty) {
      return const UpdateCheckResult(hasUpdate: false, errorCode: 'empty_version');
    }
    final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
    return UpdateCheckResult(hasUpdate: hasUpdate, latestVersion: latestVersion);
  } catch (e) {
    return UpdateCheckResult(hasUpdate: false, errorCode: 'check_failed', errorDetail: e.toString());
  }
}

int _compareVersions(String a, String b) {
  final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (int i = 0; i < partsA.length || i < partsB.length; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}
