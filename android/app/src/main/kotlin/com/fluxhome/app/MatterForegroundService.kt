package com.fluxhome.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Minimal foreground service that keeps the app process alive so that
 * Matter subscriptions and in-app automation rules continue to execute
 * even when the user has navigated away from the app.
 *
 * No logic lives here — the CHIP SDK, subscriptions, and rule evaluation
 * all run in the existing Flutter/Dart layer.  This service simply prevents
 * Android from terminating the process under memory pressure or background
 * process limits.
 *
 * Started from [MainActivity.onCreate] via [startForegroundService].
 * Returns [START_STICKY] so Android restarts it if it is ever killed.
 */
class MatterForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    // ── Notification ──────────────────────────────────────────────────────────

    private fun ensureNotificationChannel() {
        val mgr = getSystemService(NotificationManager::class.java)
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "Automations",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps device automations running in the background"
            setShowBadge(false)
        }
        mgr.createNotificationChannel(ch)
    }

    private fun buildNotification(): Notification {
        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Flux Home")
            .setContentText("Automations are active")
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        const val CHANNEL_ID       = "flux_automations"
        const val NOTIFICATION_ID  = 1001
    }
}
