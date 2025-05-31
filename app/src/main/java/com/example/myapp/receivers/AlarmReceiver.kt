package com.example.myapp.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.myapp.utils.NotificationUtils

class AlarmReceiver : BroadcastReceiver() {

    private val TAG = "AlarmReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) {
            Log.e(TAG, "Context or Intent is null, cannot process alarm.")
            return
        }

        Log.d(TAG, "Alarm received!")

        val notificationId = intent.getIntExtra("notificationId", 0) // Default to 0 if not found
        val title = intent.getStringExtra("title")
        val message = intent.getStringExtra("message")

        if (title == null || message == null) {
            Log.e(TAG, "Notification title or message is null. NotificationId: $notificationId")
            // Optionally show a generic notification if this happens
            NotificationUtils.showLocalNotification(
                context,
                "Scheduled Reminder",
                "You have an upcoming schedule.",
                emptyMap() // No specific data for this fallback
            )
            return
        }

        NotificationUtils.showLocalNotification(
            context,
            title,
            message,
            emptyMap() // Pass data if any was set for the alarm intent
        )
    }
}
