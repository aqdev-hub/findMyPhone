package com.findmyphone.find_my_phone

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmForegroundService : Service() {
    private var player: MediaPlayer? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 10, launchIntent, PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, "emergency_alarm")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("إنذار الطوارئ")
            .setContentText("تم تشغيل الإنذار عبر SMS.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()
        startForeground(101, notification)
        startSound()
        vibrate()
        return START_STICKY
    }

    override fun onDestroy() {
        player?.stop()
        player?.release()
        player = null
        // The vibration pattern loops forever (repeat index 0), so it must be
        // explicitly cancelled here — otherwise the phone keeps vibrating even
        // after the alarm sound and foreground notification are gone.
        try {
            getSystemService(Vibrator::class.java)?.cancel()
        } catch (_: Exception) {
            // Best-effort: never let a vibrator issue block service teardown
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startSound() {
        if (player != null) return
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        player = MediaPlayer().apply {
            setDataSource(applicationContext, uri)
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            isLooping = true
            prepare()
            start()
        }
    }

    private fun vibrate() {
        val vibrator = getSystemService(Vibrator::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 400, 800), 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0, 800, 400, 800), 0)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("emergency_alarm", "Emergency alarm", NotificationManager.IMPORTANCE_HIGH)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
