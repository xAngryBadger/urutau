package com.urutau.app

import android.content.ContentValues
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.urutau.storage").setMethodCallHandler { call, result ->
      if (call.method == "getFreeSpace") {
        // O Dart envia o path como argumento cru (String), não como Map.
        // `call.argument<T>(...)` faz cast de `arguments` para Map e rebenta
        // com ClassCastException quando o payload não é um Map. Por isso
        // le-se `call.arguments` diretamente e aceita-se qualquer forma.
        val path: String = when (val args = call.arguments) {
          is String -> args
          is Map<*, *> -> args["path"] as? String ?: ""
          else -> ""
        }
        try {
          val statFs = StatFs(path)
          val freeBytes = statFs.availableBlocksLong * statFs.blockSizeLong
          // Long do Java: o StandardMessageCodec converte para int do Dart.
          result.success(freeBytes)
        } catch (e: Exception) {
          result.error("GET_FREE_SPACE_ERROR", e.message, null)
        }
      } else {
        result.notImplemented()
      }
    }
    // t19 fase 2: grava o ZIP de backup automático em Downloads/Urutau via
    // MediaStore — FORA do sandbox do app (sobrevive à desinstalação).
    // Android 10+: contribuir para MediaStore.Downloads não pede permissão.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.urutau.backup").setMethodCallHandler { call, result ->
      if (call.method == "saveToDownloads") {
        try {
          val fileName = call.argument<String>("fileName") ?: "backup.zip"
          val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
          val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/zip")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Urutau/")
            put(MediaStore.Downloads.IS_PENDING, 1)
          }
          val resolver = applicationContext.contentResolver
          val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw Exception("insert Downloads retornou null")
          resolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw Exception("openOutputStream retornou null")
          values.clear()
          values.put(MediaStore.Downloads.IS_PENDING, 0)
          resolver.update(uri, values, null, null)
          result.success(uri.toString())
        } catch (e: Exception) {
          result.error("SAVE_TO_DOWNLOADS_ERROR", e.message, null)
        }
      } else {
        result.notImplemented()
      }
    }
  }
}
