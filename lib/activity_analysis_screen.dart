import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'dart:developer'; // For log

// If Schedule.dart exists and is accessible, this import is preferred:
// For this example, we'll use the simplified Schedule class defined below,
// but for the actual project, you should import your existing Schedule class.
// import 'Schedule.dart'; // Make sure this path is correct for your project structure

// Simplified Schedule class for standalone structure / testability
// IMPORTANT: If you have a Schedule class in your project (e.g., lib/Schedule.dart),
// use that instead of this one. This is primarily for making the analysis function testable
// without depending on the exact location/structure of your main Schedule model during this step.
class Schedule {
  final DateTime time;
  final String agenda;
  final bool attended;
  final String applicant;
  final String? id; // Optional ID

  Schedule({
    this.id,
    required this.time,
    required this.agenda,
    required this.attended,
    required this.applicant,
  });

  // Factory constructor to create a Schedule instance from a Firestore document.
  factory Schedule.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Schedule(
      id: doc.id,
      time: (data['time'] as Timestamp).toDate(),
      agenda: data['agenda'] as String? ?? '',
      attended: (data['attended'] == 1 || data['attended'] == true), // Handles both int and bool
      applicant: data['applicant'] as String? ?? 'Unknown Applicant',
    );
  }
}

/// Processes a list of Firestore [DocumentSnapshot]s into a structured map of schedule statistics.
///
/// This function is designed to be testable independently of Flutter UI or live Firebase calls.
Map<String, dynamic> processScheduleData(List<DocumentSnapshot> docs) {
  int total = 0;
  int attended = 0;
  Map<String, int> byMonth = {};
  Map<String, int> byApplicant = {};
  Map<String, int> keywords = {};

  for (var doc in docs) {
    Schedule schedule = Schedule.fromFirestore(doc);

    total++;
    if (schedule.attended) {
      attended++;
    }

    // Group by month (YYYY-MM)
    String monthKey = DateFormat('yyyy-MM').format(schedule.time);
    byMonth[monthKey] = (byMonth[monthKey] ?? 0) + 1;

    // Group by applicant
    String applicantKey = schedule.applicant.trim().isEmpty 
        ? "Unknown Applicant" 
        : schedule.applicant.trim();
    byApplicant[applicantKey] = (byApplicant[applicantKey] ?? 0) + 1;
    
    // Process agenda keywords
    List<String> words = schedule.agenda.toLowerCase().split(RegExp(r'\s+|,|\.|;|:'));
    for (String word in words) {
      String cleanedWord = word.replaceAll(RegExp(r'[^\w]'), ''); // Remove non-alphanumeric
      if (cleanedWord.length >= 3) { 
        keywords[cleanedWord] = (keywords[cleanedWord] ?? 0) + 1;
      }
    }
  }
  
  var sortedKeywords = Map.fromEntries(
      keywords.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
  );
  Map<String, int> topKeywords = Map.fromEntries(sortedKeywords.entries.take(10));

  // Sort applicants by count for top N display
  var sortedApplicants = Map.fromEntries(
      byApplicant.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
  );


  return {
    'totalSchedules': total,
    'attendedSchedules': attended,
    'unattendedSchedules': total - attended,
    'schedulesByMonth': byMonth,
    'schedulesByApplicant': sortedApplicants, // Return all sorted, UI can take top N
    'agendaKeywords': topKeywords,
  };
}


class ActivityAnalysisScreen extends StatefulWidget {
  // Optionally accept pre-calculated data for testing or specific use cases
  final Map<String, dynamic>? initialAnalysisData;

  const ActivityAnalysisScreen({Key? key, this.initialAnalysisData}) : super(key: key);

  @override
  _ActivityAnalysisScreenState createState() => _ActivityAnalysisScreenState();
}

class _ActivityAnalysisScreenState extends State<ActivityAnalysisScreen> {
  bool _isLoading = true;
  int _totalSchedules = 0;
  int _attendedSchedules = 0;
  int _unattendedSchedules = 0;
  Map<String, int> _schedulesByMonth = {};
  Map<String, int> _schedulesByApplicant = {};
  Map<String, int> _agendaKeywords = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialAnalysisData != null) {
      _applyAnalysisData(widget.initialAnalysisData!);
      _isLoading = false;
    } else {
      _fetchAndProcessData();
    }
  }
  
  void _applyAnalysisData(Map<String, dynamic> data) {
     _totalSchedules = data['totalSchedules'] ?? 0;
     _attendedSchedules = data['attendedSchedules'] ?? 0;
     _unattendedSchedules = data['unattendedSchedules'] ?? 0;
     _schedulesByMonth = Map<String, int>.from(data['schedulesByMonth'] ?? {});
     _schedulesByApplicant = Map<String, int>.from(data['schedulesByApplicant'] ?? {});
     _agendaKeywords = Map<String, int>.from(data['agendaKeywords'] ?? {});
  }

  Future<void> _fetchAndProcessData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('schedules').get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _totalSchedules = 0; // Explicitly set to 0
            _isLoading = false;
          });
        }
        return;
      }
      
      // Use the extracted processing function
      Map<String, dynamic> analysisResults = processScheduleData(snapshot.docs);

      if (mounted) {
        setState(() {
          _applyAnalysisData(analysisResults);
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      print("Error fetching data: $error");
      log("Stack trace for fetching data: $stackTrace", stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching analysis data: $error")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Analysis'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _totalSchedules == 0 && widget.initialAnalysisData == null // Show "No data" only if not loading and no initial data
              ? Center(child: Text("No schedule data found to analyze."))
              : RefreshIndicator( // Allow pull-to-refresh
                  onRefresh: _fetchAndProcessData,
                  child: ListView(
                    padding: EdgeInsets.all(16.0),
                    children: <Widget>[
                      _buildSummaryCard(),
                      SizedBox(height: 20),
                      if (_totalSchedules > 0) _buildPieChartCard(), // Only show charts if there's data
                      SizedBox(height: 20),
                      if (_schedulesByMonth.isNotEmpty) _buildBarChartCard("Schedules by Month", _schedulesByMonth),
                      SizedBox(height: 20),
                      if (_schedulesByApplicant.isNotEmpty) _buildBarChartCard("Schedules by Applicant (Top 10)", Map.fromEntries(
                          _schedulesByApplicant.entries.take(10) // Take top 10 for display
                       )),
                      SizedBox(height: 20),
                      if (_agendaKeywords.isNotEmpty) _buildKeywordsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Overall Summary", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.event_note, color: Theme.of(context).primaryColor, size: 30),
              title: Text("Total Schedules", style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(_totalSchedules.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green[700], size: 30),
              title: Text("Attended Schedules", style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(_attendedSchedules.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[700])),
            ),
            ListTile(
              leading: Icon(Icons.highlight_off, color: Colors.red[700], size: 30),
              title: Text("Unattended Schedules", style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(_unattendedSchedules.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard() {
    if (_totalSchedules == 0) return SizedBox.shrink();

    List<PieChartSectionData> sections = [
      PieChartSectionData(
        color: Colors.green[600],
        value: _attendedSchedules.toDouble(),
        title: '${(_attendedSchedules / _totalSchedules * 100).toStringAsFixed(0)}%',
        radius: 60, // Increased radius
        titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black38)]),
      ),
      PieChartSectionData(
        color: Colors.red[600],
        value: _unattendedSchedules.toDouble(),
        title: '${(_unattendedSchedules / _totalSchedules * 100).toStringAsFixed(0)}%',
        radius: 60, // Increased radius
        titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black38)]),
      ),
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Attendance Overview", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            SizedBox(
              height: 180, // Increased height for larger chart
              child: PieChart(PieChartData(
                sections: sections, 
                centerSpaceRadius: 50, // Increased center space
                sectionsSpace: 2, // Space between sections
                pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Optional: Handle touch events for interactivity
                }),
                )),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green[600]!, "Attended (${_attendedSchedules})"),
                SizedBox(width: 20),
                _buildLegendItem(Colors.red[600]!, "Unattended (${_unattendedSchedules})"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildBarChartCard(String title, Map<String, int> data) {
    if (data.isEmpty) return SizedBox.shrink();
    
    var sortedEntries = data.entries.toList();
    // For "Schedules by Applicant", data is already sorted and taken top 10 in _fetchAndProcessData or build method.
    // For "Schedules by Month", sort them chronologically.
    if (title.contains("Month")) { 
        sortedEntries.sort((a, b) => a.key.compareTo(b.key));
    }
    
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: sortedEntries[i].value.toDouble(), color: Colors.blue[600], width: 18, borderRadius: BorderRadius.circular(4))],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch for better bar chart layout
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            SizedBox(
              height: 220, 
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedEntries.length) {
                            String text = sortedEntries[index].key;
                            if(title.contains("Month")) {
                                try {
                                  DateTime date = DateFormat('yyyy-MM').parse(text);
                                  text = DateFormat('MMM yy').format(date);
                                } catch(e) { /* ignore */ }
                            } else if (text.length > 8) { 
                                text = text.substring(0, 6) + "..."; // Shorten for applicant names
                            }
                            return SideTitleWidget(axisSide: meta.axisSide, space: 5.0, child: Text(text, style: TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w500)));
                          }
                          return Text('');
                        },
                        reservedSize: 32, 
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _calculateInterval(data.values))),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _calculateInterval(data.values), getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.8)),
                  barTouchData: BarTouchData( // Added touch tooltip
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String weekDay = sortedEntries[group.x.toInt()].key;
                         if(title.contains("Month")) {
                                try {
                                  DateTime date = DateFormat('yyyy-MM').parse(weekDay);
                                  weekDay = DateFormat('MMMM yyyy').format(date);
                                } catch(e) { /* ignore */ }
                            }
                        return BarTooltipItem(
                          weekDay + '\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: (rod.toY - 1).toString(), // Assuming toY was value + 1
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateInterval(Iterable<int> values) {
    if (values.isEmpty) return 1;
    double maxVal = values.reduce((curr, next) => curr > next ? curr : next).toDouble();
    if (maxVal == 0) return 1; // Avoid division by zero if all values are 0
    if (maxVal <= 10) return 1;
    if (maxVal <= 50) return 5;
    if (maxVal <= 100) return 10;
    return (maxVal / 5).ceilToDouble(); // Aim for about 5-6 grid lines
  }

  Widget _buildKeywordsCard() {
    if (_agendaKeywords.isEmpty) return SizedBox.shrink();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Top Agenda Keywords", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap( // Use Wrap for better display of keywords
              spacing: 8.0,
              runSpacing: 4.0,
              children: _agendaKeywords.entries.map((entry) {
                return Chip(
                  label: Text('${entry.key} (${entry.value})'),
                  backgroundColor: Colors.teal[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
