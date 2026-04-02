package com.example.flutter_application_1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat
import java.util.Calendar
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class AppMonitorService : Service() {

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var scheduledFuture: ScheduledFuture<*>? = null
    private var lastLockTime = 0L
    private var screenOn = true
    private var overlayView: FrameLayout? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> pausePolling()
                Intent.ACTION_SCREEN_ON  -> resumePolling()
            }
        }
    }

    companion object {
        const val CHANNEL_ID = "lockin_monitor"
        const val EXTRA_PACKAGES = "selected_packages"
        const val EXTRA_LIMIT_MINUTES = "limit_minutes"

        @Volatile var selectedPackages: Set<String> = emptySet()
        @Volatile var limitMinutes: Int = 120
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(1, buildNotification())

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        screenOn = pm.isInteractive
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packages = intent?.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf()
        val limit = intent?.getIntExtra(EXTRA_LIMIT_MINUTES, 120) ?: 120
        selectedPackages = packages.toSet()
        limitMinutes = limit

        scheduledFuture?.cancel(false)
        scheduledFuture = executor.scheduleAtFixedRate(::checkForegroundApp, 0, 1, TimeUnit.SECONDS)

        return START_STICKY
    }

    private fun pausePolling() {
        screenOn = false
        scheduledFuture?.cancel(false)
        scheduledFuture = null
    }

    private fun resumePolling() {
        screenOn = true
        if (scheduledFuture == null || scheduledFuture!!.isCancelled) {
            scheduledFuture = executor.scheduleAtFixedRate(::checkForegroundApp, 0, 1, TimeUnit.SECONDS)
        }
    }

    private fun checkForegroundApp() {
        if (!screenOn || selectedPackages.isEmpty()) return

        val now = System.currentTimeMillis()
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val events = usm.queryEvents(now - 3000, now)
        var foreground: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                foreground = event.packageName
            }
        }

        // Dismiss overlay if user navigated away from the restricted app
        if (overlayView != null) {
            if (foreground != null && foreground !in selectedPackages) {
                dismissOverlay()
            }
            return
        }

        if (now - lastLockTime < 3000) return

        foreground ?: return
        if (foreground == packageName) return
        if (foreground !in selectedPackages) return

        val startOfDay = getStartOfDay()
        val dailyStats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startOfDay,
            now
        ) ?: return

        val totalMs = dailyStats.sumOf { it.totalTimeInForeground }
        val usedMinutes = totalMs / 1000 / 60

        if (usedMinutes >= limitMinutes) {
            lastLockTime = now
            showOverlay()
        }
    }

    private fun showOverlay() {
        if (overlayView != null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        mainHandler.post {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.OPAQUE
            )

            val layout = FrameLayout(this)
            layout.setBackgroundColor(Color.BLACK)

            val button = Button(this).apply {
                text = "Close Application"
                setTextColor(Color.WHITE)
                setBackgroundColor(Color.TRANSPARENT)
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER
                )
                setOnClickListener {
                    dismissOverlay()
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(homeIntent)
                }
            }

            layout.addView(button)
            wm.addView(layout, params)
            overlayView = layout
        }
    }

    private fun dismissOverlay() {
        mainHandler.post {
            overlayView?.let {
                try {
                    val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                    wm.removeView(it)
                } catch (_: Exception) {}
                overlayView = null
            }
        }
    }

    private fun getStartOfDay(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LockIn Active")
            .setContentText("Monitoring your screen time")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "LockIn Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors selected app usage in the background"
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        dismissOverlay()
        unregisterReceiver(screenReceiver)
        scheduledFuture?.cancel(true)
        executor.shutdown()
        super.onDestroy()
    }
}
