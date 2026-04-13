import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; // My chosen package for the Visualisation Suite
import 'dart:math'; // I need this to dynamically calculate the chart width for the 1-year view
import 'database_helper.dart';
import 'heuristic_engine.dart';
void main() async {
  // I must ensure Flutter bindings are initialized before running my app due to my strictly Local-First SQLite architecture.
  WidgetsFlutterBinding.ensureInitialized();
  
  // I initialize my default user persona ('Anxious Alex') on boot.
  // This establishes the ideal_study_limit and ideal_sleep_goal required by my ERD
  // so my Heuristic Engine has baseline metrics to compare against.
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
        // contrasting with the anxiety-inducing reds I found in competitor productivity apps during my visual research.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, primary: Colors.teal, secondary: Colors.green, surface: const Color(0xFFF5F7FA)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0),
      ),
      // I wrapped the home screen in a DefaultTabController to allow users to seamlessly switch 
      // between daily and historical graphs, fulfilling my 'Visualisation Suite' requirement.
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
  
  // My state variables to store the precise hour calculations for the Reflection stage.
  Map<String, double> _dailyStats = {'Study': 0, 'Sleep': 0, 'Leisure': 0};
  Map<String, Map<String, double>> _trendStats = {};
  List<String> _currentNudges = [];

  // I added this state variable to track the user's selected timeframe for longitudinal analysis.
  int _selectedTrendDays = 7;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllStats(_focusedDay); 
  }

  // I engineered this method to pull both daily and historical data simultaneously 
  // from my local SQLite database, adapting dynamically to the user's dropdown selection.
  Future<void> _loadAllStats(DateTime activeDate) async {
    String dateString = activeDate.toIso8601String().split('T')[0];
    final daily = await DatabaseHelper.instance.getDailyStats(dateString);
    
    // Fetching historical data based on the user's chosen timeframe (e.g., 7, 30, or 365 days)
    DateTime pastDate = activeDate.subtract(Duration(days: _selectedTrendDays - 1));
    final trendData = await DatabaseHelper.instance.getStatsForDateRange(pastDate, activeDate);

    final nudges = await HeuristicEngine.generateDailyNudges(activeDate);

    setState(() {
      _dailyStats = daily;
      _trendStats = trendData;
      _currentNudges = nudges;
    });
  }

// Phase 1 of my Time Locking intervention with robust Input Validation.
  // I force the user to input exact start and end times via native pickers,
  // and rigorously validate the data to prevent negative hour calculations 
  // that would corrupt my Heuristic Engine.
  Future<void> _startTimeLockingProcess(BuildContext context) async {
    final TimeOfDay? startTime = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.now(), 
      helpText: 'SELECT START TIME'
    );
    if (startTime == null || !context.mounted) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context, 
      initialTime: startTime, 
      helpText: 'SELECT END TIME'
    );
    if (endTime == null || !context.mounted) return;

    // --- NEW INPUT VALIDATION LOGIC ---
    // I convert the TimeOfDay objects into total minutes to accurately compare them
    final int startMinutes = startTime.hour * 60 + startTime.minute;
    final int endMinutes = endTime.hour * 60 + endTime.minute;

    // If the user tries to input an end time that is BEFORE or EQUAL TO the start time
    if (endMinutes <= startMinutes) {
      // I trigger a non-intrusive UI alert to guide the user back to the correct path
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Time: End time must be after the start time!'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return; // This immediately aborts the process so the bad data is never saved
    }
    // ----------------------------------

    // If the data passes my validation, I trigger the Categorization Modal
    _showCategoryModal(context, startTime, endTime);
  }

  // A helper function I wrote to combine Date and Time into an ISO string for strict SQLite storage
  String _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String();
  }

  // My core intervention: The Categorization Modal
  // This creates the cognitive pause I researched, preventing the passive, uncategorized time use seen in standard calendars.
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
              
              // My Categorisation Buttons mapped directly to my local SQLite database schema
              ElevatedButton.icon(
                onPressed: () async { await _saveBlock('Study', 1, startTime, endTime); if (context.mounted) Navigator.pop(context); },
                icon: const Icon(Icons.menu_book), label: const Text('Study (Deep Work)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                // I explicitly validate Sleep as a productive activity here to combat the student hustle culture I identified in my literature review.
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

  // I use this to securely write the highly-detailed time block to my Local-First database
  Future<void> _saveBlock(String category, int isProductive, TimeOfDay start, TimeOfDay end) async {
    DateTime activeDate = _selectedDay ?? DateTime.now();
    await DatabaseHelper.instance.insertTimeBlock({
      'category': category, 'date': activeDate.toIso8601String().split('T')[0], 
      'start_time': _combineDateAndTime(activeDate, start), 'end_time': _combineDateAndTime(activeDate, end), 'is_productive': isProductive,
    });
    _loadAllStats(activeDate); // Immediately refresh the UI to show the new data
  }

  // I engineered this dynamic chart builder to scale from 7 days up to 365 days.
  // It proves my app can handle complex longitudinal data for the Reflection stage without UI breaking.
  List<BarChartGroupData> _buildTrendBarGroups() {
    List<BarChartGroupData> groups = [];
    DateTime activeDate = _selectedDay ?? DateTime.now();
    
    for (int i = 0; i < _selectedTrendDays; i++) {
      DateTime day = activeDate.subtract(Duration(days: (_selectedTrendDays - 1) - i));
      String dateString = day.toIso8601String().split('T')[0];
      
      double sleep = _trendStats[dateString]?['Sleep'] ?? 0;
      double study = _trendStats[dateString]?['Study'] ?? 0;
      double leisure = _trendStats[dateString]?['Leisure'] ?? 0;
      double total = sleep + study + leisure;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total == 0 ? 0.1 : total, // A UX trick I implemented to prevent rendering errors on completely empty days
              rodStackItems: [
                BarChartRodStackItem(0, sleep, Colors.indigo), // Sleep at bottom
                BarChartRodStackItem(sleep, sleep + study, Colors.blueGrey), // Study in middle
                BarChartRodStackItem(sleep + study, total, Colors.green), // Leisure on top
              ],
              width: 16, // I kept the bars thin so more fit on the screen during long-term views
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
          // THE HEURISTIC FEEDBACK DISPLAY
          if (_currentNudges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _currentNudges.map((nudge) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      nudge,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal),
                    ),
                  )).toList(),
                ),
              ),
            ),
          // I implemented a Tab Bar to seamlessly switch between my Data Visualisations
          const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.pie_chart), text: "Daily"),
              Tab(icon: Icon(Icons.auto_graph), text: "Historical Trends"),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: Daily Pie Chart for immediate Reflection
                _dailyStats.values.every((element) => element == 0)
                    ? const Center(child: Text('No data for this day.', style: TextStyle(color: Colors.black54)))
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
                      
                // TAB 2: Dynamic Trend Graph with Dropdown
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Select Timeframe:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          // I added this dropdown menu so users can customize their historical trend view,
                          // extending my data visualisation suite up to a full academic year.
                          DropdownButton<int>(
                            value: _selectedTrendDays,
                            dropdownColor: Colors.teal.shade50,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text("7 Days")),
                              DropdownMenuItem(value: 14, child: Text("14 Days")),
                              DropdownMenuItem(value: 30, child: Text("1 Month")),
                              DropdownMenuItem(value: 180, child: Text("6 Months")),
                              DropdownMenuItem(value: 365, child: Text("1 Year")),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() { _selectedTrendDays = value; });
                                _loadAllStats(_selectedDay ?? DateTime.now());
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        // I implemented a horizontal scroll view here to ensure that massive timeframes 
                        // (like 1 Year) remain readable and don't compromise my UI/UX design.
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            // This math dynamically stretches the chart width based on the number of days selected
                            width: max(MediaQuery.of(context).size.width - 32, _selectedTrendDays * 30.0),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 24, // I locked the Y-axis to 24 because there are only 24 hours in a day
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        DateTime activeDate = _selectedDay ?? DateTime.now();
                                        DateTime day = activeDate.subtract(Duration(days: (_selectedTrendDays - 1) - value.toInt()));
                                        
                                        // My logic to switch labels: If viewing a short time, show day of week. If viewing months, show the date (MM/DD)
                                        String label = _selectedTrendDays <= 14 
                                            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1] 
                                            : '${day.month}/${day.day}';
                                        
                                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)));
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: _buildTrendBarGroups(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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