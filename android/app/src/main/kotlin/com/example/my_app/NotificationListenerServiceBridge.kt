package com.example.my_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

class NotificationListenerServiceBridge : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        // Parse payment-related notifications from major payment/ecommerce apps.
        if (!SUPPORTED_PACKAGES.contains(pkg)) return

        val extras = sbn.notification.extras
        val title = extras?.getString("android.title") ?: ""
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras?.getCharSequence("android.bigText")?.toString() ?: ""
        val content = listOf(title, text, bigText).joinToString(" ")

        val amount = extractAmount(content) ?: return
        if (amount <= 0.0) return

        val type = if (isIncome(content)) 1 else 0
        val category = inferCategory(content, type)
        val ts = sbn.postTime
        val source = sourceName(pkg)

        if (!looksLikeTransaction(content)) return

        val dedupKey = buildDedupKey(pkg, title, text, amount, ts)
        if (isDuplicate(dedupKey, ts)) return

        val record = JSONObject().apply {
            put("amount", amount)
            put("type", type)
            put("category", category)
            put("note", "${source}通知自动识别: $title $text")
            put("timestamp", ts)
            put("sourceApp", pkg)
        }

        appendRecord(record)
        rememberKey(dedupKey, ts)
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
        val patterns = listOf(
            Regex("(?:实付|支付|付款|扣款|消费|到账|收款|退款)[^0-9¥￥]{0,8}([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
            Regex("([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
            Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)")
        )
        val match = patterns.firstNotNullOfOrNull { it.find(content) }
        val number = match?.groupValues?.getOrNull(1) ?: return null
        return number.toDoubleOrNull()
    }

    private fun looksLikeTransaction(content: String): Boolean {
        val keywords = listOf(
            "支付", "付款", "扣款", "消费", "收款", "到账", "入账", "退款", "转账", "账单"
        )
        return keywords.any { content.contains(it) }
    }

    private fun isIncome(content: String): Boolean {
        val incomeKeywords = listOf("收款", "收入", "到账", "转入", "退款")
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
            content.contains("拼多多") -> "购物"
            content.contains("电影") || content.contains("游戏") -> "娱乐"
            content.contains("房租") || content.contains("物业") -> "住房"
            content.contains("医院") || content.contains("药") -> "医疗"
            else -> "日常"
        }
    }

    private fun sourceName(pkg: String): String {
        return when (pkg) {
            "com.tencent.mm" -> "微信"
            "com.eg.android.AlipayGphone" -> "支付宝"
            "com.xunmeng.pinduoduo" -> "拼多多"
            "com.jingdong.app.mall" -> "京东"
            "com.taobao.taobao" -> "淘宝"
            else -> "支付通知"
        }
    }

    private fun buildDedupKey(
        pkg: String,
        title: String,
        text: String,
        amount: Double,
        timestamp: Long
    ): String {
        // Bucket timestamp by minute to avoid duplicate notifications in a short period.
        val minuteBucket = timestamp / 60000L
        return "$pkg|${title.trim()}|${text.trim()}|$amount|$minuteBucket"
    }

    private fun isDuplicate(key: String, timestamp: Long): Boolean {
        val shared = getSharedPreferences(PREF_NAME, MODE_PRIVATE)
        val raw = shared.getString(KEY_RECENT_KEYS, "[]") ?: "[]"
        val now = timestamp
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }

        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val k = item.optString("key")
            val ts = item.optLong("ts")
            if (k == key && abs(now - ts) < DEDUP_WINDOW_MS) {
                return true
            }
        }
        return false
    }

    private fun rememberKey(key: String, timestamp: Long) {
        val shared = getSharedPreferences(PREF_NAME, MODE_PRIVATE)
        val raw = shared.getString(KEY_RECENT_KEYS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }

        val cleaned = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val ts = item.optLong("ts")
            if (abs(timestamp - ts) < DEDUP_WINDOW_MS) {
                cleaned.put(item)
            }
        }

        cleaned.put(
            JSONObject().apply {
                put("key", key)
                put("ts", timestamp)
            }
        )

        while (cleaned.length() > 200) {
            cleaned.remove(0)
        }

        shared.edit().putString(KEY_RECENT_KEYS, cleaned.toString()).apply()
    }

    companion object {
        const val PREF_NAME = "yuyu_auto_bookkeeping"
        const val KEY_PENDING_RECORDS = "pending_records"
        const val KEY_RECENT_KEYS = "recent_dedup_keys"
        const val DEDUP_WINDOW_MS = 60_000L

        val SUPPORTED_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.xunmeng.pinduoduo",
            "com.jingdong.app.mall",
            "com.taobao.taobao"
        )
    }
}
