import 'package:http/http.dart' as http;

const String _githubRepo = 'cyhzero09/Persistence-App';
const String _versionUrl = 'https://raw.githubusercontent.com/$_githubRepo/main/version.txt';

class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? error;

  const UpdateCheckResult({required this.hasUpdate, this.latestVersion, this.error});
}

Future<UpdateCheckResult> checkForUpdates(String currentVersion) async {
  try {
    final response = await http.get(Uri.parse(_versionUrl)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return const UpdateCheckResult(hasUpdate: false, error: '無法獲取版本資訊');
    }
    final latestVersion = response.body.trim();
    if (latestVersion.isEmpty) {
      return const UpdateCheckResult(hasUpdate: false, error: '版本資訊為空');
    }
    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
    return UpdateCheckResult(hasUpdate: hasUpdate, latestVersion: latestVersion);
  } catch (e) {
    return UpdateCheckResult(hasUpdate: false, error: '檢查更新失敗：$e');
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
