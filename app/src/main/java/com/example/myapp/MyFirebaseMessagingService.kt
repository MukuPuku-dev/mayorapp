package com.example.myapp

import android.util.Log
import com.example.myapp.utils.NotificationUtils // Will create this later
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.google.firebase.messaging.ktx.messaging

class MyFirebaseMessagingService : FirebaseMessagingService() {

    private val TAG = "MyFirebaseMsgService"

    /**
     * Called when message is received.
     *
     * @param remoteMessage Object representing the message received from Firebase Cloud Messaging.
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "From: ${remoteMessage.from}")

        // Check if message contains a data payload.
        remoteMessage.data.isNotEmpty().let {
            Log.d(TAG, "Message data payload: " + remoteMessage.data)
            // Handle data payload here if needed (e.g., for specific actions)
        }

        // Check if message contains a notification payload.
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body}")
            // Show local notification
            NotificationUtils.showLocalNotification(
                applicationContext,
                it.title,
                it.body,
                remoteMessage.data
            )
        }
    }

    /**
     * Called if the FCM registration token is updated. This may occur if the previous token had GCM
     * time to live expiry time exceeded or the server side has issued a new token.
     * Call this method to retrieve the new token.
     */
    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed token: $token")
        sendRegistrationToServer(token)
    }

    private fun sendRegistrationToServer(token: String) {
        val db = Firebase.firestore
        val tokenData = hashMapOf("token" to token)

        // Check if token already exists
        db.collection("tokens").whereEqualTo("token", token).get()
            .addOnSuccessListener { documents ->
                if (documents.isEmpty) {
                    // Token does not exist, add it
                    db.collection("tokens").add(tokenData)
                        .addOnSuccessListener { documentReference ->
                            Log.d(TAG, "Token added to Firestore with ID: ${documentReference.id}")
                            subscribeToNotificationTopic()
                        }
                        .addOnFailureListener { e ->
                            Log.w(TAG, "Error adding token to Firestore", e)
                        }
                } else {
                    Log.d(TAG, "Token already exists in Firestore.")
                    // Even if token exists, ensure subscription (idempotent)
                    subscribeToNotificationTopic()
                }
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "Error checking for existing token", e)
            }
    }

    private fun subscribeToNotificationTopic() {
        Firebase.messaging.subscribeToTopic("notification")
            .addOnCompleteListener { task ->
                var msg = "Subscribed to 'notification' topic"
                if (!task.isSuccessful) {
                    msg = "Subscription to 'notification' topic failed"
                }
                Log.d(TAG, msg)
                // Toast.makeText(baseContext, msg, Toast.LENGTH_SHORT).show() // Avoid Toasts in Service
            }
    }
}
