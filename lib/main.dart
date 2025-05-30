import 'dart:async'; // Added for Future
import 'dart:convert'; // For jsonEncode
import 'dart:developer'; // For log()
import 'dart:io'; // For File, Platform

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_admin/firebase_admin.dart'; // Typically server-side, consider if actually needed for client
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // Import for flutter_timezone

// Assuming activity_analysis_screen.dart is in the same lib directory
import 'activity_analysis_screen.dart'; 
import 'DateConvert.dart';
import 'Decisions.dart';
import 'Schedule.dart';
import 'firebase_options.dart';
import 'unauthorized_screen.dart'; // Import the UnauthorizedScreen

// --- Global Firebase and Notification Instances ---
FirebaseFirestore firestoreInstance = FirebaseFirestore.instance; // Instance for Firestore database interactions
FirebaseMessaging messaging = FirebaseMessaging.instance; // Instance for Firebase Cloud Messaging
// FirebaseAdmin admin = FirebaseAdmin.instance; // Commented out: Firebase Admin SDK is generally for server-side use. Client-side apps typically use the standard Firebase SDKs.

// Collections References
CollectionReference schedules_data = firestoreInstance.collection('schedules'); // Stores schedule documents
CollectionReference tokens_data = firestoreInstance.collection('tokens'); // Stores FCM tokens for devices
CollectionReference settings_firestore = firestoreInstance.collection('settings'); // For app settings like server keys

// Local Notifications Plugin Instance
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(); // Instance for showing local notifications

/// Sends a Firebase Cloud Messaging (FCM) notification for the given [schedule].
///
/// Retrieves the server key from Firestore (settings/serverid) and uses it
/// to authorize the HTTP POST request to FCM to send a message to the 'notification' topic.
void sendNotification(Schedule schedule) async {
  DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection("settings").doc("serverid").get();
  var serverKey = '';
  if (snapshot.exists) {
    var data = snapshot.data() as Map<String, dynamic>;
    serverKey = data['serverKey'] ?? ''; // Ensure serverKey is not null
  } else {
    print('Server key document does not exist in Firestore.');
  }

  if (serverKey.isEmpty) {
    print('Server key is empty, cannot send notification.');
    log('Attempted to send notification but serverKey was empty.'); // Added logging
    return;
  }

  try {
    http.Response response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: constructFCMPayload(schedule),
    );
    log("FCM send status: ${response.statusCode} | Message Sent Successfully!");
  } catch (e, s) {
    log("Error sending FCM notification: $e", stackTrace: s);
  }
}

/// Constructs the JSON payload for an FCM message based on the [schedule] details.
///
/// This payload includes notification details (title, body formatted with Nepali text and date/time)
/// and some custom data fields. The notification is targeted to the '/topics/notification' topic.
String constructFCMPayload(Schedule schedule) {
  return jsonEncode(<String, dynamic>{
    'notification': <String, dynamic>{
      'body': "निम्तो कर्ताः ${schedule.applicant}\n ठेगाानाः ${schedule.address}\nकैफियतः ${schedule.remarks}",
      'title': "विषय: ${schedule.agenda} ---> \n${DateConverter.convertEnglishDateToNepali(
        schedule.time.year,
        schedule.time.month,
        schedule.time.day,
      )}-> ${DateFormat.Hm().format(schedule.time)}",
    },
    'data': <String, dynamic>{ // Custom data payload
      'click_action': 'FLUTTER_NOTIFICATION_CLICK', // Necessary for onMessageOpenedApp
      'id': schedule.id ?? 'N/A', // Example: pass schedule ID
      'agenda': schedule.agenda,
    },
    'to': '/topics/notification', // Target topic
  });
}

List<dynamic>? authenticatedUsers; // List of email addresses of users allowed to use the app.
User? currentUser; // The currently signed-in Firebase Authentication user.

/// The main entry point for the application.
///
/// Initializes Firebase, registers for Firebase Messaging to handle notifications,
/// and sets up a listener for changes in authenticated users' settings from Firestore.
/// The app's UI (MyApp) is run after these initializations.
Future<void> main() async { // Changed to Future<void> for async operations
  WidgetsFlutterBinding.ensureInitialized(); // Required for plugins before runApp.

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize timezones for an app that uses them
  try {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
  } catch (e,s) {
    print("Error initializing timezones: $e");
    log("Timezone initialization error stacktrace: $s", stackTrace: s);
  }


  // Register for Firebase Cloud Messaging and set up notification handlers.
  await _registerFirebaseMessaging();

  // Listen to changes in the 'authenticatedUsers' document in Firestore.
  // This allows for dynamic updates to the list of users who can access the app.
  firestoreInstance.collection('settings').doc('authenticatedUsers').snapshots().listen((snapshot) {
    if (snapshot.exists) {
      authenticatedUsers = snapshot.data()?['emails'];
      print("Authenticated users list updated: $authenticatedUsers");
    } else {
      authenticatedUsers = []; // Default to empty list if document doesn't exist
      print("Authenticated users document does not exist. Using empty list.");
    }
    // Re-run the app to reflect potential changes in authentication status.
    runApp(const MyApp());
  });
}

/// Registers the device for Firebase Cloud Messaging (FCM) and sets up notification handling.
Future<void> _registerFirebaseMessaging() async {
  try {
    String? token = await messaging.getToken();
    print('Firebase Messaging Token: $token');

    if (token != null) {
      QuerySnapshot querySnapshot = await tokens_data.where('token', isEqualTo: token).get();
      if (querySnapshot.docs.isEmpty) {
        await messaging.subscribeToTopic("notification");
        Map<String, dynamic> data = {'token': token, 'createdAt': FieldValue.serverTimestamp()};
        await tokens_data.add(data);
        print('Token subscribed and saved to Firestore.');
      } else {
        print('Token already exists in Firestore.');
      }
    } else {
      print('Failed to get FCM token.');
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    try {
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    } catch (e, s) {
      print('Error initializing FlutterLocalNotificationsPlugin: $e');
      log('Stack trace for local_notifications init: $s', stackTrace: s);
    }


    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground notification: ${message.notification?.title} - ${message.notification?.body}');
      try {
        _showLocalNotification(
          flutterLocalNotificationsPlugin,
          message.notification?.title,
          message.notification?.body,
        );
      } catch (e,s) {
        print("Error showing local notification from onMessage: $e");
        log('Stack trace for onMessage _showLocalNotification: $s', stackTrace: s);
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e, s) {
    print('Error registering Firebase Messaging: $e');
    log('Stack trace: $s', stackTrace: s);
  }
}

/// Handles FCM messages received when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 
  print('Handling a background message: ${message.messageId}');
  
  final FlutterLocalNotificationsPlugin backgroundNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  try {
    await backgroundNotificationsPlugin.initialize(initializationSettings);
    _showLocalNotification(
      backgroundNotificationsPlugin, 
      message.notification?.title,
      message.notification?.body,
    );
  } catch (e, s) {
     print("Error from onBackgroundMessage handler: $e");
     log('Stack trace for onBackgroundMessage: $s', stackTrace: s);
  }
}

/// Displays a local notification using [FlutterLocalNotificationsPlugin].
Future<void> _showLocalNotification(
    FlutterLocalNotificationsPlugin plugin, 
    String? title,
    String? body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'schedule_channel_id', 
    'Schedule Notifications', 
    channelDescription: 'Channel for schedule reminder notifications', 
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'), 
  );
  const DarwinInitializationDetails iOSPlatformChannelSpecifics = DarwinInitializationDetails(presentSound: true); // Corrected class name
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );
  try {
    await plugin.show(
      0, 
      title,
      body,
      platformChannelSpecifics,
      payload: 'schedule_notification_payload', 
    );
  } catch (e,s) {
     print("Error in _showLocalNotification plugin.show(): $e");
     log('Stack trace for plugin.show(): $s', stackTrace: s);
  }
}

/// Example function to retrieve all data from the 'schedules' collection.
void retrieveData() {
  schedules_data.get().then((QuerySnapshot querySnapshot) {
    if (querySnapshot.docs.isNotEmpty) {
      querySnapshot.docs.forEach((doc) {
        // var data = doc.data(); 
        // print('Document data: $data');
      });
    } else {
      print('No documents found in schedules collection.');
    }
  }).catchError((error, stackTrace) {
    print('Error retrieving data: $error');
    log('Stack trace: $stackTrace', stackTrace: stackTrace);
  });
}

/// Extension on [DateTime] to compare if two DateTime objects represent the same calendar date (ignoring time).
extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

/// Compresses an image file to WebP format with reduced quality.
Future<XFile?> compressImage(File file) async {
  try {
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      '${file.path}_compressed.webp', 
      quality: 10, 
      format: CompressFormat.webp,
    );
    return compressedFile;
  } catch (error, s) {
    print('Image compression error: $error');
    log('Stack trace: $s', stackTrace: s);
    return null;
  }
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mayor Rocks', 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, 
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator()); 
          } else if (snapshot.hasData) {
            currentUser = snapshot.data; 
            if (authenticatedUsers?.contains(currentUser?.email) ?? false) {
              return ScheduleScreen(); 
            } else {
              print("User ${currentUser?.email} is authenticated but not authorized. Showing UnauthorizedScreen.");
              return UnauthorizedScreen(); // Show the UnauthorizedScreen
            }
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}

/// Represents a logical grouping of [Schedule] items that occur on the same calendar date.
class DateEntry {
  final DateTime date;
  final List<Schedule> schedules;

  DateEntry({
    required this.date,
    required this.schedules,
  });
}

Future<bool> _isUserAuthenticated(String email) async {
  print("Authenticating user (legacy check): $email");
  bool isUserAuthenticated = false; 
  var sub = firestoreInstance.collection('settings').doc('authenticatedUsers').snapshots().listen((snapshot) {
    final List<dynamic>? emails = snapshot.data()?['emails'];
    if (emails != null && emails.contains(email)) {
      isUserAuthenticated = true;
    } else {
      isUserAuthenticated = false;
    }
  });
  await Future.delayed(Duration(seconds: 1)); 
  sub.cancel(); 
  print("Legacy _isUserAuthenticated returning: $isUserAuthenticated for $email (likely inaccurate)");
  return isUserAuthenticated;
}

String getGoogleClientId() {
  if (Platform.isAndroid) {
    return '707616392800-tfsq93frcs766ohs1hc7ubguns430650.apps.googleusercontent.com';
  } else if (Platform.isIOS) {
    return '707616392800-hm3qtoqtibha4a15b3noaoqf0it2jqu6.apps.googleusercontent.com';
  } else {
    return '707616392800-d9dbkbpgf3dha27v4tmodrfrp4529b74.apps.googleusercontent.com';
  }
}

/// Screen for user login, currently supporting Google Sign-In.
class LoginScreen extends StatelessWidget {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (error, s) {
      print('Google sign-in error: $error');
      log('Stack trace: $s', stackTrace: s);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            UserCredential? userCredential = await _signInWithGoogle();
            if (userCredential != null) {
              print("Google Sign-In successful for: ${userCredential.user?.email}");
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Google Sign-In failed or cancelled.')),
              );
            }
          },
          child: Text('Sign in with Google'),
        ),
      ),
    );
  }
}

/// A form widget for adding new schedules or editing existing ones.
class ScheduleForm extends StatefulWidget {
  final void Function(Schedule) onScheduleAdded; 
  final Schedule? existingSchedule; 

  ScheduleForm({required this.onScheduleAdded, this.existingSchedule});

  @override
  _ScheduleFormState createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<ScheduleForm> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _agendaController = TextEditingController();
  final _applicantController = TextEditingController();
  final _addressController = TextEditingController();
  final _remarksController = TextEditingController();
  File? _selectedImage; 
  String imageUrl = ''; 
  bool updateImage = false; 
  Schedule? existingSchedule; 

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      existingSchedule = widget.existingSchedule;
      _selectedDate = widget.existingSchedule!.time;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingSchedule!.time);
      _agendaController.text = widget.existingSchedule!.agenda;
      _applicantController.text = widget.existingSchedule!.applicant;
      _addressController.text = widget.existingSchedule!.address;
      _remarksController.text = widget.existingSchedule!.remarks;
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _agendaController.dispose();
    _applicantController.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _showDatePicker() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null && mounted) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  void _showTimePicker() async {
    final selectedTime = await showTimePicker(context: context, initialTime: _selectedTime);
    if (selectedTime != null && mounted) {
      setState(() => _selectedTime = selectedTime);
    }
  }

  Future<List<Map<String, dynamic>>> getAllTokens() async {
    QuerySnapshot querySnapshot = await tokens_data.get();
    return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  void _addSchedule() async {
    final scheduleTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute, DateTime.now().second,
    );

    final newOrUpdatedSchedule = Schedule(
      id: widget.existingSchedule?.id,
      time: scheduleTime,
      agenda: _agendaController.text,
      applicant: _applicantController.text,
      address: _addressController.text,
      remarks: _remarksController.text,
      imageUrl: widget.existingSchedule?.imageUrl,
      uploader: widget.existingSchedule?.uploader ?? currentUser?.displayName,
      editor: currentUser?.displayName,
      attended: widget.existingSchedule?.attended ?? false, 
      additionalImages: widget.existingSchedule?.additionalImages, 
    );

    if (widget.existingSchedule != null) {
      if (updateImage && _selectedImage != null) {
        String? uploadedImageUrl = await uploadImage();
        if (uploadedImageUrl == null) return; 
        newOrUpdatedSchedule.imageUrl = uploadedImageUrl;
      }
      updateFireStoresSchedule(newOrUpdatedSchedule).then((_) {
        widget.onScheduleAdded(newOrUpdatedSchedule);
        if (mounted) Navigator.pop(context);
      }).catchError((e, s) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update schedule: $e')));
        log('Error updating schedule: $e', stackTrace: s);
      });
    } else {
      if (_selectedImage != null) {
         String? uploadedImageUrl = await uploadImage();
         if (uploadedImageUrl == null) return;
         newOrUpdatedSchedule.setImageURL(uploadedImageUrl);
      }
      newOrUpdatedSchedule.setUploader(currentUser?.displayName ?? 'Unknown');
      try {
        DocumentReference ref = await schedules_data.add({
          'time': newOrUpdatedSchedule.time.toIso8601String(),
          'agenda': newOrUpdatedSchedule.agenda,
          'applicant': newOrUpdatedSchedule.applicant,
          'address': newOrUpdatedSchedule.address,
          'remarks': newOrUpdatedSchedule.remarks,
          'imageUrl': newOrUpdatedSchedule.imageUrl ?? '',
          'uploader': newOrUpdatedSchedule.uploader,
          'editor': newOrUpdatedSchedule.editor,
          'attended': newOrUpdatedSchedule.attended,
          'additionalImages': newOrUpdatedSchedule.additionalImages ?? '',
        });
        newOrUpdatedSchedule.id = ref.id;
        sendNotification(newOrUpdatedSchedule);
        widget.onScheduleAdded(newOrUpdatedSchedule);
        if (mounted) Navigator.pop(context);
      } catch (e, s) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save new schedule: $e')));
        log('Error saving new schedule: $e', stackTrace: s);
        return;
      }
    }

    _clearForm();
    _scheduleAlarm(newOrUpdatedSchedule);
  }

  void _clearForm() {
    _agendaController.clear();
    _applicantController.clear();
    _addressController.clear();
    _remarksController.clear();
    if (mounted) setState(() { _selectedImage = null; imageUrl = ''; updateImage = false; });
  }

  Future<void> _scheduleAlarm(Schedule schedule) async {
     List<int> notificationIds = await getPendingNotificationIds();
    int newNotificationId = 0;
    while (notificationIds.contains(newNotificationId)) {
      newNotificationId++;
    }
    TimeOfDay? timeOfDay = await getSelectedTime();
    if (timeOfDay != null) {
      setAlarmTime(newNotificationId, schedule, timeOfDay);
    }
  }

  Future<void> selectImage() async {
    try {
      final picker = ImagePicker();
      final imageSource = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text("Select Image Source"),
          content: SingleChildScrollView(
            child: ListBody(children: [
              ListTile(leading: Icon(Icons.camera), title: Text("Camera"), onTap: () => Navigator.pop(context, ImageSource.camera)),
              SizedBox(height: 16),
              ListTile(leading: Icon(Icons.photo_library), title: Text("Gallery"), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ]),
          ),
        ),
      );
      if (imageSource != null) {
        final pickedFile = await picker.pickImage(source: imageSource);
        if (pickedFile != null && mounted) {
          setState(() {
            _selectedImage = File(pickedFile.path);
            if (widget.existingSchedule != null) updateImage = true; 
          });
        }
      }
    } catch (e, s) {
      print('Image selection error: $e');
      log('Stack trace: $s', stackTrace: s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to select image.')));
    }
  }

  Future<String?> uploadImage() async {
    if (_selectedImage == null) return null;
    try {
      final XFile? compressedXFile = await compressImage(_selectedImage!);
      if (compressedXFile == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image compression failed.')));
        return null;
      }
      File compressedFile = File(compressedXFile.path);
      final storageRef = firebase_storage.FirebaseStorage.instance.ref().child('schedules/${DateTime.now().millisecondsSinceEpoch}.webp');
      final uploadTask = storageRef.putFile(compressedFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();

      if (updateImage && widget.existingSchedule?.imageUrl != null && widget.existingSchedule!.imageUrl!.isNotEmpty) {
        try {
          await firebase_storage.FirebaseStorage.instance.refFromURL(widget.existingSchedule!.imageUrl!).delete();
        } catch (e, s) {
          log("Error deleting previous image: $e", stackTrace: s);
        }
      }
      return downloadURL;
    } catch (e, s) {
      log('Image upload error: $e', stackTrace: s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image.')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding( 
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16.0, left: 16.0, right: 16.0, top:16.0), // Adjust padding
      child: SingleChildScrollView( // Make form scrollable
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items nicely
              children: [
                Expanded(
                  flex: 2, // Give more space to date/time
                  child: Column(children: [
                     ListTile(
                        title: const Text('Date'),
                        subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                        onTap: _showDatePicker,
                        leading: Icon(Icons.calendar_today)),
                     ListTile(
                        title: const Text('Time'),
                        subtitle: Text(_selectedTime.format(context)),
                        onTap: _showTimePicker,
                        leading: Icon(Icons.access_time)),
                  ]),
                ),
                Expanded(
                  flex:1, // Less space for image preview
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Image", style: Theme.of(context).textTheme.labelSmall),
                      SizedBox(height: 4),
                      GestureDetector(
                        onTap: selectImage,
                        child: Container(
                          width: 60, height: 60, // Slightly larger preview
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
                          child: _selectedImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImage!, width: 60, height: 60, fit: BoxFit.cover))
                              : (widget.existingSchedule?.imageUrl != null && widget.existingSchedule!.imageUrl!.isNotEmpty && !updateImage)
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: widget.existingSchedule!.imageUrl!, width: 60, height: 60, fit: BoxFit.cover, placeholder: (context, url) => Icon(Icons.image, size:24, color: Colors.grey[500]), errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 24, color: Colors.grey[500])))
                                  : Icon(Icons.add_a_photo, color: Colors.grey[700], size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TextField(controller: _agendaController, decoration: const InputDecoration(labelText: 'विषय (Agenda)', icon: Icon(Icons.list_alt))),
            TextField(controller: _applicantController, decoration: const InputDecoration(labelText: 'निम्तो कर्ता (Applicant)', icon: Icon(Icons.person_outline))),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'ठेगाना (Address)', icon: Icon(Icons.location_on_outlined))),
            TextField(controller: _remarksController, decoration: const InputDecoration(labelText: 'कैफियत (Remarks)', icon: Icon(Icons.comment_outlined))),
            SizedBox(height: 20), 
            ElevatedButton(
              onPressed: _addSchedule,
              child: Text(widget.existingSchedule != null ? 'Update Schedule' : 'Add Schedule'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15)), 
            ),
          ],
        ),
      ),
    );
  }
}

/// Retrieves a list of pending notification IDs from [FlutterLocalNotificationsPlugin].
Future<List<int>> getPendingNotificationIds() async {
  List<PendingNotificationRequest> notifications = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  return notifications.map((notification) => notification.id).toList();
}

/// Retrieves the saved reminder time from [SharedPreferences].
/// Returns [TimeOfDay] if found, otherwise null.
Future<TimeOfDay?> getSelectedTime() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? selectedTime = prefs.getString('selectedTime');
  if (selectedTime != null) {
    List<String> timeParts = selectedTime.split(':');
    if (timeParts.length == 2) {
        int? hour = int.tryParse(timeParts[0]);
        int? minute = int.tryParse(timeParts[1]);
        if (hour != null && minute != null) {
            return TimeOfDay(hour: hour, minute: minute);
        }
    }
  }
  return null;
}

/// Schedules a zoned local notification for a given [schedule] at the [selectedTime].
Future<void> setAlarmTime(int notificationId, Schedule schedule, TimeOfDay selectedTime) async { 
  final DateTime now = DateTime.now();
  final DateTime notificationDateTime = DateTime(
      schedule.time.year, 
      schedule.time.month,
      schedule.time.day,
      selectedTime.hour, 
      selectedTime.minute);

  if (notificationDateTime.isBefore(now)) {
    print("Scheduled time $notificationDateTime is in the past. Notification not set.");
    return;
  }

  final String notificationTitle = '${DateFormat.jm().format(schedule.time)} - ${schedule.agenda}'; 
  final String notificationMessage = 'Reminder for: ${schedule.applicant}\nAddress: ${schedule.address}\nRemarks: ${schedule.remarks}';

  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'alarm_channel_id', 
    'Alarm Notifications',
    channelDescription: 'Channel for alarm clock style notifications',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    fullScreenIntent: true, 
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'), 
    usesChronometer: true,
    chronometerCountDown: true,
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails( 
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive, 
  );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  try {
    // Timezone initialization is done in main() now.
    // tz.initializeTimeZones(); 
    // final String currentTimeZone = await tz.FlutterTimezone.getLocalTimezone(); 
    // tz.setLocalLocation(tz.getLocation(currentTimeZone)); 

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      notificationTitle,
      notificationMessage,
      tz.TZDateTime.from(notificationDateTime, tz.local), 
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.alarmClock, 
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'alarm_payload_${schedule.id}',
    );
    print('Alarm set with ID $notificationId for ${tz.TZDateTime.from(notificationDateTime, tz.local)}');
  } catch (e, s) {
    print('Error scheduling zoned notification for setAlarmTime: $e');
    log('Stack trace for setAlarmTime zonedSchedule: $s', stackTrace: s);
  }
}


/// Main screen of the application, displaying schedules.
class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<DateEntry> _dateEntries = []; 
  TimeOfDay _selectedTime = TimeOfDay(hour: 10, minute: 1); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      loadSelectedTime(); 
      _loadSchedules();   
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _loadSchedules(); // Consider if this call is needed or optimal here.
  }

  Future<void> loadSelectedTime() async {
    TimeOfDay? selectedTime = await getSelectedTime(); 
    if (selectedTime != null && mounted) { 
      setState(() => _selectedTime = selectedTime);
    }
  }

  Future<void> saveSelectedTime(String selectedTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTime', selectedTime);
  }

  void _loadSchedules() {
    schedules_data.orderBy('time', descending: true).snapshots().listen((QuerySnapshot snapshot) { 
      final onlineSchedules = snapshot.docs.map((doc) {
        var scheduleData = doc.data() as Map<String, dynamic>?;
        if (scheduleData != null) {
          return Schedule(
            id: doc.id,
            time: DateTime.parse(scheduleData['time'] as String),
            agenda: scheduleData['agenda'] as String,
            applicant: scheduleData['applicant'] as String,
            address: scheduleData['address'] as String,
            remarks: scheduleData['remarks'] as String,
            attended: scheduleData['attended'] == 1, 
            imageUrl: scheduleData['imageUrl'] as String?,
            uploader: scheduleData['uploader'] as String?,
            editor: scheduleData['editor'] as String?,
            additionalImages: scheduleData['additionalImages'] as String?,
          );
        } else {
          return null;
        }
      }).whereType<Schedule>().toList(); 

      if (mounted) {
        setState(() => _dateEntries = _convertToEntries(onlineSchedules));
      }
    }, onError: (error, stackTrace) {
      print('Error in _loadSchedules: $error');
      log('Stack trace: $stackTrace', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedules. Please try again later.')),
        );
      }
    });
  }

  Future<List<Schedule>> getSchedulesFromFirestore() async {
    final QuerySnapshot event = await schedules_data.get();
    var schedules = <Schedule>[];
    for (var doc in event.docs) {
      var scheduleData = doc.data() as Map<String, dynamic>?;
      if (scheduleData != null) {
        schedules.add(Schedule(
          id: doc.id,
          time: DateTime.parse(scheduleData['time'] as String),
          agenda: scheduleData['agenda'] as String,
          applicant: scheduleData['applicant'] as String,
          address: scheduleData['address'] as String,
          remarks: scheduleData['remarks'] as String,
          attended: scheduleData['attended'] == 1,
          imageUrl: scheduleData['imageUrl'] as String?,
          uploader: scheduleData['uploader'] as String?,
          editor: scheduleData['editor'] as String?,
          additionalImages: scheduleData['additionalImages'] as String?,
        ));
      }
    }
    return schedules;
  }

  List<DateEntry> _convertToEntries(List<Schedule> schedules) {
    final Map<DateTime, List<Schedule>> scheduleMap = {};
    for (final schedule in schedules) {
      final date = DateTime(schedule.time.year, schedule.time.month, schedule.time.day);
      if (!scheduleMap.containsKey(date)) {
        scheduleMap[date] = [];
      }
      scheduleMap[date]!.add(schedule);
    }
    final List<DateEntry> dateEntries = [];
    for (final entry in scheduleMap.entries) {
      entry.value.sort((a, b) => a.time.compareTo(b.time));
      dateEntries.add(DateEntry(date: entry.key, schedules: entry.value));
    }
    dateEntries.sort((a, b) => b.date.compareTo(a.date));
    return dateEntries;
  }

  void _cancelReminder() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    await saveSelectedTime("10:1"); 
    if (mounted) loadSelectedTime(); 
    print('All reminders canceled and time reset.');
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All reminders cancelled.')));
  }

  void _showTimePicker() async {
    final initialTime = _selectedTime;
    final selectedTime = await showTimePicker(context: context, initialTime: initialTime);

    if (selectedTime != null && mounted) {
      setState(() => _selectedTime = selectedTime);
      await saveSelectedTime('${selectedTime.hour}:${selectedTime.minute}');
      await flutterLocalNotificationsPlugin.cancelAll(); 
      print('All pending alarms canceled. Re-scheduling with new time.');

      int notificationId = 0;
      for (var dateEntry in _dateEntries) {
        for (var schedule in dateEntry.schedules) {
          if (!_isPastDate(schedule.time)) { 
            setAlarmTime(notificationId, schedule, selectedTime);
            notificationId++;
          }
        }
      }
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminders updated to ${selectedTime.format(context)}')),
      );
    }
  }

  void _addSchedule(Schedule schedule) async {
    _loadSchedules(); 
  }

  void _deleteSchedule(Schedule schedule) async {
    try {
      await deleteFireStoreSchedule(schedule); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule successfully deleted.')));
      }
    } catch (error, stackTrace) {
      print('Error in _deleteSchedule: $error');
      log('Stack trace: $stackTrace', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete schedule. Please try again.')),
        );
      }
    }
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _getDateBackgroundColor(bool isEven) {
    return isEven ? Color(0xFFE8F5E9) : Color(0xFFE3F2FD); // Softer alternating colors
  }

  void _showImageGallery(int initialIndex, List<String> imageUrls) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, 
      pageBuilder: (context, animation, secondaryAnimation) => PhotoViewGallery.builder(
        itemCount: imageUrls.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(imageUrls[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        scrollPhysics: BouncingScrollPhysics(),
        pageController: PageController(initialPage: initialIndex),
        backgroundDecoration: BoxDecoration(color: Colors.black.withOpacity(0.9)), 
        loadingBuilder: (context, event) => Center(child: CircularProgressIndicator()),
      ),
    ));
  }
  
  Future<void> selectImage(Schedule schedule) async {
    try {
      final picker = ImagePicker();
      final imageSource = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text("Select Image Source"),
          content: SingleChildScrollView(
            child: ListBody(children: [
              ListTile(leading: Icon(Icons.camera_alt), title: Text("Camera"), onTap: () => Navigator.pop(context, ImageSource.camera)),
              SizedBox(height: 16),
              ListTile(leading: Icon(Icons.photo_library), title: Text("Gallery"), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ]),
          ),
        ),
      );

      if (imageSource != null) {
        final pickedFile = await picker.pickImage(source: imageSource);
        if (pickedFile != null && mounted) {
          File selectedImageFile = File(pickedFile.path);
          String? uploadedImageUrl = await uploadImage(selectedImageFile); 
          if (uploadedImageUrl != null) {
            if (schedule.additionalImages != null && schedule.additionalImages!.isNotEmpty) {
              schedule.additionalImages = "$uploadedImageUrl,${schedule.additionalImages!}"; 
            } else {
              schedule.additionalImages = uploadedImageUrl;
            }
            await updateFireStoresSchedule(schedule).catchError((e,s) { 
              print('Error updating schedule after adding image in _ScheduleScreenState.selectImage: $e');
              log('Stack trace: $s', stackTrace: s);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save image details. Please try again.')),
                );
              }
            });
             _loadSchedules(); 
          }
        }
      }
    } catch (error, stackTrace) {
      print('Image Select error in _ScheduleScreenState.selectImage: $error');
      log('Stack trace: $stackTrace', stackTrace: stackTrace);
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to select or upload image.')),
          );
       }
    }
  }

  Future<String?> uploadImage(File imageFile) async { 
    try {
      XFile? compressedXFile = await compressImage(imageFile); 
      if (compressedXFile == null) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image compression failed.')));
        return null;
      }
      File compressedFile = File(compressedXFile.path);
      final storageRef = firebase_storage.FirebaseStorage.instance.ref().child('schedules_additional/${DateTime.now().millisecondsSinceEpoch}.webp');
      final uploadTask = storageRef.putFile(compressedFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (error, stackTrace) {
      print('Image upload error in _ScheduleScreenState.uploadImage (additional): $error');
      log('Stack trace: $stackTrace', stackTrace: stackTrace);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload additional image.')));
      return null; 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule App'),
        actions: [
          IconButton( // Navigation to ActivityAnalysisScreen
            icon: Icon(Icons.analytics_outlined), // Changed icon
            tooltip: 'Activity Analysis',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ActivityAnalysisScreen()),
              );
            },
          ),
          TextButton.icon( // Reminder button
            icon: Icon(Icons.alarm, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(
              _selectedTime.hour == 10 && _selectedTime.minute == 1 ? 'Set Reminder' : _selectedTime.format(context),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            onPressed: _showTimePicker,
            style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8)),
          ),
          if (!(_selectedTime.hour == 10 && _selectedTime.minute == 1))
            IconButton(
              icon: Icon(Icons.alarm_off_outlined, color: Colors.red[300]), // Changed icon
              onPressed: _cancelReminder,
              tooltip: 'Cancel All Reminders',
            ),
          Padding( 
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center( 
              child: GestureDetector(
                 onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Decisions())),
                 child: const Text('Developer: Mukesh Pokharel', style: TextStyle(fontSize: 8, color: Colors.white70)) // Reduced font size
              ),
            ),
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary, 
        foregroundColor: Theme.of(context).colorScheme.onPrimary, 
      ),
      body: ListView.builder(
        itemCount: _dateEntries.length,
        itemBuilder: (context, index) {
          final dateEntry = _dateEntries[index];
          final isEvenDate = index % 2 == 0;
          return _buildDateEntryCard(dateEntry, isEvenDate);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, 
            builder: (context) => Padding( 
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ScheduleForm(onScheduleAdded: _addSchedule),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDateEntryCard(DateEntry dateEntry, bool isEvenDate) {
    final isToday = _isToday(dateEntry.date);
    final isPast = _isPastDate(dateEntry.date) && !isToday; // Ensure today is not also marked as past for this specific style

    TextStyle dateTextStyle;
    if (isToday) {
      dateTextStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 16); // Emphasize today
    } else if (isPast) {
      dateTextStyle = TextStyle(fontWeight: FontWeight.normal, color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 14);
    } else { // Future dates
      dateTextStyle = TextStyle(fontWeight: FontWeight.normal, color: Colors.black87, fontSize: 15);
    }
    
    final dateBackgroundColor = isToday ? Colors.amber[100] : _getDateBackgroundColor(isEvenDate); // Highlight today's card

    return Card(
      color: dateBackgroundColor,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 5), // Adjusted margin
      elevation: isToday ? 4 : 2, // More elevation for today
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out date and Nepali date
              children: [
                Text(DateFormat.yMMMd().format(dateEntry.date), style: dateTextStyle),
                Text(
                  '${DateConverter.convertEnglishDateToNepali(dateEntry.date.year, dateEntry.date.month, dateEntry.date.day)}   ${DateConverter.getNepaliDayOfWeekInString(DateFormat('EEEE').format(dateEntry.date))}',
                  style: dateTextStyle.copyWith(fontSize: dateTextStyle.fontSize! * 0.9), // Slightly smaller Nepali date
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, indent: 16, endIndent: 16), // Divider
          ...dateEntry.schedules.map((schedule) {
            final isEvenTime = dateEntry.schedules.indexOf(schedule) % 2 == 0;
            return _buildScheduleCard(schedule, isEvenTime, isToday); // Pass isToday for context
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule, bool isEvenTime, bool isTodayInDateCard) {
    final isPast = _isPastDate(schedule.time);
    final isScheduleToday = _isToday(schedule.time);

    Color tileColor;
    TextStyle titleStyle;
    TextStyle subtitleStyle;
    TextStyle uploaderEditorStyle = TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[700]);


    if (isPast) {
      tileColor = schedule.attended ? Colors.green.shade50 : Colors.blue.shade50;
      titleStyle = TextStyle(color: schedule.attended ? Colors.green[800] : Colors.blue[800], fontWeight: FontWeight.w500);
      subtitleStyle = TextStyle(color: schedule.attended ? Colors.green[700] : Colors.blue[700]);
    } else if (isScheduleToday) {
      tileColor = Colors.orange.shade50; // Highlight for today's schedules
      titleStyle = TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold);
      subtitleStyle = TextStyle(color: Colors.orange[700]);
    } else { // Future schedules
      tileColor = isEvenTime ? Colors.grey[50]! : Colors.white;
      titleStyle = TextStyle(color: Colors.black87, fontWeight: FontWeight.w500);
      subtitleStyle = TextStyle(color: Colors.black54);
    }

    return Card(
      color: tileColor,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: GestureDetector(
        onLongPress: () {
          if (!isPast) { 
            showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: Text('Modify Schedule'),
                content: Text('Edit or delete this schedule?'),
                actions: <Widget>[
                  TextButton(child: Text('Edit'), onPressed: () { Navigator.of(context).pop(); showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: ScheduleForm(onScheduleAdded: _addSchedule, existingSchedule: schedule))); }),
                  TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
                  TextButton(child: Text('Delete', style: TextStyle(color: Colors.red)), onPressed: () { Navigator.of(context).pop(); _deleteSchedule(schedule); }),
                ],
              ),
            );
          }
        },
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Row(children: [
            Text(DateFormat.jm().format(schedule.time), style: titleStyle.copyWith(fontSize: 16)),
            SizedBox(width: 10),
            Expanded(child: Text(schedule.agenda, style: titleStyle.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis)), // Agenda next to time
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 5),
            Text('Applicant: ${schedule.applicant}', style: subtitleStyle),
            Text('Address: ${schedule.address}', style: subtitleStyle),
            if (schedule.remarks.isNotEmpty) Text('Remarks: ${schedule.remarks}', style: subtitleStyle),
             if (schedule.imageUrl != null && schedule.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: GestureDetector(
                  onTap: () {
                    List<String> imageUrls = [schedule.imageUrl!];
                    if (schedule.additionalImages != null && schedule.additionalImages!.isNotEmpty) {
                      imageUrls.addAll(schedule.additionalImages!.split(",").where((url) => url.trim().isNotEmpty));
                    }
                    _showImageGallery(0, imageUrls);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 16, color: Colors.blueAccent),
                      Text(" View Image${(schedule.additionalImages?.split(",").where((s) => s.isNotEmpty).length ?? 0) > 0 ? 's (${1 + (schedule.additionalImages?.split(",").where((s) => s.isNotEmpty).length ?? 0)})' : ''}", style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                    ],
                  ),
                ),
              ),
            if (!isPast) 
                IconButton(icon: Icon(Icons.add_a_photo_outlined, size: 20, color: Colors.grey[600]), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => selectImage(schedule), tooltip: "Add more images"),

            if ((schedule.uploader != null && schedule.uploader!.isNotEmpty) || (schedule.editor != null && schedule.editor!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (schedule.uploader != null && schedule.uploader!.isNotEmpty) Text('Uploaded by: ${schedule.uploader}', style: uploaderEditorStyle),
                    if (schedule.editor != null && schedule.editor!.isNotEmpty) Text((schedule.uploader != null && schedule.uploader!.isNotEmpty ? ' | ' : '') + 'Edited by: ${schedule.editor}', style: uploaderEditorStyle),
                  ],
                ),
              )
          ]),
          trailing: isPast
              ? Checkbox(
                  value: schedule.attended,
                  activeColor: Colors.green[700],
                  onChanged: (newValue) {
                    if (mounted) {
                      setState(() {
                        schedule.setAttended(newValue ?? false);
                        schedule.setEditor(currentUser?.displayName ?? 'Unknown');
                      });
                      updateFireStoresSchedule(schedule).catchError((e, s) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update attendance.')));
                          setState(() { schedule.setAttended(!schedule.attended); }); 
                        }
                        log('Error updating attendance: $e', stackTrace: s);
                      });
                    }
                  },
                )
              : null, 
        ),
      ),
    );
  }
}

/// Deletes a [schedule] document from Firestore and its associated images from Firebase Storage.
Future<void> deleteFireStoreSchedule(Schedule schedule) async {
  if (schedule.id == null || schedule.id!.isEmpty) {
    print("Cannot delete schedule: ID is null or empty.");
    return;
  }
  try {
    await schedules_data.doc(schedule.id).delete();

    if (schedule.imageUrl != null && schedule.imageUrl!.isNotEmpty) {
      try {
        await firebase_storage.FirebaseStorage.instance.refFromURL(schedule.imageUrl!).delete();
      } catch (e, s) {
        print('Error deleting main image for schedule ${schedule.id}: $e');
        log('Stack trace: $s', stackTrace: s);
      }
    }
    if (schedule.additionalImages != null && schedule.additionalImages!.isNotEmpty) {
      List<String> images = schedule.additionalImages!.split(",").where((url) => url.trim().isNotEmpty).toList();
      for (String url in images) {
        try {
          await firebase_storage.FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e, s) {
          print('Error deleting additional image $url for schedule ${schedule.id}: $e');
          log('Stack trace: $s', stackTrace: s);
        }
      }
    }
  } catch (e, s) {
    print('Error deleting schedule document ${schedule.id}: $e');
    log('Stack trace: $s', stackTrace: s);
    throw Exception('Failed to delete schedule from Firestore');
  }
}

/// Updates a [Schedule] in Firestore.
Future<void> updateFireStoresSchedule(Schedule schedule) async {
   if (schedule.id == null || schedule.id!.isEmpty) {
    print("Cannot update schedule: ID is null or empty.");
    throw Exception('Schedule ID is missing, cannot update.');
  }
  try {
    await schedules_data.doc(schedule.id).set({
      'time': schedule.time.toIso8601String(),
      'agenda': schedule.agenda,
      'applicant': schedule.applicant,
      'address': schedule.address,
      'remarks': schedule.remarks,
      'attended': schedule.attended ? 1 : 0,
      'imageUrl': schedule.imageUrl ?? '', 
      'uploader': schedule.uploader ?? '',
      'editor': schedule.editor ?? '',
      'additionalImages': schedule.additionalImages ?? '',
    }, SetOptions(merge: true));
  } catch (e, s) {
    print('Error writing document in updateFireStoresSchedule: $e');
    log('Stack trace: $s', stackTrace: s);
    throw Exception('Failed to update schedule in Firestore');
  }
}

/// A StatelessWidget that provides a full-screen, zoomable view of an image.
class ZoomableImagePage extends StatelessWidget {
  final String imageUrl;

  const ZoomableImagePage({required this.imageUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View Image')), 
      backgroundColor: Colors.black, 
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(), 
        child: Center( 
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            backgroundDecoration: BoxDecoration(color: Colors.transparent), 
            loadingBuilder: (context, event) => Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.error, color: Colors.red)), 
          ),
        ),
      ),
    );
  }
}
