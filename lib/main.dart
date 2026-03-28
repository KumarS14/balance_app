import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; // My chosen package for the Visualisation Suite
import 'database_helper.dart';

void main() async {
  // I must ensure Flutter bindings are initialized before running the app due to my Local-First SQLite architecture.
  WidgetsFlutterBinding.ensureInitialized();
  
  // I initialize my default user persona ('Anxious Alex') on boot.
  // This establishes the ideal_study_limit and ideal_sleep_goal required by my ERD
  // so the Heuristic Engine has baseline metrics to compare against.
  await DatabaseHelper.instance.initializeDefaultUser();
  runApp(const BalanceApp());
}

class BalanceApp extends StatelessWidget {
  const BalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balance: Life Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // I deliberately selected a Teal and Green colour palette to reduce visual stress,
        // contrasting with the anxiety-inducing reds found in competitor productivity apps.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, primary: Colors.teal, secondary: Colors.green, surface: const Color(0xFFF5F7FA)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0),
      ),
      // I wrapped the home screen in a DefaultTabController to allow users to seamlessly switch 
      // between daily and weekly graphs, fulfilling my 'Visualisation Suite' requirement.
      home: const DefaultTabController(length: 2, child: BalanceDashboard()),
    );
  }
}

class BalanceDashboard extends StatefulWidget {
  const BalanceDashboard({super.key});

  @override
  State<BalanceDashboard> createState() => _BalanceDashboardState();
}

class _BalanceDashboardState extends State<BalanceDashboard> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // I updated my state variables to track exact hours (double) rather than just block counts.
  Map<String, double> _dailyStats = {'Study': 0, 'Sleep': 0, 'Leisure': 0};
  Map<String, Map<String, double>> _weeklyStats = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllStats(_focusedDay); 
  }

  // I engineered this method to pull both daily and historical 7-day data simultaneously 
  // from my local SQLite database to power the Reflection stage graphs.
  Future<void> _loadAllStats(DateTime activeDate) async {
    String dateString = activeDate.toIso8601String().split('T')[0];
    final daily = await DatabaseHelper.instance.getDailyStats(dateString);
    
    // Fetching the last 7 days for the trend analysis graph
    DateTime weekAgo = activeDate.subtract(const Duration(days: 6));
    final weekly = await DatabaseHelper.instance.getStatsForDateRange(weekAgo, activeDate);

    setState(() {
      _dailyStats = daily;
      _weeklyStats = weekly;
    });
  }

  // 1. The first phase of my Time Locking intervention.
  // I force the user to input exact start and end times via native pickers to calculate accurate burnout metrics.
  Future<void> _startTimeLockingProcess(BuildContext context) async {
    final TimeOfDay? startTime = await showTimePicker(context: context, initialTime: TimeOfDay.now(), helpText: 'SELECT START TIME');
    if (startTime == null || !context.mounted) return;

    final TimeOfDay? endTime = await showTimePicker(context: context, initialTime: startTime, helpText: 'SELECT END TIME');
    if (endTime == null || !context.mounted) return;

    _showCategoryModal(context, startTime, endTime);
  }

  // A helper function to combine Date and Time into an ISO string for strict SQLite storage
  String _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String();
  }

  // 2. My core intervention: The Categorization Modal
  // This creates the cognitive pause I researched, preventing uncategorized time use.
  void _showCategoryModal(BuildContext context, TimeOfDay startTime, TimeOfDay endTime) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Categorize Time Block', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Allocating: ${startTime.format(context)} - ${endTime.format(context)}', style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              
              // My Categorisation Buttons mapped directly to the local SQLite database
              ElevatedButton.icon(
                onPressed: () async { await _saveBlock('Study', 1, startTime, endTime); if (context.mounted) Navigator.pop(context); },
                icon: const Icon(Icons.menu_book), label: const Text('Study (Deep Work)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                // I explicitly validate Sleep as a productive activity here to combat hustle culture
                onPressed: () async { await _saveBlock('Sleep', 1, startTime, endTime); if (context.mounted) Navigator.pop(context); },
                icon: const Icon(Icons.bedtime), label: const Text('Sleep (Recovery)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async { await _saveBlock('Leisure', 0, startTime, endTime); if (context.mounted) Navigator.pop(context); },
                icon: const Icon(Icons.coffee), label: const Text('Leisure (Unstructured)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  // Securely writes the highly-detailed time block to the Local-First database
  Future<void> _saveBlock(String category, int isProductive, TimeOfDay start, TimeOfDay end) async {
    DateTime activeDate = _selectedDay ?? DateTime.now();
    await DatabaseHelper.instance.insertTimeBlock({
      'category': category, 'date': activeDate.toIso8601String().split('T')[0], 
      'start_time': _combineDateAndTime(activeDate, start), 'end_time': _combineDateAndTime(activeDate, end), 'is_productive': isProductive,
    });
    _loadAllStats(activeDate);
  }

  // I engineered this method to dynamically build a Stacked Bar Chart for the Reflection Suite.
  // It iterates through the last 7 days of SQLite data to visualize burnout trends.
  List<BarChartGroupData> _buildWeeklyBarGroups() {
    List<BarChartGroupData> groups = [];
    DateTime activeDate = _selectedDay ?? DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      DateTime day = activeDate.subtract(Duration(days: 6 - i));
      String dateString = day.toIso8601String().split('T')[0];
      
      double sleep = _weeklyStats[dateString]?['Sleep'] ?? 0;
      double study = _weeklyStats[dateString]?['Study'] ?? 0;
      double leisure = _weeklyStats[dateString]?['Leisure'] ?? 0;
      double total = sleep + study + leisure;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total == 0 ? 0.1 : total, // Prevents rendering errors on completely empty days
              rodStackItems: [
                BarChartRodStackItem(0, sleep, Colors.indigo), // Sleep at bottom
                BarChartRodStackItem(sleep, sleep + study, Colors.blueGrey), // Study in middle
                BarChartRodStackItem(sleep + study, total, Colors.green), // Leisure on top
              ],
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Dashboard')),
      body: Column(
        children: [
          // My Interactive Table Calendar
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
              _loadAllStats(selectedDay); 
            },
            calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          
          // I implemented a Tab Bar to seamlessly switch between Data Visualisations
          const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.pie_chart), text: "Daily"),
              Tab(icon: Icon(Icons.bar_chart), text: "7-Day Trend"),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: Daily Pie Chart for immediate Reflection
                _dailyStats.values.every((element) => element == 0)
                    ? const Center(child: Text('No data for this day. Add a time block!', style: TextStyle(fontSize: 16, color: Colors.black54)))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2, centerSpaceRadius: 40,
                          sections: [
                            if (_dailyStats['Study']! > 0) PieChartSectionData(color: Colors.blueGrey, value: _dailyStats['Study']!, title: '${_dailyStats['Study']!.toStringAsFixed(1)}h', radius: 60, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            if (_dailyStats['Sleep']! > 0) PieChartSectionData(color: Colors.indigo, value: _dailyStats['Sleep']!, title: '${_dailyStats['Sleep']!.toStringAsFixed(1)}h', radius: 60, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            if (_dailyStats['Leisure']! > 0) PieChartSectionData(color: Colors.green, value: _dailyStats['Leisure']!, title: '${_dailyStats['Leisure']!.toStringAsFixed(1)}h', radius: 60, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      
                // TAB 2: Weekly Stacked Bar Chart for historical trend comparison
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 24, // Setting the Y-axis limit to 24 hours in a day
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Dynamically displays the day of the week based on the selected day
                              DateTime activeDate = _selectedDay ?? DateTime.now();
                              DateTime day = activeDate.subtract(Duration(days: 6 - value.toInt()));
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(days[day.weekday - 1], style: const TextStyle(fontSize: 12)));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildWeeklyBarGroups(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // My Floating Action Button designed to trigger the Time Locking modal
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startTimeLockingProcess(context), 
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}