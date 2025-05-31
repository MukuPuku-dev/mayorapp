package com.example.myapp.adapters

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.myapp.R
import com.example.myapp.models.DateEntry
import com.example.myapp.utils.DateConverter // Import DateConverter
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class DateEntryAdapter(
    private var dateEntries: List<DateEntry>,
    private val context: Context
) : RecyclerView.Adapter<DateEntryAdapter.ViewHolder>() {

    // MMM d, yyyy format (e.g., Jan 1, 2023)
    private val dateFormat = SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone("Asia/Kathmandu") // Or user's default timezone
    }
    // EEE format for day of week (e.g., Mon)
    private val dayOfWeekFormat = SimpleDateFormat("EEE", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone("Asia/Kathmandu")
    }


    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.list_item_date_entry, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val dateEntry = dateEntries[position]
        val date = dateEntry.date

        val formattedDate = dateFormat.format(date)
        // val dayOfWeek = dayOfWeekFormat.format(date) // No longer needed separately if using getFullNepaliDateWithDayOfWeek

        val nepaliDateString = DateConverter.getFullNepaliDateWithDayOfWeek(date)

        holder.tvDateHeader.text = "$formattedDate\n$nepaliDateString"


        val scheduleAdapter = ScheduleAdapter(dateEntry.schedules, context)
        holder.rvSchedules.layoutManager = LinearLayoutManager(holder.itemView.context)
        holder.rvSchedules.adapter = scheduleAdapter
    }

    override fun getItemCount(): Int = dateEntries.size

    fun updateDateEntries(newDateEntries: List<DateEntry>) {
        this.dateEntries = newDateEntries
        notifyDataSetChanged() // Consider using DiffUtil for better performance
    }

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvDateHeader: TextView = view.findViewById(R.id.tv_date_header)
        val rvSchedules: RecyclerView = view.findViewById(R.id.rv_schedules_for_date)
    }
}
