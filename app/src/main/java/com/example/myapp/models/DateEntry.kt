package com.example.myapp.models

import java.util.Date

data class DateEntry(
    val date: Date,
    val schedules: List<Schedule>
)
