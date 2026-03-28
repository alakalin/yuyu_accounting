package com.example.my_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
	private val channelName = "yuyu.auto_bookkeeping/channel"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openNotificationListenerSettings" -> {
						val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					}

					"isNotificationListenerEnabled" -> {
						result.success(isNotificationServiceEnabled())
					}

					"fetchPendingAutoRecords" -> {
						val shared = getSharedPreferences(NotificationListenerServiceBridge.PREF_NAME, Context.MODE_PRIVATE)
						val data = shared.getString(NotificationListenerServiceBridge.KEY_PENDING_RECORDS, "[]") ?: "[]"
						shared.edit().putString(NotificationListenerServiceBridge.KEY_PENDING_RECORDS, "[]").apply()
						result.success(data)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun isNotificationServiceEnabled(): Boolean {
		val pkgName = packageName
		val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
		val names = flat.split(":")
		for (name in names) {
			val componentName = ComponentName.unflattenFromString(name)
			if (componentName != null && componentName.packageName == pkgName) {
				return true
			}
		}
		return false
	}
}
