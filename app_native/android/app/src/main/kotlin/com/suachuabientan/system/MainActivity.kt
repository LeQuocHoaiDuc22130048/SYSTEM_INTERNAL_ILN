package com.suachuabientan.system

import android.os.SystemClock
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "attendance/device_clock")
            .setMethodCallHandler { call, result ->
                if (call.method == "snapshot") {
                    val boot = try { Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT) } catch (_: Exception) { -1 }
                    result.success(mapOf("elapsedRealtimeMillis" to SystemClock.elapsedRealtime(), "bootCount" to boot,
                        "model" to "${Build.MANUFACTURER} ${Build.MODEL}", "osVersion" to Build.VERSION.RELEASE))
                } else result.notImplemented()
            }
    }
}
