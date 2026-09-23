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
                    // 直达厂商「自启动 / 允许后台运行」设置页。
                    // 国产 ROM（ColorOS/MIUI/EMUI/OriginOS…）即使允许了电池优化，
                    // 没开自启动也会在划掉应用后冻结闹钟，导致提醒被推迟到下次打开应用。
                    // 返回 true 表示已跳到厂商页面，false 表示已退回应用详情页兜底。
                    "openAutoStartSettings" -> {
                        result.success(openAutoStartSettings())
                    }
                    // 应用详情页（厂商自启动页都跳不动时的兜底入口）
                    "openAppDetailsSettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    .setData(Uri.parse("package:$packageName"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAutoStartSettings(): Boolean {
        for (component in AUTO_START_COMPONENTS) {
            try {
                val parts = component.split("/")
                val intent = Intent().setComponent(
                    android.content.ComponentName(parts[0], parts[1])
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // 该机型没这个页面，继续试下一个
            }
        }
        // 兜底：跳到本应用的系统详情页，用户仍可在这里找到「自启动/后台运行」入口
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            false
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        // 各家 ROM 的「自启动 / 后台运行」页面，按品牌优先级排列
        private val AUTO_START_COMPONENTS = listOf(
            // OPPO / 一加 / realme (ColorOS)
            "com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe/com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.oplus.battery/com.oplus.powermanager.fuelgaue.PowerUsageModelActivity",
            "com.coloros.oppoguardelf/com.coloros.powermanager.fuelgaue.PowerUsageModelActivity",
            "com.oneplus.security/com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            // 小米 / 红米 (MIUI / HyperOS)
            "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.miui.securitycenter/com.miui.powercenter.PowerSettings",
            // 华为 / 荣耀
            "com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager/com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            "com.hihonor.systemmanager/com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.hihonor.systemmanager/com.hihonor.systemmanager.appcontrol.activity.StartupAppControlActivity",
            // vivo / iQOO (OriginOS / Funtouch)
            "com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure/com.iqoo.secure.safeguard.SoftPermissionDetailActivity",
            "com.vivo.permissionmanager/com.vivo.permissionmanager.activity.PurviewTabActivity",
            // 魅族
            "com.meizu.safe/com.meizu.safe.security.ShowAppSecActivity",
            // 三星
            "com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity",
            "com.samsung.android.sm_cn/com.samsung.android.sm.ui.battery.BatteryActivity",
            // 华硕 / 联想 / 乐视
            "com.asus.mobilemanager/com.asus.mobilemanager.autostart.AutoStartActivity",
            "com.asus.mobilemanager/com.asus.mobilemanager.powersaver.PowerSaverSettings",
            "com.lenovo.security/com.lenovo.security.purebackground.PureBackgroundActivity",
            "com.letv.android.letvsafe/com.letv.android.letvsafe.AutobootManageActivity",
        )
    }
}
