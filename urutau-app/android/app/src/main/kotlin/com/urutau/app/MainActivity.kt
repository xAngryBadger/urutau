package com.urutau.app

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.urutau.storage").setMethodCallHandler { call, result ->
      if (call.method == "getFreeSpace") {
        val path = call.argument<String>("path") ?: ""
        try {
          val statFs = StatFs(path)
          val freeBytes = statFs.availableBlocksLong * statFs.blockSizeLong
          result.success(freeBytes)
        } catch (e: Exception) {
          result.error("GET_FREE_SPACE_ERROR", e.message, null)
        }
      } else {
        result.notImplemented()
      }
    }
  }
}
