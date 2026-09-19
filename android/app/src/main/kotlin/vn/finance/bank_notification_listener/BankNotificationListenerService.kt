package vn.finance.bank_notification_listener

import android.app.Notification
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel
import java.util.Collections

class BankNotificationListenerService : NotificationListenerService() {

    companion object {
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
                        sink.success(event)
                        iterator.remove()
                    }
                }
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val extras = sbn.notification?.extras
        val packageName = sbn.packageName ?: ""
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

        val eventMap: Map<String, Any> = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "postTime" to postTime
        )

        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                sink.success(eventMap)
            } else {
                pendingEvents.add(eventMap)
            }
        }
    }
}
