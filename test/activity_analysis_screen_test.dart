import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayorapp/activity_analysis_screen.dart'; // Adjust import if necessary
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart for PieChart and BarChart

void main() {
  group('ActivityAnalysisScreen Widget Tests', () {
    testWidgets('shows CircularProgressIndicator when loading', (WidgetTester tester) async {
      // Build the screen without initial data, so it should be in loading state.
      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen()));

      // Expect CircularProgressIndicator to be present.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Expect no data-driven widgets yet.
      expect(find.text("Overall Summary"), findsNothing);
    });

    testWidgets('shows "No schedule data found" when data is empty after loading', (WidgetTester tester) async {
      // Provide empty initial data to simulate loaded but empty state.
      final Map<String, dynamic> emptyData = {
        'totalSchedules': 0,
        'attendedSchedules': 0,
        'unattendedSchedules': 0,
        'schedulesByMonth': <String, int>{},
        'schedulesByApplicant': <String, int>{},
        'agendaKeywords': <String, int>{},
      };

      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: emptyData)));
      await tester.pumpAndSettle(); // Ensure all frames are processed after initial build

      // Expect "No schedule data found" text.
      expect(find.text("No schedule data found to analyze."), findsOneWidget);
      // Expect CircularProgressIndicator to be gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays summary data correctly when provided', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
        'totalSchedules': 10,
        'attendedSchedules': 7,
        'unattendedSchedules': 3,
        'schedulesByMonth': {'2023-10': 5, '2023-11': 5},
        'schedulesByApplicant': {'User A': 6, 'User B': 4},
        'agendaKeywords': {'meeting': 5, 'project': 3},
      };

      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();


      expect(find.text("Overall Summary"), findsOneWidget);
      expect(find.text("Total Schedules"), findsOneWidget);
      expect(find.text("10"), findsOneWidget); // Total schedules count
      expect(find.text("Attended Schedules"), findsOneWidget);
      expect(find.text("7"), findsOneWidget);  // Attended count
      expect(find.text("Unattended Schedules"), findsOneWidget);
      expect(find.text("3"), findsOneWidget); // Unattended count
    });

    testWidgets('displays PieChart when there is data', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
        'totalSchedules': 10,
        'attendedSchedules': 7,
        'unattendedSchedules': 3,
        'schedulesByMonth': {}, 'schedulesByApplicant': {}, 'agendaKeywords': {}, // Keep other data minimal
      };
      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();

      expect(find.text("Attendance Overview"), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text("Attended (7)"), findsOneWidget);
      expect(find.text("Unattended (3)"), findsOneWidget);
    });

    testWidgets('displays BarChart for schedules by month when data is present', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
         'totalSchedules': 5, 'attendedSchedules': 0, 'unattendedSchedules': 0, // Minimal summary
        'schedulesByMonth': {'2023-10': 2, '2023-11': 3},
        'schedulesByApplicant': {}, 'agendaKeywords': {},
      };
      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();

      expect(find.text("Schedules by Month"), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      // More specific checks can be added for bar chart data if needed,
      // e.g., by finding specific text from formatted bottom titles if they are predictable.
      expect(find.text('Oct 23'), findsOneWidget); // Assuming 'MMM yy' format from screen
      expect(find.text('Nov 23'), findsOneWidget);
    });

    testWidgets('displays BarChart for schedules by applicant when data is present', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
        'totalSchedules': 3, 'attendedSchedules': 0, 'unattendedSchedules': 0,
        'schedulesByMonth': {},
        'schedulesByApplicant': {'User A': 2, 'User B': 1},
        'agendaKeywords': {},
      };
      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();

      expect(find.text("Schedules by Applicant (Top 10)"), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('User A'), findsOneWidget);
      // expect(find.text('User B'), findsOneWidget); // Might be truncated to "User B..."
    });

    testWidgets('displays agenda keywords when data is present', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
        'totalSchedules': 1, 'attendedSchedules': 0, 'unattendedSchedules': 0,
        'schedulesByMonth': {}, 'schedulesByApplicant': {},
        'agendaKeywords': {'meeting': 5, 'urgent': 3},
      };
      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();

      expect(find.text("Top Agenda Keywords"), findsOneWidget); // Title from the card
      expect(find.widgetWithText(Chip, 'meeting (5)'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'urgent (3)'), findsOneWidget);
    });

     testWidgets('hides charts and keyword section if respective data is empty', (WidgetTester tester) async {
      final Map<String, dynamic> mockData = {
        'totalSchedules': 0, // No schedules means no data for charts or keywords
        'attendedSchedules': 0,
        'unattendedSchedules': 0,
        'schedulesByMonth': <String, int>{},
        'schedulesByApplicant': <String, int>{},
        'agendaKeywords': <String, int>{},
      };

      await tester.pumpWidget(MaterialApp(home: ActivityAnalysisScreen(initialAnalysisData: mockData)));
      await tester.pumpAndSettle();

      // Summary card should still be there, but might show 0s or be minimal
      expect(find.text("Overall Summary"), findsOneWidget);
      expect(find.text("Total Schedules"), findsOneWidget);
      expect(find.text("0"), findsOneWidget); // Total schedules count

      // Charts and keyword section should not be built
      expect(find.byType(PieChart), findsNothing);
      expect(find.byType(BarChart), findsNothing);
      expect(find.text("Top Agenda Keywords"), findsNothing);
      expect(find.text("No schedule data found to analyze."), findsOneWidget);

    });
  });
}
