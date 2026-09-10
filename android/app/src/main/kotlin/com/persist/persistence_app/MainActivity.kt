package com.persist.persistence_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
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
                    // 是否已在电池优化白名单中
                    "isIgnoringBatteryOptimization" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    // 弹出系统"忽略电池优化"请求对话框（需声明 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS）
                    "requestIgnoreBatteryOptimization" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                )
                                startActivity(intent)
                            }
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
