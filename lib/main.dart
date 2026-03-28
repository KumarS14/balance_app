import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; // My imported charting library for data visualization
import 'database_helper.dart'; 

void main() {
  // I must ensure Flutter bindings are initialized before running the app.
  // This is a strict technical requirement for my Local-First SQLite architecture.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BalanceApp());
}

class BalanceApp extends StatelessWidget {
  const BalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balance: Life Management',
      debugShowCheckedModeBanner: false, // I removed the debug banner to maintain a clean UI.
      theme: ThemeData(
        // I deliberately implemented this Teal and Green colour palette based on my visual research.
        // It reduces visual stress and contrasts with the anxiety-inducing reds used in competitor apps.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
          secondary: Colors.green,
          surface: const Color(0xFFF5F7FA), 
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const BalanceDashboard(),
    );
  }
}

class BalanceDashboard extends StatefulWidget {
  const BalanceDashboard({super.key});

  @override
  State<BalanceDashboard> createState() => _BalanceDashboardState();
}

class _BalanceDashboardState extends State<BalanceDashboard> {
  // These variables manage my calendar state and graph data for the 'Reflection' stage.
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, int> _dailyStats = {'Study': 0, 'Sleep': 0, 'Leisure': 0};

  @override
  void initState() {
    super.initState();
    _loadDailyStats(_focusedDay); 
  }

  // I built this method to fetch data from my SQLite database and dynamically update the Pie Chart.
  Future<void> _loadDailyStats(DateTime date) async {
    String dateString = date.toIso8601String().split('T')[0];
    final stats = await DatabaseHelper.instance.getDailyStats(dateString);
    setState(() {
      _dailyStats = stats;
    });
  }

  // I engineered this method to trigger my 'Time Locking' mechanism. 
  // It forces the user into a cognitive pause, requiring them to validate Rest and Leisure.
  void _showTimeLockingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Categorize Time Block',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // My Categorisation Buttons mapped directly to my local SQLite database
              ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.instance.insertTimeBlock({
                    'category': 'Study',
                    'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                    'is_productive': 1,
                  });
                  if (context.mounted) Navigator.pop(context); 
                  _loadDailyStats(_selectedDay ?? DateTime.now()); // Instantly updates my visual graph
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Study (Deep Work)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.instance.insertTimeBlock({
                    'category': 'Sleep',
                    'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                    'is_productive': 1, // I validate rest as productive to combat burnout
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadDailyStats(_selectedDay ?? DateTime.now()); 
                },
                icon: const Icon(Icons.bedtime),
                label: const Text('Sleep (Recovery)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.instance.insertTimeBlock({
                    'category': 'Leisure',
                    'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                    'is_productive': 0, 
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadDailyStats(_selectedDay ?? DateTime.now()); 
                },
                icon: const Icon(Icons.coffee),
                label: const Text('Leisure (Unstructured)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Dashboard')),
      body: Column(
        children: [
          // My Interactive Table Calendar
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; 
              });
              _loadDailyStats(selectedDay); // Fetch the clicked day's database records
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          const Divider(height: 30, thickness: 1),

          // I integrated fl_chart here to visualize the burnout data in a Pie Chart 
          // to fulfill the 'Reflection' stage of my application.
          Expanded(
            child: _dailyStats.values.every((element) => element == 0)
                ? const Center(
                    child: Text(
                      'No data for this day. Add a time block!',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: Colors.blueGrey,
                          value: _dailyStats['Study']!.toDouble(),
                          title: '${_dailyStats['Study']} Study',
                          radius: 60,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.indigo,
                          value: _dailyStats['Sleep']!.toDouble(),
                          title: '${_dailyStats['Sleep']} Sleep',
                          radius: 60,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.green,
                          value: _dailyStats['Leisure']!.toDouble(),
                          title: '${_dailyStats['Leisure']} Leisure',
                          radius: 60,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      
      // I designed this Floating Action Button to call my Time Locking modal
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTimeLockingModal(context), 
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}