package com.example.myapp

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.ProgressBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.myapp.adapters.DateEntryAdapter
import com.example.myapp.models.DateEntry
import com.example.myapp.models.Schedule
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.ktx.auth
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.messaging.ktx.messaging
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

class MainActivity : AppCompatActivity() {

    private lateinit var auth: FirebaseAuth
    private lateinit var googleSignInClient: GoogleSignInClient
    private lateinit var rvDateEntries: RecyclerView
    private lateinit var dateEntryAdapter: DateEntryAdapter
    private lateinit var progressBar: ProgressBar
    private lateinit var fabAddSchedule: FloatingActionButton

    private val firestore = Firebase.firestore
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        auth = Firebase.auth

        if (auth.currentUser == null) {
            redirectToLogin()
            return
        }

        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.default_web_client_id))
            .requestEmail()
            .build()
        googleSignInClient = GoogleSignIn.getClient(this, gso)

        rvDateEntries = findViewById(R.id.rv_date_entries)
        progressBar = findViewById(R.id.progressBar)
        fabAddSchedule = findViewById(R.id.fab_add_schedule)

        setupRecyclerView()
        loadSchedules() // Initial load

        fabAddSchedule.setOnClickListener {
            val intent = Intent(this, ScheduleFormActivity::class.java)
            startActivity(intent)
        }
        subscribeToNotificationsTopic()
    }

    private fun subscribeToNotificationsTopic() {
        Firebase.messaging.subscribeToTopic("notification")
            .addOnCompleteListener { task ->
                var msg = "Subscribed to 'notification' topic on app start"
                if (!task.isSuccessful) {
                    msg = "Subscription to 'notification' topic on app start failed"
                }
                Log.d(TAG, msg)
                // Optional: Toast.makeText(baseContext, msg, Toast.LENGTH_SHORT).show()
            }
    }

    override fun onResume() {
            startActivity(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        // Refresh data when returning to MainActivity, in case a schedule was added/edited
        // This is a simple way to refresh. For more complex apps, you might use
        // ActivityResultLauncher or a ViewModel with LiveData.
        if (auth.currentUser != null) { // Only load if user is still logged in
             loadSchedules() // Refresh data
        }
    }

    private fun setupRecyclerView() {
        dateEntryAdapter = DateEntryAdapter(emptyList(), this)
        rvDateEntries.layoutManager = LinearLayoutManager(this)
        rvDateEntries.adapter = dateEntryAdapter
    }

    private fun loadSchedules() {
        progressBar.visibility = View.VISIBLE
        firestore.collection("schedules")
            .orderBy("time", Query.Direction.DESCENDING)
            .get()
            .addOnSuccessListener { documents ->
                progressBar.visibility = View.GONE
                if (documents.isEmpty) {
                    Log.d(TAG, "No schedules found.")
                    dateEntryAdapter.updateDateEntries(emptyList()) // Clear adapter if no data
                    Toast.makeText(this, "No schedules found.", Toast.LENGTH_SHORT).show()
                    return@addOnSuccessListener
                }

                val schedules = documents.mapNotNull { doc ->
                    try {
                        val schedule = doc.toObject(Schedule::class.java)
                        schedule.documentId = doc.id // Assign document ID
                        schedule
                    } catch (e: Exception) {
                        Log.e(TAG, "Error converting document to Schedule: ${doc.id}", e)
                        null
                    }
                }
                Log.d(TAG, "Fetched ${schedules.size} schedules.")
                groupAndDisplaySchedules(schedules)
            }
            .addOnFailureListener { exception ->
                progressBar.visibility = View.GONE
                Log.w(TAG, "Error getting documents: ", exception)
                Toast.makeText(this, "Error loading schedules: ${exception.message}", Toast.LENGTH_LONG).show()
            }
    }

    private fun groupAndDisplaySchedules(schedules: List<Schedule>) {
        if (schedules.isEmpty()) {
            dateEntryAdapter.updateDateEntries(emptyList())
            return
        }
        // Group schedules by date (ignoring time part for grouping)
        val groupedByDate = schedules.groupBy {
            val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kathmandu"))
            cal.time = it.time.toDate()
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.time // This is the Date object representing the start of the day
        }

        // Create DateEntry objects, sorted by date descending
        val dateEntries = groupedByDate.map { (date, scheduleList) ->
            // Sort schedules within each date by time descending (already done by initial query if only one date)
            // If query was broader, sort here: scheduleList.sortedByDescending { it.time.toDate() }
            DateEntry(date, scheduleList.sortedByDescending { it.time.toDate() })
        }.sortedByDescending { it.date } // Sort DateEntry list by date descending

        Log.d(TAG, "Grouped into ${dateEntries.size} date entries.")
        dateEntryAdapter.updateDateEntries(dateEntries)
    }


    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_sign_out -> {
                signOut()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun signOut() {
        auth.signOut()
        googleSignInClient.signOut().addOnCompleteListener(this) {
            redirectToLogin()
        }
    }

    private fun redirectToLogin() {
        startActivity(Intent(this, LoginActivity::class.java))
        finish()
    }

    // Helper functions (isPastDate, isToday) can be added here or in a utility class
    // For now, they are in ScheduleAdapter. Consider moving to a central place if needed elsewhere.
}
