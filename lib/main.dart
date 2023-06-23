import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'DateConvert.dart';
import 'Decisions.dart';
import 'Schedule.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// import 'package:flutter_alarm_clock/flutter_alarm_clock.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;
FirebaseMessaging messaging = FirebaseMessaging.instance;
FirebaseAdmin admin = FirebaseAdmin.instance;
CollectionReference schedules_data = firestoreInstance.collection('schedules');
CollectionReference tokens_data = firestoreInstance.collection('tokens');
CollectionReference settings_firestore =
    firestoreInstance.collection('settings');

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void sendNotification(Schedule schedule) async {
  // QuerySnapshot querySnapshot = await settings_firestore.doc("serverid").get();
  DocumentSnapshot snapshot = await FirebaseFirestore.instance
      .collection("settings")
      .doc("serverid")
      .get();
  var serverKey = '';
  if (snapshot.exists) {
    var data = snapshot.data() as Map<String, dynamic>;
    serverKey = data['serverKey'];
    // print('Server Key: $serverKey');
  } else {
    print('Document does not exist');
  }

  try {
    //Send  Message
    http.Response response =
        await http.post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'key=$serverKey',
            },
            body: constructFCMPayload(schedule));

    log("status: ${response.statusCode} | Message Sent Successfully!");
  } catch (e) {
    log("error push notification $e");
  }
}

String constructFCMPayload(Schedule schedule) {
  return jsonEncode(
    <String, dynamic>{
      'notification': <String, dynamic>{
        'body':
            "निम्तो कर्ताः ${schedule.applicant}\n ठेगाानाः ${schedule.address}\nकैफियतः ${schedule.remarks}",
        'title':
            "विषय: ${schedule.agenda} ---> \n${DateConverter.convertEnglishDateToNepali(
          schedule.time.year,
          schedule.time.month,
          schedule.time.day,
        )}-> ${DateFormat.Hm().format(schedule.time)}",
      },
      'data': <String, dynamic>{
        'name': "Mukesh Pokharel",
        'time': "Schedule Time",
        'service': "Service",
        'status': "Status",
        'id': "id"
      },
      'to': '/topics/notification',
    },
  );
}

List<dynamic>? authenticatedUsers;
User? currentUser;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the plugin.

  // await DatabaseHelper.initialize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  _registerFirebaseMessaging();

  firestoreInstance
      .collection('settings')
      .doc('authenticatedUsers')
      .snapshots()
      .listen((snapshot) {
    authenticatedUsers = snapshot.data()?['emails'];
    print("data changed");
    runApp(const MyApp());
  });
}

Future<void> _registerFirebaseMessaging() async {
  String? token = await messaging.getToken();

  QuerySnapshot querySnapshot =
      await tokens_data.where('token', isEqualTo: token).get();
  if (querySnapshot.docs.isEmpty) {
    // Token does not exist, add a new document
    await messaging.subscribeToTopic("notification");
    Map<String, dynamic> data = {'token': token};
    await tokens_data.add(data);
  } else {
    // Token already exists, handle accordingly
    print('Token already exists in the database.');
  }

  print('Firebase Messaging token: $token');

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // Handle incoming notifications when the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received foreground notification: ${message.notification?.body}');
    _showLocalNotification(
      flutterLocalNotificationsPlugin,
      message.notification?.title,
      message.notification?.body,
    );
  });

  // Handle incoming notifications when the app is in the background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Received background notification: ${message.notification?.body}');
  _showLocalNotification(
    FlutterLocalNotificationsPlugin(),
    message.notification?.title,
    message.notification?.body,
  );
}

Future<void> _showLocalNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    String? title,
    String? body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'channel_id',
    'channel_name',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true, // Enable playing sound
  );
  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails();
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
    payload: 'notification_payload',
  );
}

void retrieveData() {
  schedules_data // Replace with your collection name
      .get()
      .then((QuerySnapshot querySnapshot) {
    if (querySnapshot.docs.isNotEmpty) {
      // Loop through the documents
      querySnapshot.docs.forEach((doc) {
        // Access the document data using doc.data()
        var data = doc.data();
      });
    } else {
      print('No documents found.');
    }
  }).catchError((error) => print('Error retrieving data: $error'));
}

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return this.year == other.year &&
        this.month == other.month &&
        this.day == other.day;
  }
}

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
            // Firebase authentication state is still loading
            return CircularProgressIndicator();
          } else if (snapshot.hasData) {
            // User is logged in, show the ScheduleScreen
            currentUser = snapshot.data!;

            if (authenticatedUsers!.contains(currentUser?.email))
              return ScheduleScreen();
            else
              return CircularProgressIndicator();
          } else {
            // User is not logged in, show the login screen
            return LoginScreen();
          }
        },
      ),
    );
  }
}

class DateEntry {
  final DateTime date;
  final List<Schedule> schedules;

  DateEntry({
    required this.date,
    required this.schedules,
  });
}

Future<bool> _isUserAuthenticated(String email) async {
  print("authenticating user");
  final settingsDocRef =
      firestoreInstance.collection('settings').doc('authenticatedUsers');
  bool isUserAuthenticated = false;

  await firestoreInstance
      .collection('settings')
      .doc('authenticatedUsers')
      .snapshots()
      .listen((snapshot) {
    print("upup");
    final List<dynamic>? emails = snapshot.data()?['emails'];
    print(emails);
    print("emails printed");

    if (emails != null && emails.contains(email)) {
      isUserAuthenticated = true;
    } else {
      isUserAuthenticated = false;
    }
  });
  print("haha");

  return isUserAuthenticated;
}

class LoginScreen extends StatelessWidget {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '707616392800-d9dbkbpgf3dha27v4tmodrfrp4529b74.apps.googleusercontent.com',
  );

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      return userCredential;
    } catch (error) {
      print('Google sign-in error: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            UserCredential? userCredential = await _signInWithGoogle();
            if (userCredential != null) {
              // User logged in successfully, handle the navigation or any other logic
              // For example, you can navigate to the ScheduleScreen:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MyApp(),
                ),
              );
            }
          },
          child: Text('Sign in with Google'),
        ),
      ),
    );
  }
}

class ScheduleForm extends StatefulWidget {
  final void Function(Schedule) onScheduleAdded;

  final Schedule? existingSchedule; // Add the existingSchedule parameter

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
  var imageUrl = '';
  bool updateImage = false;
  Schedule? existingSchedule; // Declare the variable here
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    if (widget.existingSchedule != null) {
      existingSchedule = widget.existingSchedule;
      _selectedDate = widget.existingSchedule!.time;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingSchedule!.time);
      _agendaController.text = widget.existingSchedule!.agenda;
      _applicantController.text = widget.existingSchedule!.applicant;
      _addressController.text = widget.existingSchedule!.address;
      _remarksController.text = widget.existingSchedule!.remarks;
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

    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
      });
    }
  }

  void _showTimePicker() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selectedTime != null) {
      setState(() {
        _selectedTime = selectedTime;
      });
    }
  }

  Future<List<Map<String, dynamic>>> getAllTokens() async {
    QuerySnapshot querySnapshot = await tokens_data.get();
    List<Map<String, dynamic>> tokens = [];
    for (DocumentSnapshot doc in querySnapshot.docs) {
      tokens.add(doc.data as Map<String, dynamic>);
    }
    return tokens;
  }

  void _addSchedule() async {
    final schedule = Schedule(
      time: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
        DateTime.now().second,
      ),
      agenda: _agendaController.text,
      applicant: _applicantController.text,
      address: _addressController.text,
      remarks: _remarksController.text,
    );
    // imageUrl='';
    _agendaController.clear();
    _applicantController.clear();
    _addressController.clear();
    _remarksController.clear();
    // Navigator.pop(context);
    widget.onScheduleAdded(schedule);
    if (existingSchedule != null) {
      // Update the existing schedule
      schedule.uploader = existingSchedule!.uploader;

      schedule.editor = currentUser!.displayName;
      schedule.id = existingSchedule!.id;
      if (updateImage) {
        await uploadImage();
        schedule.imageUrl = imageUrl;
      } else {
        schedule.imageUrl = existingSchedule!.imageUrl;
      }

      updateFireStoresSchedule(schedule);

      // Update any other properties as needed

      // Call the callback function to inform the parent widget about the updated schedule
    } else {
      await uploadImage(); // this also gets u url.
      schedule.setImageURL(imageUrl);
      schedule.setUploader(currentUser?.displayName ?? '');

      schedules_data.doc(schedule.time.toIso8601String()).set({
        'time': schedule.time.toIso8601String(),
        'agenda': schedule.agenda,
        'applicant': schedule.applicant,
        'address': schedule.address,
        'remarks': schedule.remarks,
        'imageUrl': schedule.imageUrl,
        'uploader': schedule.uploader,
      }, SetOptions(merge: true)).onError(
          (e, _) => print("Error writing document: $e"));

      sendNotification(schedule);
    }
    // get a list of notifications id
    List<int> notificationIds = await getPendingNotificationIds();
    print(notificationIds);
    // get next notificationId
    int newNotificationId = 0; // Start with the initial ID value

    while (notificationIds.contains(newNotificationId)) {
      newNotificationId++; // Increment the ID until a unique ID is found
    }
    TimeOfDay? timeOfDay = await getSelectedTime();
    setAlarmTime(newNotificationId, schedule, timeOfDay!);
  }

  Future<void> selectImage() async {
    try {
      final picker = ImagePicker();
      final imageSource = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text("Select Image Source"),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                ListTile(
                  leading: Icon(Icons.camera),
                  title: Text("Camera"),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text("Gallery"),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      if (imageSource != null) {
        final pickedFile = await picker.pickImage(source: imageSource);
        if (pickedFile != null) {
          if (existingSchedule != null) updateImage = true;
          setState(() {
            _selectedImage = File(pickedFile.path);
          });
        }
      }
    } catch (error) {
      // Handle any errors that occur during image upload
      print('Image Select error: $error');
    }
  }


  Future<String?> uploadImage() async {
    try {
      if (_selectedImage != null) {
        // Compress the image
        final compressedImage = await compressImage(_selectedImage!);

        if (compressedImage != null) {
          // Upload the compressed image to Firebase Storage
          final storageRef = firebase_storage.FirebaseStorage.instance
              .ref()
              .child('schedules/${DateTime.now().millisecondsSinceEpoch}.webp');
          final uploadTask = storageRef.putFile(File(compressedImage.path));

          // Get the image URL after upload completes
          final snapshot = await uploadTask.whenComplete(() {});
          final downloadURL = await snapshot.ref.getDownloadURL();

          //delete the existing image if exists
          if (updateImage) {
            // Get the current image URL from the schedule object
            final currentImageUrl = existingSchedule!.imageUrl;
            // Delete the previous image from Firebase Storage if it exists
            if (currentImageUrl != null) {
              final storageRef = firebase_storage.FirebaseStorage.instance
                  .refFromURL(currentImageUrl);
              await storageRef.delete();
            }
          }
          // Save the image URL to the schedule object

          imageUrl = downloadURL;

          return imageUrl; // Return the download URL
        }
      }
    } catch (error) {
      // Handle any errors that occur during image upload
      print('Image upload error: $error');
    }

    return null; // Return null if image upload fails or no image selected
  }

  Future<XFile?> compressImage(File file) async {
    try {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        '${file.path}.webp',
        quality: 10,
        format: CompressFormat.webp,
      );

      return compressedFile;
    } catch (error) {
      // Handle any errors that occur during image compression
      print('Image compression error: $error');
      return null; // Return null if compression fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Date'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(_selectedDate),
                    ),
                    Text(
                      DateConverter.convertEnglishDateToNepali(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue, // Replace with your desired color
                      ),
                    ),
                  ],
                ),
                onTap: _showDatePicker,
              ),
            ),
            Expanded(
              child: ListTile(
                title: const Text('Time'),
                subtitle: Text(_selectedTime.format(context)),
                onTap: _showTimePicker,
              ),
            ),
            Expanded(
              child: ListTile(
                trailing: GestureDetector(
                  onTap: selectImage,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(
              left: 8.0), // Adjust the padding as per your preference
          child: Column(
            children: [
              TextField(
                controller: _agendaController,
                decoration: const InputDecoration(labelText: 'विषय'),
              ),
              TextField(
                controller: _applicantController,
                decoration: const InputDecoration(labelText: 'निम्तो कर्ता'),
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'ठेगाना'),
              ),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'कैफियत'),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _addSchedule,
          child: Text(widget.existingSchedule != null
              ? 'Update Schedule'
              : 'Add Schedule'),
        ),
      ],
    );
  }
}

Future<List<int>> getPendingNotificationIds() async {
  List<PendingNotificationRequest> notifications =
      await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  List<int> notificationIds =
      notifications.map((notification) => notification.id).toList();
  return notificationIds;
}

Future<TimeOfDay?> getSelectedTime() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? selectedTime = prefs.getString('selectedTime');
  print("selectedTime: $selectedTime");
  if (selectedTime != null) {
    List<String> timeParts = selectedTime.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }
  return null; // Return null if no time is saved
}
Future<void> setAlarmTime(int notificationId, Schedule schedule,TimeOfDay _selectedTime) async {

  final DateTime notificationTime =
  DateTime(schedule.time.year, schedule.time.month,
      schedule.time.day, _selectedTime.hour, _selectedTime.minute);
  final String notificationTitle = '${DateFormat.jm().format(schedule.time)}--${schedule.agenda}';
  final String notificationMessage = '${schedule.applicant}\n ${schedule.address}\n ${schedule.remarks}';
  // Schedule the alarm notification
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'channel_id',
    'channel_name',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    fullScreenIntent: true,
    color: Colors.red,
    playSound: true,
    usesChronometer: true, // Enable the chronometer
    chronometerCountDown: true, // Set the chronometer to count down

    // Enable playing sound
    sound: RawResourceAndroidNotificationSound('alarm'),

  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
  DarwinNotificationDetails();
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );
  tz.initializeTimeZones();
  final location = tz.local;

  await flutterLocalNotificationsPlugin.zonedSchedule(
    notificationId,
    notificationTitle,
    notificationMessage,
    tz.TZDateTime.from(notificationTime, location),
    platformChannelSpecifics,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    androidScheduleMode: AndroidScheduleMode.alarmClock,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
    payload: 'alarm_payload',
  );
  // FlutterAlarmClock.createAlarm(selectedTime.hour, selectedTime.minute);

  print('Alarm set for ${tz.TZDateTime.from(notificationTime, location)}');
}



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
    _loadSchedules();
  }

  Future<void> loadSelectedTime() async {
    TimeOfDay? selectedTime = await getSelectedTime();
    if (selectedTime != null) {
      setState(() {
        _selectedTime = selectedTime;
      });
    }
  }
  Future<void> saveSelectedTime(String selectedTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print("saving shared");
    await prefs.setString('selectedTime', selectedTime);
  }

  void _loadSchedules() {
    schedules_data.snapshots().listen((QuerySnapshot snapshot) {
      final onlineSchedules = snapshot.docs
          .map((doc) {
            var scheduleData = doc.data() as Map<String, dynamic>?;

            if (scheduleData != null) {
              var schedule = Schedule(
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
              );
              // print(schedule.id);
              // print("IDS");

              return schedule;
            } else {
              return null;
            }
          })
          .whereType<Schedule>()
          .toList();

      setState(() {
        _dateEntries = _convertToEntries(onlineSchedules);
      });
    }, onError: (error) {
      print('Error retrieving data: $error');
    });
  }

  Future<List<Schedule>> getSchedulesFromFirestore() async {
    final QuerySnapshot event = await schedules_data.get();
    var schedules = <Schedule>[];

    for (var doc in event.docs) {
      var scheduleData = doc.data() as Map<String, dynamic>?;

      if (scheduleData != null) {
        var schedule = Schedule(
          time: DateTime.parse(scheduleData['time'] as String),
          agenda: scheduleData['agenda'] as String,
          applicant: scheduleData['applicant'] as String,
          address: scheduleData['address'] as String,
          remarks: scheduleData['remarks'] as String,
          attended: scheduleData['attended'] == 1,
        );
        schedules.add(schedule);
      }
    }

    return schedules;
  }

  List<DateEntry> _convertToEntries(List<Schedule> schedules) {
    final Map<DateTime, List<Schedule>> scheduleMap = {};

    for (final schedule in schedules) {
      final date = DateTime(
        schedule.time.year,
        schedule.time.month,
        schedule.time.day,
      );

      if (!scheduleMap.containsKey(date)) {
        scheduleMap[date] = [];
      }

      scheduleMap[date]!.add(schedule);
    }

    final List<DateEntry> dateEntries = [];

    for (final entry in scheduleMap.entries) {
      dateEntries.add(DateEntry(date: entry.key, schedules: entry.value));
    }

    dateEntries.sort((a, b) => b.date.compareTo(a.date));

    return dateEntries;
  }
  void _cancelReminder () async {
    await flutterLocalNotificationsPlugin.cancelAll();
    await saveSelectedTime("10:1");
    await loadSelectedTime();

  }
  void _showTimePicker() async {
    final initialTime = _selectedTime ??
        TimeOfDay
            .now(); // Use TimeOfDay.now() as default if _selectedTime is null
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime!,
    );
    if (selectedTime != null) {
      setState(() {
        _selectedTime = selectedTime;
      });
      saveSelectedTime('${selectedTime.hour}:${selectedTime.minute}');
      // get a list of schedules to update notification time.
      await flutterLocalNotificationsPlugin.cancelAll();
      print('All pending schedules have been canceled.');

      int notificationId = 0;
      TimeOfDay? timeOfDay = await getSelectedTime();
      List<Schedule> validSchedules = [];
      for (var dateEntry in _dateEntries) {
        for (var schedule in dateEntry.schedules) {
          if (!_isPastDate(schedule.time)) {
            validSchedules.add(schedule);
            setAlarmTime(
                notificationId,
                schedule,timeOfDay!);
            notificationId++;
          }
        }
      }
    }
  }








  void _addSchedule(Schedule schedule) async {
    final isPastDate = _isPastDate(schedule.time);
    // schedule.attended = isPastDate;
    final dateEntry = _dateEntries.firstWhere(
      (entry) => entry.date.isSameDate(schedule.time),
      orElse: () {
        final newEntry = DateEntry(
          date: schedule.time,
          schedules: [],
        );
        _dateEntries.add(newEntry);
        return newEntry;
      },
    );

    dateEntry.schedules.add(schedule);

    _dateEntries.sort((a, b) => b.date.compareTo(a.date));

    setState(() {});

    Navigator.pop(context); // Dismiss the schedule form screen
  }

  void _deleteSchedule(Schedule schedule) async {
    deleteFireStoreSchedule(schedule);
    setState(() {
      _dateEntries.forEach((dateEntry) {
        dateEntry.schedules.remove(schedule);
        if (dateEntry.schedules.isEmpty) {
          _dateEntries.remove(dateEntry);
        }
      });
    });
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Color _getDateBackgroundColor(bool isEven) {
    if (isEven) {
      return Color(0x90C2FFAE);
    } else {
      return Colors.blue.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Schedule App'),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                _showTimePicker(); // Function to display time picker
              },
              child: Text(
                _selectedTime?.hour == 10 && _selectedTime?.minute == 1
                    ? 'Set Reminder'
                    : _selectedTime?.format(context) ?? 'Set Time',
              ),
            ),

            Visibility(
              visible: _selectedTime?.hour != 10 || _selectedTime?.minute != 1,
              child: IconButton(
                onPressed: () {
                  _cancelReminder(); // Function to cancel the reminder
                },
                icon: Icon(
                  Icons.close,
                  color: Colors.red,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Decisions()),
                );
              },
              child: const Text(
                'Developer: Mukesh Pokharel',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),

      ),
      body: ListView.builder(
        itemCount: _dateEntries.length,
        itemBuilder: (context, index) {
          final dateEntry = _dateEntries[index];
          final isEvenDate = index % 2 == 0;
          final isToday = _isToday(dateEntry.date);
          final dateBackgroundColor =
              isToday ? Color(0xFF90F9E4) : _getDateBackgroundColor(isEvenDate);

          return Column(
            children: [
              Container(
                color: dateBackgroundColor,
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(dateEntry.date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.red : Colors.black,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            '${DateConverter.convertEnglishDateToNepali(
                              dateEntry.date.year,
                              dateEntry.date.month,
                              dateEntry.date.day,
                            )}   ${DateConverter.getNepaliDayOfWeekInString(DateFormat('EEEE').format(dateEntry.date))}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isToday ? Colors.red : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: dateEntry.schedules.length,
                itemBuilder: (context, index) {
                  final schedule = dateEntry.schedules[index];
                  final isEvenTime = index % 2 == 0;

                  final isPastDate = _isPastDate(schedule.time);

                  final scheduleColor = isPastDate
                      ? (schedule.attended ? Colors.green : Colors.red)
                      : null;

                  return Container(
                      color: isToday
                          ? dateBackgroundColor
                          : isEvenTime
                              ? Colors.grey[100]
                              : Colors.white,
                      child: GestureDetector(
                        onLongPress: () {
                          if (!isPastDate)
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Delete Schedule'),
                                  content: Text(
                                      'Are you sure you want to delete this schedule?'),
                                  actions: <Widget>[
                                    ElevatedButton(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all(
                                                Colors.blue),
                                        // Customize the button style as desired
                                      ),
                                      child: Text(
                                        'Edit',
                                        style: TextStyle(
                                          color: Colors.white,
                                          // Set the text color to red
                                        ),
                                      ),
                                      onPressed: () {
                                        // Add your edit functionality here
                                        Navigator.of(context).pop();

                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) {
                                            return SingleChildScrollView(
                                              child: Container(
                                                padding: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context)
                                                      .viewInsets
                                                      .bottom,
                                                ),
                                                child: ScheduleForm(
                                                  onScheduleAdded: _addSchedule,
                                                  existingSchedule: schedule,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                        // editSchedule(schedule);

                                        // Close the dialog
                                      },
                                    ),
                                    TextButton(
                                      child: Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pop(); // Close the dialog
                                      },
                                    ),
                                    TextButton(
                                      child: Text('Delete'),
                                      onPressed: () {
                                        _deleteSchedule(schedule);
                                        Navigator.of(context)
                                            .pop(); // Close the dialog
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                        },
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                DateFormat.jm().format(schedule.time),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: scheduleColor,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.only(right: 16),
                                // Adjust the padding as per your preference
                                child: (schedule.imageUrl != null &&
                                        schedule.imageUrl?.isNotEmpty == true)
                                    ? GestureDetector(
                                        onTap: () {
                                          // Handle the image click here
                                          if (schedule.imageUrl != null) {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text('Uploaded Image'),
                                                  content: Image.network(
                                                      schedule.imageUrl!),
                                                  actions: <Widget>[
                                                    TextButton(
                                                      child: Text('Close'),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop(); // Close the dialog
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        },
                                        child: IconButton(
                                          icon: Icon(Icons.image),
                                          onPressed: () {
                                            if (schedule.imageUrl != null) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (BuildContext context) =>
                                                          ZoomableImagePage(
                                                    imageUrl:
                                                        schedule.imageUrl!,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      )
                                    : SizedBox(),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('विषय: ${schedule.agenda}'),
                              Text('निम्तो कर्ता: ${schedule.applicant}'),
                              Text('ठेगाना: ${schedule.address}'),
                              Text('कैफियत: ${schedule.remarks}'),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        schedule.uploader ?? '',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors
                                              .blue, // Customize the color as per your preference
                                        ),
                                      ),
                                      Text(
                                        schedule.editor ?? '',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors
                                              .blue, // Customize the color as per your preference
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isPastDate
                                  ? Checkbox(
                                      value: schedule.attended,
                                      onChanged: (newValue) {
                                        setState(() {
                                          schedule
                                              .setAttended(newValue ?? false);
                                          schedule.setEditor(
                                              currentUser?.displayName ?? '');
                                          // DatabaseHelper.updateSchedule(schedule);
                                          updateFireStoresSchedule(schedule);
                                        });
                                      },
                                    )
                                  : SizedBox(),
                            ],
                          ),
                        ),
                      ));
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ScheduleForm(
                    onScheduleAdded: _addSchedule,
                  ),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void deleteFireStoreSchedule(Schedule schedule) {
    schedules_data.doc(schedule.id).delete().then(
          (value) => {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('You have successfully deleted the schdedule'))),
          },
          onError: (e) => print("Error deleting"),
        );
    if (schedule.imageUrl != null) {
      final storageRef = firebase_storage.FirebaseStorage.instance
          .refFromURL(schedule.imageUrl!);
      storageRef.delete();
    }
  }
}

void updateFireStoresSchedule(Schedule schedule) {
  schedules_data.doc(schedule.id).set({
    'time': schedule.time.toIso8601String(),
    'agenda': schedule.agenda,
    'applicant': schedule.applicant,
    'address': schedule.address,
    'remarks': schedule.remarks,
    'attended': schedule.attended ? 1 : 0,
    'imageUrl': schedule.imageUrl,
    'uploader': schedule.uploader,
    'editor': schedule.editor,
  }, SetOptions(merge: true)).onError(
      (e, _) => print("Error writing document: $e"));
}

class ZoomableImagePage extends StatelessWidget {
  final String imageUrl;

  const ZoomableImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zoomable Image'),
      ),
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop(); // Close the page on tap
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            backgroundDecoration: BoxDecoration(
              color: Colors.transparent,
            ),
            loadingBuilder: (context, event) =>
                Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
