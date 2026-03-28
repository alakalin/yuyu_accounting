package com.example.my_app

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

class NotificationListenerServiceBridge : NotificationListenerService() {
    private fun insertDebugLog(pkg: String, title: String, content: String, reason: String) {
        try {
            val dbFile = getDatabasePath(DB_FILE_NAME)
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            try {
                db.execSQL("CREATE TABLE IF NOT EXISTS debug_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, time INTEGER, pkg TEXT, title TEXT, content TEXT, reason TEXT)")
                val values = ContentValues().apply {
                    put("time", System.currentTimeMillis())
                    put("pkg", pkg)
                    put("title", title)
                    put("content", content)
                    put("reason", reason)
                }
                db.insert("debug_logs", null, values)
            } finally {
                db.close()
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

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
        
        insertDebugLog(pkg, title, content, "RAW_RECV")

        val amount = extractAmount(content)
        if (amount == null || amount <= 0.0) {
            insertDebugLog(pkg, title, content, "FAIL: Parse Amount (\$amount)")
            return
        }

        val type = if (isIncome(content)) 1 else 0
        val category = inferCategory(content, type)
        val ts = sbn.postTime
        val source = sourceName(pkg)

        if (!looksLikeTransaction(content)) {
            insertDebugLog(pkg, title, content, "FAIL: Not Transaction")
            return
        }

        val dedupKey = buildDedupKey(pkg, title, text, amount, ts)
        if (isDuplicate(dedupKey, ts)) {
            insertDebugLog(pkg, title, content, "FAIL: Duplicate")
            return
        }
        
        insertDebugLog(pkg, title, content, "SUCCESS: Valid")

        val record = JSONObject().apply {
            put("amount", amount)
            put("type", type)
            put("category", category)
            put("note", "${source}通知自动识别: $title $text")
            put("timestamp", ts)
            put("sourceApp", pkg)
        }

        val directSaved = tryWriteTransactionDirectly(
            amount = amount,
            type = type,
            categoryName = category,
            timestamp = ts,
            note = record.optString("note")
        )

        // Fallback queue for Flutter-side import when direct DB write is unavailable.
        if (!directSaved) {
            appendRecord(record)
        }

        rememberKey(dedupKey, ts)
        notifyNewRecord()
    }

    private fun notifyNewRecord() {
        val intent = android.content.Intent(ACTION_NEW_AUTO_RECORD).apply {
            `package` = packageName
        }
        sendBroadcast(intent)
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

    private fun tryWriteTransactionDirectly(
        amount: Double,
        type: Int,
        categoryName: String,
        timestamp: Long,
        note: String
    ): Boolean {
        val dbFile = getDatabasePath(DB_FILE_NAME)
        if (!dbFile.exists()) {
            return false
        }

        var db: SQLiteDatabase? = null
        return try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )

            val categoryId = resolveCategoryId(db, categoryName, type)
                ?: resolveCategoryId(db, if (type == 1) "其他" else "日常", type)
                ?: return false

            if (hasDuplicateRecord(db, amount, type, timestamp)) {
                return true
            }

            val values = ContentValues().apply {
                put("amount", amount)
                put("type", type)
                put("categoryId", categoryId)
                put("timestamp", timestamp)
                put("note", note)
            }

            db.insert("transactions", null, values) > 0
        } catch (_: Exception) {
            false
        } finally {
            db?.close()
        }
    }

    private fun resolveCategoryId(
        db: SQLiteDatabase,
        name: String,
        type: Int
    ): Long? {
        val cursor = db.rawQuery(
            "SELECT id FROM categories WHERE name = ? AND type = ? LIMIT 1",
            arrayOf(name, type.toString())
        )
        cursor.use {
            if (it.moveToFirst()) {
                return it.getLong(0)
            }
        }
        return null
    }

    private fun hasDuplicateRecord(
        db: SQLiteDatabase,
        amount: Double,
        type: Int,
        timestamp: Long
    ): Boolean {
        val minTs = timestamp - DEDUP_WINDOW_MS
        val maxTs = timestamp + DEDUP_WINDOW_MS
        val cursor = db.rawQuery(
            "SELECT id FROM transactions WHERE amount = ? AND type = ? AND timestamp BETWEEN ? AND ? AND note LIKE ? LIMIT 1",
            arrayOf(
                amount.toString(),
                type.toString(),
                minTs.toString(),
                maxTs.toString(),
                "%通知自动识别%"
            )
        )
        cursor.use {
            return it.moveToFirst()
        }
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
        val normalized = content.replace("\\s+".toRegex(), "")

        val hitPositive = TRANSACTION_PATTERNS.any { it.containsMatchIn(normalized) }
        if (!hitPositive) return false

        // Filter marketing messages that contain money-like text but no real payment.
        val hitNegative = NON_TRANSACTION_PATTERNS.any { it.containsMatchIn(normalized) }
        return !hitNegative
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
        const val ACTION_NEW_AUTO_RECORD = "yuyu.auto_bookkeeping.NEW_RECORD"
        const val DB_FILE_NAME = "accounting.db"

        val TRANSACTION_PATTERNS = listOf(
            Regex("支付成功|付款成功|扣款成功|消费成功"),
            Regex("微信支付|支付凭证|转账给|向你转账"),
            Regex("收款成功|收款到账|到账通知|收入"),
            Regex("退款成功|退款到账"),
            Regex("实付[¥￥]?[0-9]+(?:\\.[0-9]{1,2})?"),
            Regex("[¥￥][0-9]+(?:\\.[0-9]{1,2})?"),
            Regex("[0-9]+(?:\\.[0-9]{1,2})?元")
        )

        val NON_TRANSACTION_PATTERNS = listOf(
            Regex("红包封面|优惠券|立减|满减|返现活动"),
            Regex("广告|营销|推荐|活动通知")
        )

        val SUPPORTED_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.xunmeng.pinduoduo",
            "com.jingdong.app.mall",
            "com.taobao.taobao"
        )
    }
}
