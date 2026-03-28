package com.example.my_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class NotificationListenerServiceBridge : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        // Only parse notifications from WeChat and Alipay.
        if (pkg != "com.tencent.mm" && pkg != "com.eg.android.AlipayGphone") return

        val extras = sbn.notification.extras
        val title = extras?.getString("android.title") ?: ""
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras?.getCharSequence("android.bigText")?.toString() ?: ""
        val content = listOf(title, text, bigText).joinToString(" ")

        val amount = extractAmount(content) ?: return
        val type = if (isIncome(content)) 1 else 0
        val category = inferCategory(content, type)

        val record = JSONObject().apply {
            put("amount", amount)
            put("type", type)
            put("category", category)
            put("note", "${if (pkg == "com.tencent.mm") "微信" else "支付宝"}通知自动识别: $title $text")
            put("timestamp", System.currentTimeMillis())
            put("sourceApp", pkg)
        }

        appendRecord(record)
    }

    private fun appendRecord(record: JSONObject) {
        val shared = getSharedPreferences(PREF_NAME, MODE_PRIVATE)
        val raw = shared.getString(KEY_PENDING_RECORDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        array.put(record)
        shared.edit().putString(KEY_PENDING_RECORDS, array.toString()).apply()
    }

    private fun extractAmount(content: String): Double? {
        val regex = Regex("([0-9]+(?:\\.[0-9]{1,2})?)\\s*元")
        val match = regex.find(content) ?: Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)").find(content)
        val number = match?.groupValues?.getOrNull(1) ?: return null
        return number.toDoubleOrNull()
    }

    private fun isIncome(content: String): Boolean {
        val incomeKeywords = listOf("收款", "收入", "到账", "转入")
        return incomeKeywords.any { content.contains(it) }
    }

    private fun inferCategory(content: String, type: Int): String {
        if (type == 1) {
            return when {
                content.contains("工资") -> "工资"
                content.contains("理财") -> "理财"
                else -> "其他"
            }
        }

        return when {
            content.contains("打车") || content.contains("地铁") || content.contains("公交") -> "交通"
            content.contains("餐") || content.contains("奶茶") || content.contains("外卖") -> "餐饮"
            content.contains("超市") || content.contains("淘宝") || content.contains("京东") -> "购物"
            content.contains("电影") || content.contains("游戏") -> "娱乐"
            content.contains("房租") || content.contains("物业") -> "住房"
            content.contains("医院") || content.contains("药") -> "医疗"
            else -> "日常"
        }
    }

    companion object {
        const val PREF_NAME = "yuyu_auto_bookkeeping"
        const val KEY_PENDING_RECORDS = "pending_records"
    }
}
