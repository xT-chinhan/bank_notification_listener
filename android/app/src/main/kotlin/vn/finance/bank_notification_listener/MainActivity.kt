package vn.finance.bank_notification_listener

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "vn.finance.notification_listener/methods"
    private val eventChannelName = "vn.finance.notification_listener/events"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerPermissionGranted())
                }
                "openPermissionSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    BankNotificationListenerService.eventSink = events
                    BankNotificationListenerService.flushPendingEvents()
                }

                override fun onCancel(arguments: Any?) {
                    BankNotificationListenerService.eventSink = null
                }
            }
        )
    }

    private fun isNotificationListenerPermissionGranted(): Boolean {
        try {
            val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
            if (enabledPackages.contains(packageName)) {
                return true
            }
        } catch (_: Exception) {
            // Fallback to Settings.Secure
        }

        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == packageName) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
