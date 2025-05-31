package com.example.myapp.utils

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.example.myapp.models.Schedule
import com.example.myapp.receivers.AlarmReceiver
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

object AlarmScheduler {

    private const val TAG = "AlarmScheduler"
    // SimpleDateFormat to format time for notification title
    private val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone("Asia/Kathmandu") // Consistent timezone
    }


    fun scheduleAlarm(context: Context, schedule: Schedule, reminderTime: Calendar) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Generate a unique notificationId for this alarm.
        // Using documentId.hashCode() is a common way, ensure it's stable.
        // Add a prefix or suffix if there's any chance of collision with other notification types.
        val notificationId = schedule.documentId.hashCode()

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("notificationId", notificationId)
            putExtra("title", "${timeFormat.format(schedule.time.toDate())} -- ${schedule.agenda}")
            putExtra("message", "Applicant: ${schedule.applicant}\nAddress: ${schedule.address}\nRemarks: ${schedule.remarks}".trim())
            // Add more data if needed by AlarmReceiver or the activity launched by notification
        }

        val pendingIntentFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId, // Use the unique notificationId as requestCode
            intent,
            pendingIntentFlag
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminderTime.timeInMillis, pendingIntent)
                    Log.d(TAG, "Exact alarm scheduled for schedule ${schedule.documentId} at ${reminderTime.time} (ID: $notificationId)")
                } else {
                    Log.w(TAG, "Cannot schedule exact alarms. App needs SCHEDULE_EXACT_ALARM permission or user disabled it.")
                    // Fallback or inform user. For now, just log.
                    // Consider using setWindow or set an inexact alarm as fallback.
                    // alarmManager.set(AlarmManager.RTC_WAKEUP, reminderTime.timeInMillis, pendingIntent) // Inexact
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminderTime.timeInMillis, pendingIntent)
                Log.d(TAG, "Exact alarm scheduled for schedule ${schedule.documentId} at ${reminderTime.time} (ID: $notificationId)")
            }
        } catch (se: SecurityException) {
            Log.e(TAG, "SecurityException while scheduling alarm. Check USE_EXACT_ALARM or SCHEDULE_EXACT_ALARM permissions.", se)
            // This might happen if permissions are revoked or not declared correctly.
        }
    }

    fun cancelAlarm(context: Context, scheduleId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val notificationId = scheduleId.hashCode() // Re-generate the same notificationId

        val intent = Intent(context, AlarmReceiver::class.java) // Action and component must match
        // No need to put extras for cancellation if request code and component match.
        // However, to be absolutely safe, you can re-create the exact same intent.
        // For cancellation, only the requestCode and the Intent's component/action/data type matter most.

        val pendingIntentFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE // Use FLAG_NO_CREATE to check if it exists
        } else {
            PendingIntent.FLAG_NO_CREATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            pendingIntentFlag
        )

        if (pendingIntent != null) { // Only cancel if it exists
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel() // Also cancel the PendingIntent itself
            Log.d(TAG, "Alarm cancelled for schedule ID $scheduleId (Notification ID: $notificationId)")
        } else {
            Log.d(TAG, "No alarm found to cancel for schedule ID $scheduleId (Notification ID: $notificationId)")
        }
    }
}
