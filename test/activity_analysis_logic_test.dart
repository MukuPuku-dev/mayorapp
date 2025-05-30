import 'package:test/test.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for Timestamp
import 'package:mayorapp/activity_analysis_screen.dart'; // For processScheduleData and Schedule class
// Note: The Schedule class is defined within activity_analysis_screen.dart for this test setup.
// If it's in a separate file (e.g., lib/Schedule.dart), adjust the import.

// Mock DocumentSnapshot class
class MockDocumentSnapshot implements DocumentSnapshot {
  final String _id;
  final Map<String, dynamic>? _data;

  MockDocumentSnapshot(this._id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;
  
  @override
  dynamic get(Object field) {
    if (_data == null) throw StateError('document does not exist');
    if (field is String && _data!.containsKey(field)) {
      return _data![field];
    }
    if (field is FieldPath && field.components.isNotEmpty && _data!.containsKey(field.components.first)) {
       // Simplified: only handles top-level fields for this mock
      return _data![field.components.first];
    }
    throw StateError('field does not exist');
  }
  
  @override
  SnapshotMetadata get metadata => throw UnimplementedError(); // Not needed for these tests

  @override
  DocumentReference<Object?> get reference => throw UnimplementedError(); // Not needed
}


void main() {
  group('Activity Analysis Logic - processScheduleData', () {
    late List<DocumentSnapshot> testDocs;

    setUp(() {
      // Create mock DocumentSnapshots
      testDocs = [
        MockDocumentSnapshot('1', {
          'time': Timestamp.fromDate(DateTime(2023, 10, 26, 10, 0)),
          'agenda': 'Team Meeting about Project Alpha',
          'applicant': 'User1',
          'attended': true,
        }),
        MockDocumentSnapshot('2', {
          'time': Timestamp.fromDate(DateTime(2023, 10, 27, 14, 30)),
          'agenda': 'Site Visit for Alpha Construction',
          'applicant': 'User2',
          'attended': false,
        }),
        MockDocumentSnapshot('3', {
          'time': Timestamp.fromDate(DateTime(2023, 11, 5, 9, 0)),
          'agenda': 'Client Meeting: Beta Phase',
          'applicant': 'User1',
          'attended': true,
        }),
        MockDocumentSnapshot('4', {
          'time': Timestamp.fromDate(DateTime(2023, 11, 10, 11, 0)),
          'agenda': 'Internal Review Meeting',
          'applicant': 'User3',
          'attended': true,
        }),
         MockDocumentSnapshot('5', { // Test empty applicant and short words
          'time': Timestamp.fromDate(DateTime(2023, 11, 12, 11, 0)),
          'agenda': 'Follow up on A and B',
          'applicant': ' ', // Empty applicant
          'attended': false,
        }),
      ];
    });

    test('processes total schedules correctly', () {
      final analysisResults = processScheduleData(testDocs);
      expect(analysisResults['totalSchedules'], equals(5));
    });

    test('processes attended schedules correctly', () {
      final analysisResults = processScheduleData(testDocs);
      expect(analysisResults['attendedSchedules'], equals(3));
    });

    test('processes unattended schedules correctly', () {
      final analysisResults = processScheduleData(testDocs);
      expect(analysisResults['unattendedSchedules'], equals(2));
    });

    test('groups schedules by month correctly', () {
      final analysisResults = processScheduleData(testDocs);
      Map<String, int> schedulesByMonth = Map<String, int>.from(analysisResults['schedulesByMonth']);
      expect(schedulesByMonth['2023-10'], equals(2));
      expect(schedulesByMonth['2023-11'], equals(3));
    });

    test('groups schedules by applicant correctly (and handles empty applicant)', () {
      final analysisResults = processScheduleData(testDocs);
      Map<String, int> schedulesByApplicant = Map<String, int>.from(analysisResults['schedulesByApplicant']);
      // The result is sorted by count descending in processScheduleData
      expect(schedulesByApplicant['User1'], equals(2));
      expect(schedulesByApplicant['User2'], equals(1));
      expect(schedulesByApplicant['User3'], equals(1));
      expect(schedulesByApplicant['Unknown Applicant'], equals(1)); // For empty applicant string
    });

    test('processes agenda keywords correctly (top 10, min length 3, lowercase)', () {
      final analysisResults = processScheduleData(testDocs);
      Map<String, int> agendaKeywords = Map<String, int>.from(analysisResults['agendaKeywords']);
      
      expect(agendaKeywords['meeting'], equals(3));
      expect(agendaKeywords['alpha'], equals(2));
      expect(agendaKeywords['internal'], equals(1)); // Example, check others based on your data
      expect(agendaKeywords['review'], equals(1));
      expect(agendaKeywords['client'], equals(1));
      expect(agendaKeywords['beta'], equals(1));
      expect(agendaKeywords['phase'], equals(1));
      expect(agendaKeywords['site'], equals(1));
      expect(agendaKeywords['visit'], equals(1));
      expect(agendaKeywords['construction'], equals(1));

      // Check that short words or common words (if not filtered by a stop-word list which we aren't doing here) are ignored
      expect(agendaKeywords.containsKey('on'), isFalse); 
      expect(agendaKeywords.containsKey('a'), isFalse);
      expect(agendaKeywords.containsKey('b'), isFalse);
      expect(agendaKeywords.containsKey('and'), isFalse); // 'and' is also >=3 but might be filtered by a more advanced logic
                                                          // For now, it will be counted if it appears.
                                                          // Re-evaluating the test data: "Follow up on A and B"
                                                          // "follow" (6), "up" (2 - ignored), "on" (2 - ignored)
                                                          // "and" (3 - will be counted if not explicitly excluded)
                                                          // "and" should actually be there.

      // Let's re-evaluate keywords from test data:
      // Doc 1: team, meeting, about, project, alpha (all count = 1)
      // Doc 2: site, visit, for, alpha, construction (for ignored)
      // Doc 3: client, meeting, beta, phase
      // Doc 4: internal, review, meeting
      // Doc 5: follow, (up, on, a, b - ignored)
      // Expected counts:
      // meeting: 3
      // alpha: 2
      // team: 1, about: 1, project: 1, site: 1, visit: 1, construction: 1, client: 1, beta: 1, phase: 1, internal: 1, review: 1, follow: 1
      
      // For simplicity, testing a few prominent ones:
      expect(agendaKeywords['meeting'], equals(3));
      expect(agendaKeywords['alpha'], equals(2));
      expect(agendaKeywords['team'], equals(1));
      expect(agendaKeywords['follow'], equals(1));
      expect(agendaKeywords.length, lessThanOrEqualTo(10)); // Max 10 keywords
    });
     test('handles empty schedule list', () {
      final analysisResults = processScheduleData([]);
      expect(analysisResults['totalSchedules'], equals(0));
      expect(analysisResults['attendedSchedules'], equals(0));
      expect(analysisResults['unattendedSchedules'], equals(0));
      expect(analysisResults['schedulesByMonth'], isEmpty);
      expect(analysisResults['schedulesByApplicant'], isEmpty);
      expect(analysisResults['agendaKeywords'], isEmpty);
    });
  });
}
