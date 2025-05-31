package com.example.myapp.utils

import android.util.Log
import com.sbischl.NepaliDateConverter.NepaliDate // Assuming this is the main class from the library
import java.util.Calendar
import java.util.Date

object DateConverter {

    private const val TAG = "DateConverter"

    /**
     * Converts a Gregorian date to a Nepali (Bikram Sambat) date string.
     *
     * @param year English year (e.g., 2023)
     * @param month English month (1-12)
     * @param day English day of the month
     * @return Formatted Nepali date string (e.g., "2080-01-15") or Gregorian date if conversion fails.
     */
    fun convertEnglishDateToNepali(year: Int, month: Int, day: Int): String {
        return try {
            // Library API usage is assumed here. This might need adjustment based on the actual library.
            // Some libraries might take month 0-11, others 1-12. Assuming 1-12 for input here.
            // The library might also have a constructor taking java.util.Date or Calendar.
            val nepaliDate = NepaliDate.fromGregorian(year, month, day) // Common pattern
            // Format: YYYY-MM-DD. The library might have formatting options.
            "${nepaliDate.year}-${String.format("%02d", nepaliDate.month)}-${String.format("%02d", nepaliDate.day)}"
        } catch (e: Exception) {
            Log.e(TAG, "Error converting English date to Nepali: $year-$month-$day", e)
            // Fallback to Gregorian date string or a specific error message
            "$year-${String.format("%02d", month)}-${String.format("%02d", day)} (Nepali N/A)"
        }
    }

    fun convertEnglishDateToNepali(date: Date): String {
        val calendar = Calendar.getInstance()
        calendar.time = date
        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH) + 1 // Calendar.MONTH is 0-indexed
        val day = calendar.get(Calendar.DAY_OF_MONTH)
        return convertEnglishDateToNepali(year, month, day)
    }

    /**
     * Converts an English day of the week string (e.g., "Monday") to Nepali.
     *
     * @param englishDayOfWeek Full English day name (e.g., "Monday", "Tuesday")
     * @return Nepali day name (e.g., "सोमबार") or the English name if no mapping found.
     */
    fun getNepaliDayOfWeekInString(englishDayOfWeek: String): String {
        return when (englishDayOfWeek.lowercase()) {
            "sunday" -> "आइतबार"
            "monday" -> "सोमबार"
            "tuesday" -> "मंगलबार"
            "wednesday" -> "बुधबार"
            "thursday" -> "बिहिबार"
            "friday" -> "शुक्रबार"
            "saturday" -> "शनिबार"
            else -> englishDayOfWeek // Fallback to English name
        }
    }

    /**
     * Provides a full Nepali date string including day of the week.
     * Example: "२०८०-०१-१५ (सोमबार)"
     */
    fun getFullNepaliDateWithDayOfWeek(date: Date): String {
        val nepaliDatePart = convertEnglishDateToNepali(date)

        val calendar = Calendar.getInstance()
        calendar.time = date
        val englishDayIndex = calendar.get(Calendar.DAY_OF_WEEK) // Sunday is 1, Saturday is 7

        val englishDayName = when (englishDayIndex) {
            Calendar.SUNDAY -> "Sunday"
            Calendar.MONDAY -> "Monday"
            Calendar.TUESDAY -> "Tuesday"
            Calendar.WEDNESDAY -> "Wednesday"
            Calendar.THURSDAY -> "Thursday"
            Calendar.FRIDAY -> "Friday"
            Calendar.SATURDAY -> "Saturday"
            else -> ""
        }
        val nepaliDayName = getNepaliDayOfWeekInString(englishDayName)

        return if (nepaliDayName.isNotEmpty() && !nepaliDatePart.contains("(Nepali N/A)")) {
            "$nepaliDatePart ($nepaliDayName)"
        } else {
            nepaliDatePart // Return just the date if day name conversion failed or if it's a fallback
        }
    }
}
