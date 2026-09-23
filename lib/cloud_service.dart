import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_version.dart';

/// 云端存档的元信息（用于设置页显示「上次备份」）。
class CloudBackupInfo {
  final DateTime updatedAt;
  final String? version;
  final int sizeBytes;

  const CloudBackupInfo({required this.updatedAt, this.version, required this.sizeBytes});
}

/// 云端操作失败。code 用于 UI 映射文案，detail 是原始错误详情。
class CloudException implements Exception {
  final String code;
  final String? detail;

  const CloudException(this.code, [this.detail]);

  @override
  String toString() => 'CloudException($code${detail == null ? '' : ', $detail'})';
}

/// Google 账号登录 + 云端存档（Firebase Auth + Firestore）。
///
/// 依赖 android/app/google-services.json：该文件不存在时 [init] 会失败并保持
/// [isReady] 为 false，设置页显示「云端未配置」，其余功能完全不受影响。
/// 不要在任何路径上因云端不可用而阻塞启动或写入。
class CloudService {
  static final CloudService _instance = CloudService._();
  factory CloudService() => _instance;
  CloudService._();

  bool _initAttempted = false;
  bool _firebaseReady = false;
  bool _googleReady = false;

  /// 云端功能是否可用（Firebase + Google 登录都初始化成功）
  bool get isReady => _firebaseReady && _googleReady;

  /// 当前登录用户，未登录为 null
  User? get user => _firebaseReady ? FirebaseAuth.instance.currentUser : null;

  /// 登录状态变化流；云端不可用时为 null
  Stream<User?>? get authChanges =>
      _firebaseReady ? FirebaseAuth.instance.authStateChanges() : null;

  /// 启动时调用。失败只降级不抛异常。
  Future<void> init() async {
    if (_initAttempted) return;
    _initAttempted = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase 初始化失败（通常是缺 android/app/google-services.json）: $e');
      return;
    }
    try {
      // 用 google-services.json 注册时不需要传 clientId/serverClientId，
      // 插件会自动读取其中 web OAuth client（client_type: 3）。
      await GoogleSignIn.instance.initialize();
      _googleReady = true;
    } catch (e) {
      debugPrint('Google 登录初始化失败: $e');
    }
  }

  /// 弹出 Google 账号选择并登录；用户取消时抛 CloudException('canceled')。
  Future<void> signIn() async {
    if (!isReady) throw const CloudException('notConfigured');
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const CloudException('noIdToken');
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on CloudException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const CloudException('canceled');
      }
      throw CloudException('signInFailed', '$e');
    } catch (e) {
      throw CloudException('signInFailed', '$e');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google 侧登出失败也要把 Firebase 登录态清掉
    }
    if (_firebaseReady) await FirebaseAuth.instance.signOut();
  }

  DocumentReference<Map<String, dynamic>> _backupDoc(String uid) =>
      FirebaseFirestore.instance.collection('backups').doc(uid);

  /// 上传存档。Firestore 单文档上限 1MB，超限提前给出明确错误。
  Future<void> uploadBackup(String json) async {
    final u = user;
    if (u == null) throw const CloudException('notSignedIn');
    if (json.length > 900 * 1024) {
      throw const CloudException('tooLarge', 'backup exceeds 900KB');
    }
    try {
      await _backupDoc(u.uid).set({
        'backup': json,
        'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
        'sizeBytes': json.length,
        'appVersion': appVersion,
      });
    } on FirebaseException catch (e) {
      throw CloudException('writeFailed', '${e.code}: ${e.message}');
    }
  }

  /// 读取云端存档元信息；没有备份时返回 null。
  Future<CloudBackupInfo?> fetchBackupInfo() async {
    final u = user;
    if (u == null) return null;
    try {
      final snap = await _backupDoc(u.uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final millis = data['updatedAtMillis'] as int?;
      if (millis == null) return null;
      return CloudBackupInfo(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(millis),
        version: data['appVersion'] as String?,
        sizeBytes: data['sizeBytes'] as int? ?? 0,
      );
    } on FirebaseException catch (e) {
      throw CloudException('readFailed', '${e.code}: ${e.message}');
    }
  }

  /// 下载云端存档 JSON，没有备份时返回 null。
  Future<String?> downloadBackup() async {
    final u = user;
    if (u == null) throw const CloudException('notSignedIn');
    try {
      final snap = await _backupDoc(u.uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return data['backup'] as String?;
    } on FirebaseException catch (e) {
      throw CloudException('readFailed', '${e.code}: ${e.message}');
    }
  }
}