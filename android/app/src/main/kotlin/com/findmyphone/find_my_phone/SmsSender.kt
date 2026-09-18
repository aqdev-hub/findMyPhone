package com.findmyphone.find_my_phone

import android.app.PendingIntent
import android.content.Context
import android.telephony.SmsManager

object SmsSender {
    fun send(context: Context, phone: String, message: String) {
        val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = smsManager.divideMessage(message)
        smsManager.sendMultipartTextMessage(phone, null, parts, ArrayList<PendingIntent?>(), ArrayList<PendingIntent?>())
    }
}
