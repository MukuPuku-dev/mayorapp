// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart' as path;
// import 'Schedule.dart';
//
// class DatabaseHelper {
//   static late Database _database;
//
//   static Future<void> initialize() async {
//
//     print('Initializing database...');
//     _database = await openDatabase(
//       path.join(await getDatabasesPath(), 'schedule.db'),
//       onCreate: (db, version) {
//         return db.execute(
//           'CREATE TABLE schedules(id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT, agenda TEXT, applicant TEXT, address TEXT, remarks TEXT, attended INTEGER)',
//         );
//       },
//       version: 1,
//     );
//     print('Database initialized successfully');
//   }
//
//   static Future<void> insertSchedule(Schedule schedule) async {
//     await _database.insert(
//       'schedules',
//       {
//         'time': schedule.time.toIso8601String(),
//         'agenda': schedule.agenda,
//         'applicant': schedule.applicant,
//         'address': schedule.address,
//         'remarks': schedule.remarks,
//       },
//     );
//     print('Schedule inserted successfully: $schedule');
//   }
//   static Future<void> updateSchedule(Schedule schedule) async {
//     await _database.update(
//       'schedules',
//       {
//         'time': schedule.time.toIso8601String(),
//         'agenda': schedule.agenda,
//         'applicant': schedule.applicant,
//         'address': schedule.address,
//         'remarks': schedule.remarks,
//         'attended': schedule.attended?1:0,
//       },
//       where: 'time = ?',
//       whereArgs: [schedule.time.toIso8601String()],
//     );
//     print('Schedule updated successfully: $schedule');
//
//   }
//
//   static Future<List<Schedule>> getAllSchedules() async {
//     final List<Map<String, dynamic>> maps = await _database.query('schedules');
//     return List.generate(maps.length, (index) {
//       print(maps[index]);
//       return Schedule(
//         time: DateTime.parse(maps[index]['time']),
//         agenda: maps[index]['agenda'],
//         applicant: maps[index]['applicant'],
//         address: maps[index]['address'],
//         remarks: maps[index]['remarks'],
//         attended: maps[index]['attended']==1,
//       );
//     });
//   }
//
//   static Future<void> deleteSchedule(Schedule schedule) async {
//     await _database.delete(
//       'schedules',
//       where: 'time = ?',
//       whereArgs: [schedule.time.toIso8601String()],
//     );
//   }
//
// }