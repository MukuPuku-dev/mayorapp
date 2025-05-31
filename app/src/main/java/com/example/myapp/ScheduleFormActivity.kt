package com.example.myapp

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.bumptech.glide.Glide
import com.example.myapp.models.Schedule
import com.example.myapp.utils.AlarmScheduler
import com.example.myapp.utils.DateConverter // Import DateConverter
import com.example.myapp.utils.ImageUtils
import com.google.android.material.textfield.TextInputEditText
import id.zelory.compressor.Compressor
import com.google.firebase.Timestamp
import com.google.firebase.auth.ktx.auth
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.storage.ktx.storage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

class ScheduleFormActivity : AppCompatActivity() {

    private lateinit var etAgenda: TextInputEditText
    private lateinit var etApplicant: TextInputEditText
    private lateinit var etAddress: TextInputEditText
    private lateinit var tvDatePicker: TextView
    private lateinit var tvNepaliDateDisplay: TextView // Added
    private lateinit var tvTimePicker: TextView
    private lateinit var etRemarks: TextInputEditText
    private lateinit var ivImagePreview: ImageView
    private lateinit var btnSelectImage: Button
    private lateinit var btnSaveSchedule: Button

    private val selectedDateTime = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))
    private val dateFormat = SimpleDateFormat("EEE, MMM d, yyyy", Locale.getDefault())
    private val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault())

    private var existingSchedule: Schedule? = null
    private var scheduleId: String? = null
    private var selectedImageUri: Uri? = null
    private var newImageTakenUri: Uri? = null // For camera captures

    private val db = Firebase.firestore
    private val auth = Firebase.auth
    private val storage = Firebase.storage
    private val TAG = "ScheduleFormActivity"

    // ActivityResultLaunchers
    private val cameraLauncher = registerForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) {
            newImageTakenUri?.let { uri ->
                selectedImageUri = uri
                ivImagePreview.setImageURI(uri)
                ivImagePreview.visibility = View.VISIBLE
            }
        } else {
            Toast.makeText(this, "Camera capture failed.", Toast.LENGTH_SHORT).show()
        }
    }

    private val galleryLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri?.let {
            selectedImageUri = it
            ivImagePreview.setImageURI(it)
            ivImagePreview.visibility = View.VISIBLE
        }
    }

    private val requestCameraPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
            if (isGranted) {
                openCamera()
            } else {
                Toast.makeText(this, "Camera permission is required to take photos.", Toast.LENGTH_LONG).show()
            }
        }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_schedule_form)

        etAgenda = findViewById(R.id.et_agenda)
        etApplicant = findViewById(R.id.et_applicant)
        etAddress = findViewById(R.id.et_address)
        tvDatePicker = findViewById(R.id.tv_date_picker)
        tvNepaliDateDisplay = findViewById(R.id.tv_nepali_date_display) // Initialized
        tvTimePicker = findViewById(R.id.tv_time_picker)
        etRemarks = findViewById(R.id.et_remarks)
        ivImagePreview = findViewById(R.id.iv_image_preview)
        btnSelectImage = findViewById(R.id.btn_select_image)
        btnSaveSchedule = findViewById(R.id.btn_save_schedule)

        scheduleId = intent.getStringExtra("scheduleId")

        if (scheduleId != null) {
            title = "Edit Schedule"
            loadScheduleData(scheduleId!!)
        } else {
            title = "Add New Schedule"
            updateDateDisplay() // Initialize with current date
            updateTimeDisplay() // Initialize with current time
        }

        setupPickers()
        btnSaveSchedule.setOnClickListener { CoroutineScope(Dispatchers.Main).launch { saveSchedule() } }
        btnSelectImage.setOnClickListener { showImageSourceDialog() }
    }

    private fun showImageSourceDialog() {
        val options = arrayOf("Camera", "Gallery")
        AlertDialog.Builder(this)
            .setTitle("Select Image Source")
            .setItems(options) { _, which ->
                when (which) {
                    0 -> checkCameraPermissionAndOpen() // Camera
                    1 -> galleryLauncher.launch("image/*") // Gallery
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun checkCameraPermissionAndOpen() {
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED -> {
                openCamera()
            }
            shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) -> {
                // Show an explanation to the user *asynchronously*
                AlertDialog.Builder(this)
                    .setTitle("Camera Permission Needed")
                    .setMessage("This app needs camera permission to take pictures for schedules. Please grant the permission.")
                    .setPositiveButton("OK") { _, _ ->
                        requestCameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                    }
                    .setNegativeButton("Cancel", null)
                    .show()
            }
            else -> {
                requestCameraPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }
    }

    private fun openCamera() {
        try {
            newImageTakenUri = ImageUtils.getTmpFileUri(this)
            cameraLauncher.launch(newImageTakenUri)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating temp file for camera", e)
            Toast.makeText(this, "Could not start camera: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }


    private fun setupPickers() {
        tvDatePicker.setOnClickListener {
            val datePickerDialog = DatePickerDialog(
                this,
                { _, year, month, dayOfMonth ->
                    selectedDateTime.set(Calendar.YEAR, year)
                    selectedDateTime.set(Calendar.MONTH, month)
                    selectedDateTime.set(Calendar.DAY_OF_MONTH, dayOfMonth)
                    updateDateDisplay()
                },
                selectedDateTime.get(Calendar.YEAR),
                selectedDateTime.get(Calendar.MONTH),
                selectedDateTime.get(Calendar.DAY_OF_MONTH)
            )
            datePickerDialog.show()
        }

        tvTimePicker.setOnClickListener {
            val timePickerDialog = TimePickerDialog(
                this,
                { _, hourOfDay, minute ->
                    selectedDateTime.set(Calendar.HOUR_OF_DAY, hourOfDay)
                    selectedDateTime.set(Calendar.MINUTE, minute)
                    updateTimeDisplay()
                },
                selectedDateTime.get(Calendar.HOUR_OF_DAY),
                selectedDateTime.get(Calendar.MINUTE),
                false // 12-hour format
            )
            timePickerDialog.show()
        }
    }

    private fun updateDateDisplay() {
        tvDatePicker.text = dateFormat.format(selectedDateTime.time)
        tvNepaliDateDisplay.text = DateConverter.getFullNepaliDateWithDayOfWeek(selectedDateTime.time)
    }

    private fun updateTimeDisplay() {
        tvTimePicker.text = timeFormat.format(selectedDateTime.time)
    }

    private fun loadScheduleData(id: String) {
        db.collection("schedules").document(id)
            .get()
            .addOnSuccessListener { document ->
                if (document != null && document.exists()) {
                    existingSchedule = document.toObject(Schedule::class.java)
                    existingSchedule?.let {
                        etAgenda.setText(it.agenda)
                        etApplicant.setText(it.applicant)
                        etAddress.setText(it.address)
                        etRemarks.setText(it.remarks)
                        selectedDateTime.time = it.time.toDate()
                        updateDateDisplay()
                        updateTimeDisplay()
                        if (!it.imageUrl.isNullOrEmpty()) {
                            Glide.with(this).load(it.imageUrl).into(ivImagePreview)
                            ivImagePreview.visibility = View.VISIBLE
                        }
                    }
                } else {
                    Log.d(TAG, "No such document for ID: $id")
                    Toast.makeText(this, "Schedule not found.", Toast.LENGTH_SHORT).show()
                    finish()
                }
            }
            .addOnFailureListener { exception ->
                Log.d(TAG, "get failed with ", exception)
                Toast.makeText(this, "Failed to load schedule.", Toast.LENGTH_SHORT).show()
                finish()
            }
    }

    private suspend fun saveSchedule() { // Make it a suspend function for coroutines
        val agenda = etAgenda.text.toString().trim()
        val applicant = etApplicant.text.toString().trim()
        val address = etAddress.text.toString().trim()
        val remarks = etRemarks.text.toString().trim()

        if (agenda.isEmpty() || applicant.isEmpty()) {
            Toast.makeText(this, "Agenda and Applicant cannot be empty.", Toast.LENGTH_SHORT).show()
            return
        }

        val currentUser = auth.currentUser
        if (currentUser == null) {
            Toast.makeText(this, "User not authenticated. Please log in again.", Toast.LENGTH_LONG).show()
            // Optionally, redirect to LoginActivity
            return
        }
        val userEmail = currentUser.email ?: "Unknown User"

        val scheduleData = hashMapOf(
            "time" to Timestamp(selectedDateTime.time),
            "agenda" to agenda,
            "applicant" to applicant,
            "address" to address,
            "remarks" to remarks,
            "attended" to (existingSchedule?.attended ?: false),
            "imageUrl" to (existingSchedule?.imageUrl), // Default to existing, will be overwritten if new image uploaded
            "additionalImages" to (existingSchedule?.additionalImages)
        )

        var newImageUrl: String? = existingSchedule?.imageUrl // Keep old image if no new one selected

        if (selectedImageUri != null) {
            // Image was selected, proceed with compression and upload
            val imageFile = ImageUtils.getFileFromUri(this, selectedImageUri!!)
            if (imageFile == null) {
                Toast.makeText(this, "Failed to get image file from URI.", Toast.LENGTH_LONG).show()
                return
            }

            try {
                val compressedImageFile = withContext(Dispatchers.IO) {
                    Compressor.compress(applicationContext, imageFile)
                }
                val imageFileName = "schedules_images/${UUID.randomUUID()}.webp" // Using webp for efficiency
                val storageRef = storage.reference.child(imageFileName)

                newImageUrl = withContext(Dispatchers.IO) {
                    storageRef.putFile(Uri.fromFile(compressedImageFile)).await()
                    storageRef.downloadUrl.await().toString()
                }
                scheduleData["imageUrl"] = newImageUrl

                // If editing and there was an old image different from the new one, delete it
                if (existingSchedule != null && !existingSchedule!!.imageUrl.isNullOrEmpty() && existingSchedule!!.imageUrl != newImageUrl) {
                    try {
                        val oldImageRef = storage.getReferenceFromUrl(existingSchedule!!.imageUrl!!)
                        oldImageRef.delete().await()
                        Log.d(TAG, "Old image deleted: ${existingSchedule!!.imageUrl}")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to delete old image: ${existingSchedule!!.imageUrl}", e)
                        // Non-fatal, continue
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error during image compression or upload", e)
                Toast.makeText(this, "Image processing failed: ${e.message}", Toast.LENGTH_LONG).show()
                return // Stop if image processing fails
            }
        }


        if (existingSchedule == null) { // Add mode
            scheduleData["uploader"] = userEmail
            db.collection("schedules")
                .add(scheduleData)
                .addOnSuccessListener { documentReference ->
                    val newScheduleId = documentReference.id
                    val finalSchedule = Schedule(
                        id = newScheduleId, // Firestore generated ID
                        time = scheduleData["time"] as Timestamp,
                        agenda = scheduleData["agenda"] as String,
                        applicant = scheduleData["applicant"] as String,
                        address = scheduleData["address"] as String,
                        remarks = scheduleData["remarks"] as String,
                        attended = scheduleData["attended"] as Boolean,
                        imageUrl = scheduleData["imageUrl"] as String?,
                        uploader = scheduleData["uploader"] as String?,
                        editor = null, // No editor for new schedule
                        additionalImages = scheduleData["additionalImages"] as String?
                    ).apply { this.documentId = newScheduleId }

                    scheduleReminder(finalSchedule)
                    Log.d(TAG, "DocumentSnapshot written with ID: $newScheduleId")
                    Toast.makeText(this, "Schedule added successfully.", Toast.LENGTH_SHORT).show()
                    finish()
                }
                .addOnFailureListener { e ->
                    Log.w(TAG, "Error adding document", e)
                    Toast.makeText(this, "Error adding schedule: ${e.message}", Toast.LENGTH_LONG).show()
                }
        } else { // Edit mode
            scheduleData["editor"] = userEmail
            scheduleData["uploader"] = existingSchedule?.uploader ?: userEmail

            db.collection("schedules").document(scheduleId!!)
                .set(scheduleData)
                .addOnSuccessListener {
                    val updatedSchedule = Schedule(
                        id = scheduleId!!,
                        time = scheduleData["time"] as Timestamp,
                        agenda = scheduleData["agenda"] as String,
                        applicant = scheduleData["applicant"] as String,
                        address = scheduleData["address"] as String,
                        remarks = scheduleData["remarks"] as String,
                        attended = scheduleData["attended"] as Boolean,
                        imageUrl = scheduleData["imageUrl"] as String?,
                        uploader = scheduleData["uploader"] as String?,
                        editor = scheduleData["editor"] as String?,
                        additionalImages = scheduleData["additionalImages"] as String?
                    ).apply { this.documentId = scheduleId!! }

                    // Cancel old alarm and schedule new one
                    AlarmScheduler.cancelAlarm(this, updatedSchedule.documentId)
                    scheduleReminder(updatedSchedule)

                    Log.d(TAG, "DocumentSnapshot successfully updated!")
                    Toast.makeText(this, "Schedule updated successfully.", Toast.LENGTH_SHORT).show()
                    finish()
                }
                .addOnFailureListener { e ->
                    Log.w(TAG, "Error updating document", e)
                    Toast.makeText(this, "Error updating schedule: ${e.message}", Toast.LENGTH_LONG).show()
                }
        }
    }

    private fun scheduleReminder(schedule: Schedule) {
        val reminderTime = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu")).apply {
            time = schedule.time.toDate()
            add(Calendar.MINUTE, -10) // 10 minutes before
        }

        if (reminderTime.after(Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu")))) {
            AlarmScheduler.scheduleAlarm(applicationContext, schedule, reminderTime)
        } else {
            Log.d(TAG, "Reminder time for schedule ${schedule.documentId} is in the past. Not scheduling.")
        }
    }
}
