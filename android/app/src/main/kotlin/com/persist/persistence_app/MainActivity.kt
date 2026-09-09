package com.persist.persistence_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/persistence")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 强制用浏览器类应用打开 URL（CATEGORY_APP_BROWSER 只匹配浏览器，
                    // 避免被 GitHub 客户端的 App Links 接管）
                    "openInBrowser" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                .addCategory(Intent.CATEGORY_APP_BROWSER)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // 无可用的浏览器应用时回退给 Dart 侧 launchUrl 处理
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
