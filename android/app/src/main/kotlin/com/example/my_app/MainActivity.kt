package com.example.my_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterActivity() {
	private val channelName = "yuyu.auto_bookkeeping/channel"
	private val eventChannelName = "yuyu.auto_bookkeeping/events"
	private var eventSink: EventChannel.EventSink? = null

	private val recordReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context?, intent: Intent?) {
			if (intent?.action == NotificationListenerServiceBridge.ACTION_NEW_AUTO_RECORD) {
				eventSink?.success("new_record")
			}
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
			.setStreamHandler(object : EventChannel.StreamHandler {
				override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
					eventSink = events
				}

				override fun onCancel(arguments: Any?) {
					eventSink = null
				}
			})

		val filter = IntentFilter(NotificationListenerServiceBridge.ACTION_NEW_AUTO_RECORD)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			registerReceiver(recordReceiver, filter, RECEIVER_NOT_EXPORTED)
		} else {
			registerReceiver(recordReceiver, filter)
		}

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

	override fun onDestroy() {
		try {
			unregisterReceiver(recordReceiver)
		} catch (_: Exception) {
			// ignore
		}
		super.onDestroy()
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
