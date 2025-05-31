package com.example.myapp.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.myapp.models.Schedule
import com.example.myapp.utils.AlarmScheduler
import com.google.firebase.Timestamp
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.TimeZone

class BootCompletedReceiver : BroadcastReceiver() {

    private val TAG = "BootCompletedReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) {
            Log.e(TAG, "Context is null, cannot process boot event.")
            return
        }
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed event received. Re-scheduling alarms.")

            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val db = Firebase.firestore
                    val now = Timestamp.now() // Schedules in the past won't be re-scheduled for alarms

                    db.collection("schedules")
                        .whereGreaterThanOrEqualTo("time", now) // Only fetch future schedules
                        .get()
                        .addOnSuccessListener { documents ->
                            if (documents.isEmpty) {
                                Log.d(TAG, "No future schedules found to re-schedule alarms.")
                                return@addOnSuccessListener
                            }
                            for (document in documents) {
                                try {
                                    val schedule = document.toObject(Schedule::class.java)
                                    schedule.documentId = document.id

                                    val scheduleTimeCal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu")).apply {
                                        time = schedule.time.toDate()
                                    }
                                    val reminderTime = (scheduleTimeCal.clone() as Calendar).apply {
                                        add(Calendar.MINUTE, -10) // 10 minutes before
                                    }

                                    if (reminderTime.after(Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu")))) {
                                        Log.d(TAG, "Re-scheduling alarm for schedule: ${schedule.documentId} at ${reminderTime.time}")
                                        AlarmScheduler.scheduleAlarm(context, schedule, reminderTime)
                                    } else {
                                        Log.d(TAG, "Reminder time for schedule ${schedule.documentId} is in the past after boot. Not re-scheduling.")
                                    }
                                } catch (e: Exception) {
                                     Log.e(TAG, "Error processing schedule document ${document.id} for re-scheduling", e)
                                }
                            }
                            Log.d(TAG, "Finished re-scheduling ${documents.size()} potential alarms.")
                        }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "Error fetching schedules for re-scheduling alarms", e)
                        }
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in BootCompletedReceiver coroutine", e)
                }
            }
        }
    }
}
