package com.findmyphone.find_my_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * SmsCommandReceiver — the live entry point for every incoming SMS command.
 *
 * IMPORTANT: This receiver only enqueues work; ALL actual command parsing,
 * trust/code verification, dispatch (LOCATE/SILENTLOCATE/INFO/ALARM/LOCK/RESET),
 * replies, and audit logging live in [SmsProcessorWorker] — the single source
 * of truth for command handling. Do not re-implement command logic here.
 *
 * Using WorkManager (rather than processing inline on a raw background
 * Thread) means each command survives process death and is retried by the
 * system if the app is killed mid-processing — meaningfully more reliable
 * for a security-critical path than a fire-and-forget Thread.
 */
class SmsCommandReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!NativeStore.enabled(context)) return

        val pending = goAsync()
        try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent).forEach { sms ->
                val sender = sms.originatingAddress.orEmpty()
                val body = sms.messageBody.orEmpty()
                if (sender.isBlank() || body.isBlank()) return@forEach

                val input = Data.Builder()
                    .putString(SmsProcessorWorker.KEY_SENDER, sender)
                    .putString(SmsProcessorWorker.KEY_BODY, body)
                    .build()
                val request = OneTimeWorkRequestBuilder<SmsProcessorWorker>()
                    .setInputData(input)
                    .build()
                WorkManager.getInstance(context).enqueue(request)
            }
        } finally {
            pending.finish()
        }
    }
}
