package com.chinhan.xt_manager

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Collections
import java.util.UUID

class NotificationMonitorService : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "bank_notifications_storage"
        const val KEY_SAVED_NOTIFICATIONS = "saved_notifications"
        const val MAX_SAVED_ITEMS = 300

        private const val CHANNEL_ID = "bank_notification_monitor_channel"
        private const val CHANNEL_NAME = "Lắng nghe thông báo ngân hàng"
        private const val FOREGROUND_NOTIFICATION_ID = 9901

        var eventSink: EventChannel.EventSink? = null
            set(value) {
                field = value
                if (value != null) {
                    flushPendingEvents()
                }
            }

        val pendingEvents: MutableList<Map<String, Any>> = Collections.synchronizedList(mutableListOf())
        private val mainHandler = Handler(Looper.getMainLooper())

        fun flushPendingEvents() {
            mainHandler.post {
                val sink = eventSink ?: return@post
                synchronized(pendingEvents) {
                    val iterator = pendingEvents.iterator()
                    while (iterator.hasNext()) {
                        val event = iterator.next()
                        try {
                            sink.success(event)
                            iterator.remove()
                        } catch (_: Exception) {
                            break
                        }
                    }
                }
            }
        }

        fun saveNotificationLocally(context: Context, eventMap: Map<String, Any>) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val jsonStr = prefs.getString(KEY_SAVED_NOTIFICATIONS, "[]") ?: "[]"
                val existingArray = JSONArray(jsonStr)

                val notifObj = JSONObject()
                for ((key, value) in eventMap) {
                    notifObj.put(key, value)
                }

                val newArray = JSONArray()
                newArray.put(notifObj)
                val limit = Math.min(existingArray.length(), MAX_SAVED_ITEMS - 1)
                for (i in 0 until limit) {
                    newArray.put(existingArray.getJSONObject(i))
                }

                prefs.edit().putString(KEY_SAVED_NOTIFICATIONS, newArray.toString()).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun getStoredNotifications(context: Context): List<Map<String, Any>> {
            val result = mutableListOf<Map<String, Any>>()
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val jsonStr = prefs.getString(KEY_SAVED_NOTIFICATIONS, "[]") ?: "[]"
                val jsonArray = JSONArray(jsonStr)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val map = mutableMapOf<String, Any>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = obj.get(key)
                    }
                    result.add(map)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return result
        }

        fun clearStoredNotifications(context: Context) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().remove(KEY_SAVED_NOTIFICATIONS).apply()
                synchronized(pendingEvents) {
                    pendingEvents.clear()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureForegroundService()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureForegroundService()
        return START_STICKY
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        ensureForegroundService()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        // Auto-rebind to avoid silent disconnects by Android OS or Battery Savers
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                requestRebind(ComponentName(this, NotificationMonitorService::class.java))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Keep the foreground notification alive when user swipes app from Recent Apps
        ensureForegroundService()
    }

    private fun ensureForegroundService() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && notificationManager != null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Dịch vụ chạy ngầm duy trì lắng nghe biến động số dư ngân hàng 24/7"
                    setShowBadge(false)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("chinhan-xT đang hoạt động ngầm")
                .setContentText("Đang lắng nghe biến động số dư ngân hàng & ví điện tử 24/7")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(pendingIntent)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(FOREGROUND_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(FOREGROUND_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: ""
        // Do not process own notifications (prevent infinite loops with our own foreground status)
        if (packageName == applicationContext.packageName) {
            return
        }

        val extras = sbn.notification?.extras
        var title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            ?: extras?.getString(Notification.EXTRA_TITLE)
            ?: ""
        val titleBig = extras?.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()
        if (!titleBig.isNullOrEmpty() && title.isEmpty()) {
            title = titleBig
        }

        var text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        if (bigText != null && (text.isEmpty() || bigText.length > text.length)) {
            text = bigText
        }

        val subText = extras?.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
            ?: extras?.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()
            ?: ""
        val postTime = sbn.postTime

        if (title.isEmpty() && text.isEmpty()) {
            return
        }

        val eventMap: Map<String, Any> = mapOf(
            "id" to UUID.randomUUID().toString(),
            "packageName" to packageName,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "postTime" to postTime,
            "timestamp" to postTime
        )

        // 1. Always persist to disk so notifications are NEVER lost when app is closed / killed
        saveNotificationLocally(applicationContext, eventMap)

        // 2. Dispatch to live UI if FlutterEngine is currently active
        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                try {
                    sink.success(eventMap)
                } catch (_: Exception) {
                    pendingEvents.add(eventMap)
                }
            } else {
                pendingEvents.add(eventMap)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
