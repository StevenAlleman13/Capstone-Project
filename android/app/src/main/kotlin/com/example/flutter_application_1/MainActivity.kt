package com.example.flutter_application_1

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lockin/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasUsageStatsPermission") {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        packageName
                    )
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lockin/monitor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitorService" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        val limitMinutes = call.argument<Int>("limitMinutes") ?: 120
                        val serviceIntent = Intent(this, AppMonitorService::class.java).apply {
                            putStringArrayListExtra(AppMonitorService.EXTRA_PACKAGES, ArrayList(packages))
                            putExtra(AppMonitorService.EXTRA_LIMIT_MINUTES, limitMinutes)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    }
                    "stopMonitorService" -> {
                        stopService(Intent(this, AppMonitorService::class.java))
                        result.success(null)
                    }
                    "hasOverlayPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            Settings.canDrawOverlays(this)
                        else
                            true
                        result.success(granted)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
