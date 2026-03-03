import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'database_helper.dart'; // Connecting my local database helper

void main() {
  // I must ensure Flutter bindings are initialized before running the app.
  // This is a strict technical requirement for my Local-First SQLite architecture 
  WidgetsFlutterBinding.ensureInitialized();
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // I engineered this method to trigger the 'Time Locking' mechanism. 
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
              const SizedBox(height: 8),
              const Text(
                'What is the primary focus of this block?',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Categorisation Buttons mapping directly to my local SQLite DB
              ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.instance.insertTimeBlock({
                    'category': 'Study',
                    'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                    'is_productive': 1,
                  });
                  if (context.mounted) Navigator.pop(context); 
                  debugPrint("Saved Study block to local SQLite DB");
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Study (Deep Work)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.instance.insertTimeBlock({
                    'category': 'Sleep',
                    'date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                    'is_productive': 1, 
                  });
                  if (context.mounted) Navigator.pop(context);
                  debugPrint("Saved Sleep block to local SQLite DB");
                },
                icon: const Icon(Icons.bedtime),
                label: const Text('Sleep (Recovery)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
                  debugPrint("Saved Leisure block to local SQLite DB");
                },
                icon: const Icon(Icons.coffee),
                label: const Text('Leisure (Unstructured)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
      appBar: AppBar(
        title: const Text('Balance Dashboard'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; 
              });
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.green, 
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.teal, 
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, 
              titleCentered: true,
            ),
          ),
          
          const Divider(height: 30, thickness: 1),

          const Expanded(
            child: Center(
              child: Text(
                'Categorized time blocks will appear here.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTimeLockingModal(context), 
        backgroundColor: Colors.teal,
        tooltip: 'Add Categorized Time Block',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}