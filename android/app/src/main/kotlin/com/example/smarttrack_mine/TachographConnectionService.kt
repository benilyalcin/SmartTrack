package com.example.smarttrack_mine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Minimal foreground service whose only job is to keep this app's process
 * alive while a real tachograph Bluetooth connection is active, so Android's
 * background execution limits (Doze / App Standby / process death when the
 * task is swiped from Recents) don't silently kill the live K-LINE socket
 * that lives in the Flutter engine's Dart isolate.
 *
 * It does no Bluetooth work itself — the actual connection is owned by the
 * `flutter_classic_bluetooth`/`flutter_blue_plus` plugins running in the
 * same process. This service exists purely to satisfy Android's contract
 * for long-running background work: show the user an ongoing notification
 * ("bağlantı arka planda aktif") and Android will let the process keep
 * running until [ACTION_STOP] is sent (on disconnect) or the user force-
 * stops the app.
 *
 * IMPORTANT: this is a nice-to-have that must never take the whole app down
 * with it. `startForeground()` with `FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE`
 * can throw (e.g. `SecurityException` if `BLUETOOTH_CONNECT` isn't held at
 * that exact instant on Android 14+, or `ForegroundServiceStartNotAllowedException`
 * if the OS decides the start came too late) — an uncaught exception here
 * would crash the entire process, which would look to the driver exactly
 * like "pairing kicked me out of the app". Every path below is wrapped so a
 * failure here just quietly gives up on the background keep-alive instead.
 *
 * Started/stopped from Dart via [MainActivity]'s `com.smarttrack/background_service`
 * MethodChannel — see `lib/core/services/background_keepalive_service.dart`.
 */
class TachographConnectionService : Service() {

    companion object {
        const val ACTION_START = "com.example.smarttrack_mine.action.START"
        const val ACTION_STOP = "com.example.smarttrack_mine.action.STOP"
        private const val CHANNEL_ID = "tachograph_connection_channel"
        private const val NOTIFICATION_ID = 4201
        private const val TAG = "TachographConnSvc"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // MainActivity.startServiceWithAction() calls Context
        // .startForegroundService() for *both* START and STOP (see its own
        // comment on why: it's the only start mechanism Android allows
        // unconditionally from a background context on API 26+). Every such
        // call obligates this service to call startForeground() within
        // ~5 seconds, *regardless* of which action was actually requested —
        // the previous version only did that on the START path, so a STOP
        // (or a START whose own startForeground() call threw, e.g.
        // SecurityException from a momentarily-missing BLUETOOTH_CONNECT
        // grant right after a storage clear) left that promise unfulfilled.
        // Android does not forgive this with a catchable exception on our
        // side — it kills the entire app process with a
        // ForegroundServiceDidNotStartInTimeException that no try/catch
        // anywhere in the app (Kotlin or Dart) can intercept. So: always
        // call startForeground() first, unconditionally, then immediately
        // stop again if that's what was actually asked for.
        try {
            startAsForeground()
        } catch (e: Exception) {
            Log.w(TAG, "startForeground() failed, keep-alive unavailable this run", e)
            try {
                stopSelf()
            } catch (_: Exception) {
            }
            return START_STICKY
        }

        if (intent?.action == ACTION_STOP) {
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            } catch (e: Exception) {
                Log.w(TAG, "stopForeground()/stopSelf() failed", e)
            }
        }
        return START_STICKY
    }

    private fun startAsForeground() {
        createNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val contentIntent = try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                PendingIntent.getActivity(
                    this,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            } else null
        } catch (e: Exception) {
            null
        }

        val smallIcon = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.stat_notify_sync

        val builder = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("SmartTrack")
            .setContentText("Takograf bağlantısı arka planda aktif")
            .setSmallIcon(smallIcon)
            .setOngoing(true)
        if (contentIntent != null) {
            builder.setContentIntent(contentIntent)
        }
        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Takograf Bağlantısı",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Takograf Bluetooth bağlantısı arka planda aktifken gösterilir."
        }
        manager.createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
