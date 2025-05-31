package com.example.myapp.adapters

import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.example.myapp.R
import com.example.myapp.ScheduleFormActivity
import com.example.myapp.models.Schedule
import com.example.myapp.utils.AlarmScheduler
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.storage.ktx.storage
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class ScheduleAdapter(private var schedules: List<Schedule>, private val context: Context) :
    RecyclerView.Adapter<ScheduleAdapter.ViewHolder>() {

    private val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault())
    private val db = Firebase.firestore
    private val TAG = "ScheduleAdapter"

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.list_item_schedule, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val schedule = schedules[position]

        holder.tvTime.text = timeFormat.format(schedule.time.toDate())
        holder.tvAgenda.text = "Agenda: ${schedule.agenda}"
        holder.tvApplicant.text = "Applicant: ${schedule.applicant}"
        holder.tvAddress.text = "Address: ${schedule.address}"
        holder.tvRemarks.text = "Remarks: ${schedule.remarks}"

        // Image indicator (small icon)
        if (!schedule.imageUrl.isNullOrEmpty() || !schedule.additionalImages.isNullOrEmpty()) {
            holder.ivImageIndicator.visibility = View.VISIBLE
        } else {
            holder.ivImageIndicator.visibility = View.GONE
        }

        // Actual image display
        if (!schedule.imageUrl.isNullOrEmpty()) {
            holder.ivScheduleImage.visibility = View.VISIBLE
            Glide.with(context)
                .load(schedule.imageUrl)
                .placeholder(R.drawable.ic_image_placeholder) // Optional placeholder
                .error(R.drawable.ic_broken_image) // Optional error image
                .into(holder.ivScheduleImage)
        } else {
            holder.ivScheduleImage.visibility = View.GONE
        }

        if (schedule.attended) {
            holder.ivAttendedIndicator.visibility = View.VISIBLE
        } else {
            holder.ivAttendedIndicator.visibility = View.GONE
        }

        // Visually mark past/attended schedules
        val scheduleDate = schedule.time.toDate()
        if (isPastDate(scheduleDate) || schedule.attended) {
            holder.itemView.setBackgroundColor(ContextCompat.getColor(context, R.color.light_gray)) // Example: light gray background
            holder.tvAgenda.setTextColor(Color.GRAY)
        } else if (isToday(scheduleDate)) {
             holder.itemView.setBackgroundColor(ContextCompat.getColor(context, R.color.light_yellow)) // Example: light yellow for today
        }
        else {
            // Reset to default if not past/attended and not today
            holder.itemView.setBackgroundColor(Color.WHITE)
            holder.tvAgenda.setTextColor(ContextCompat.getColor(context, android.R.color.black))
        }

        holder.itemView.setOnLongClickListener {
            showEditDeleteDialog(schedule, position)
            true
        }
    }

    private fun showEditDeleteDialog(schedule: Schedule, position: Int) {
        val options = arrayOf("Edit", "Delete")
        AlertDialog.Builder(context)
            .setTitle("Choose Action for \"${schedule.agenda}\"")
            .setItems(options) { dialog, which ->
                when (which) {
                    0 -> { // Edit
                        val intent = Intent(context, ScheduleFormActivity::class.java)
                        intent.putExtra("scheduleId", schedule.documentId)
                        context.startActivity(intent)
                    }
                    1 -> { // Delete
                        confirmDelete(schedule, position)
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun confirmDelete(schedule: Schedule, position: Int) {
        AlertDialog.Builder(context)
            .setTitle("Confirm Delete")
            .setMessage("Are you sure you want to delete schedule: \"${schedule.agenda}\"? This action cannot be undone.")
            .setPositiveButton("Delete") { _, _ ->
                deleteScheduleFromFirestore(schedule, position) // Pass the whole schedule object
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun deleteScheduleFromFirestore(schedule: Schedule, position: Int) {
        if (schedule.documentId.isEmpty()) {
            Log.e(TAG, "Cannot delete schedule, documentId is empty.")
            Toast.makeText(context, "Error: Schedule ID is missing.", Toast.LENGTH_SHORT).show()
            return
        }

        // Delete from Firestore
        db.collection("schedules").document(schedule.documentId)
            .delete()
            .addOnSuccessListener {
                Log.d(TAG, "Schedule ${schedule.documentId} successfully deleted from Firestore!")
                Toast.makeText(context, "Schedule deleted.", Toast.LENGTH_SHORT).show()

                // If imageUrl exists, delete from Firebase Storage
                if (!schedule.imageUrl.isNullOrEmpty()) {
                    val storageRef = Firebase.storage.getReferenceFromUrl(schedule.imageUrl)
                    storageRef.delete().addOnSuccessListener {
                        Log.d(TAG, "Image ${schedule.imageUrl} successfully deleted from Storage!")
                    }.addOnFailureListener { e ->
                        Log.w(TAG, "Error deleting image ${schedule.imageUrl} from Storage", e)
                        // Non-fatal, Firestore document already deleted.
                    }
                }
                // Cancel any scheduled alarm for this schedule
                AlarmScheduler.cancelAlarm(context, schedule.documentId)

                // UI update will be handled by MainActivity's onResume listener
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "Error deleting schedule ${schedule.documentId} from Firestore", e)
                Toast.makeText(context, "Failed to delete schedule: ${e.message}", Toast.LENGTH_LONG).show()
            }
    }


    override fun getItemCount(): Int = schedules.size

    fun updateSchedules(newSchedules: List<Schedule>) {
        this.schedules = newSchedules
        notifyDataSetChanged()
    }

    private fun isPastDate(date: Date): Boolean {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))
        cal.time = date
        val today = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))

        // Reset time part for comparison to date only
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)

        return cal.before(today)
    }

    private fun isToday(date: Date): Boolean {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))
        cal.time = date
        val today = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))
        return cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
               cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
    }


    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvTime: TextView = view.findViewById(R.id.tv_schedule_time)
        val tvAgenda: TextView = view.findViewById(R.id.tv_agenda)
        val tvApplicant: TextView = view.findViewById(R.id.tv_applicant)
        val tvAddress: TextView = view.findViewById(R.id.tv_address)
        val tvRemarks: TextView = view.findViewById(R.id.tv_remarks)
        val ivImageIndicator: ImageView = view.findViewById(R.id.iv_image_indicator)
        val ivAttendedIndicator: ImageView = view.findViewById(R.id.iv_attended_indicator)
        val ivScheduleImage: ImageView = view.findViewById(R.id.iv_schedule_image) // Added for actual image
    }
}
