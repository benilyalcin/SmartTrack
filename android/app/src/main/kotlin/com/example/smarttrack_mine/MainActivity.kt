package com.example.smarttrack_mine

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.smarttrack/background_service"
    private val storageChannelName = "com.smarttrack/public_storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startServiceWithAction(TachographConnectionService.ACTION_START)
                    result.success(null)
                }
                "stop" -> {
                    // Re-invoking the foreground-service start path (rather than a
                    // plain startService) even to deliver the stop action: it's the
                    // only start mechanism Android allows unconditionally from a
                    // background context on API 26+, and it's idempotent — the
                    // service's own onStartCommand handles ACTION_STOP by calling
                    // stopForeground()/stopSelf() right away.
                    startServiceWithAction(TachographConnectionService.ACTION_STOP)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Writes straight into the shared Documents/SmartTrack/<subfolder>
        // MediaStore collection — genuinely visible in the Files app the
        // instant this returns, no Storage Access Framework picker, no
        // WRITE_EXTERNAL_STORAGE permission needed (scoped storage lets any
        // app *add* files to MediaStore's own collections on API 29+; this
        // app's minSdk is below that, so [saveToDocuments] falls back to
        // legacy public-directory writes there instead — see its comment).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDocuments" -> {
                    val fileName = call.argument<String>("fileName")
                    val subfolder = call.argument<String>("subfolder")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (fileName == null || subfolder == null || bytes == null) {
                        result.error("bad_args", "fileName/subfolder/bytes required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val path = saveToDocuments(fileName, subfolder, bytes)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Inserts [bytes] as a new entry in the MediaStore Documents collection
     * under `Documents/SmartTrack/<subfolder>/<fileName>` (API 29+). There's
     * no dedicated `MediaStore.Documents` class (only Images/Video/Audio/
     * Downloads get their own typed collection) — the generic
     * `MediaStore.Files` collection plus a `RELATIVE_PATH` of
     * `Environment.DIRECTORY_DOCUMENTS` is the documented way to land a file
     * under the Documents tree instead. Falls back to the legacy
     * world-writable public Documents directory on older devices (works
     * down to API 21 without a runtime permission prompt as long as the app
     * declares WRITE_EXTERNAL_STORAGE with maxSdkVersion=28, since that
     * grant is install-time only pre-API 23 and this app's minSdk covers
     * both cases already).
     */
    private fun saveToDocuments(fileName: String, subfolder: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Files.FileColumns.DISPLAY_NAME, fileName)
                put(MediaStore.Files.FileColumns.MIME_TYPE, "application/octet-stream")
                put(
                    MediaStore.Files.FileColumns.RELATIVE_PATH,
                    "${android.os.Environment.DIRECTORY_DOCUMENTS}/SmartTrack/$subfolder",
                )
                put(MediaStore.Files.FileColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Files.getContentUri("external"), values)
                ?: throw IllegalStateException("MediaStore insert() returned null")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open output stream for $uri")
            values.clear()
            values.put(MediaStore.Files.FileColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }

        @Suppress("DEPRECATION")
        val dir = java.io.File(
            android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOCUMENTS),
            "SmartTrack/$subfolder",
        )
        if (!dir.exists()) dir.mkdirs()
        val file = java.io.File(dir, fileName)
        file.writeBytes(bytes)
        return file.absolutePath
    }

    private fun startServiceWithAction(action: String) {
        // Defense in depth alongside TachographConnectionService's own
        // startForeground() call: on Android 12+, BLUETOOTH_CONNECT is a
        // runtime permission the OS can revoke at any time (including as
        // part of resetting an app's data/storage) — starting the
        // FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE service without it held
        // makes startForeground() throw, and Android's "did you call
        // startForeground() in time" watchdog kills the whole app process
        // over that regardless of any try/catch. Skipping the call entirely
        // when the permission isn't currently held keeps this strictly a
        // "nice-to-have that degrades quietly" as intended, for both the
        // start and stop actions.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w("MainActivity", "BLUETOOTH_CONNECT not held, skipping foreground keep-alive service (action=$action)")
            return
        }

        val intent = Intent(this, TachographConnectionService::class.java).apply {
            this.action = action
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            // The background keep-alive is a nice-to-have, not something a
            // pairing attempt should ever be allowed to crash over — e.g.
            // IllegalStateException (app fully backgrounded, nothing left
            // to redeliver to), SecurityException (a required permission
            // wasn't actually held at this exact instant), or the OS
            // refusing a foreground-service start it considers too late.
            // Bluetooth itself is unaffected either way; just log and move on.
            Log.w("MainActivity", "Background keep-alive service start failed for action=$action", e)
        }
    }
}
