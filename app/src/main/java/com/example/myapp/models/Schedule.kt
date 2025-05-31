package com.example.myapp.models

import com.google.firebase.Timestamp

data class Schedule(
    val id: String = "",
    val time: Timestamp = Timestamp.now(),
    val agenda: String = "",
    val applicant: String = "",
    val address: String = "",
    val remarks: String = "",
    val attended: Boolean = false,
    val imageUrl: String? = null,
    val uploader: String? = null,
    val editor: String? = null,
    val additionalImages: String? = null // Assuming this might be a JSON string of URLs or a single URL
) {
    @JvmField // Important for Firestore to recognize this field if it's not a property with a backing field
    lateinit var documentId: String // To store Firestore document ID
}
