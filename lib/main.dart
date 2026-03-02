import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  // I must ensure Flutter bindings are initialized before running the app.
  // This is a strict technical requirement for my Local-First SQLite architecture 
  // to access the device's hard drive and protect user privacy.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BalanceApp());
}

class BalanceApp extends StatelessWidget {
  const BalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balance: Life Management',
      debugShowCheckedModeBanner: false, // I removed the debug banner to maintain a clean UI for testing.
      theme: ThemeData(
        // I implemented this Teal and Green colour palette based on my visual research.
        // It deliberately reduces visual stress and contrasts with the anxiety-inducing 
        // reds I observed in competitor apps like Pomofocus.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
          secondary: Colors.green,
          surface: const Color(0xFFF5F7FA), // Calming off-white background
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
  // These variables manage my calendar state, which I designed specifically 
  // to support the 'Reflection' stage of the Personal Informatics model.
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Dashboard'),
      ),
      body: Column(
        children: [
          // The Interactive Table Calendar for the Reflection Stage
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
                color: Colors.green, // Calm visual indicator for the current day
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.teal, // Primary focus indicator for user selection
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // I am hiding extra buttons to prevent UI clutter
              titleCentered: true,
            ),
          ),
          
          const Divider(height: 30, thickness: 1),

          // Area reserved for rendering the categorized time blocks (Study, Sleep, Leisure)
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
      
      // I designed this Floating Action Button as the trigger for my 'Time Locking' 
      // feature to introduce friction and force a cognitive pause.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement the Time Locking Category Modal (Study, Sleep, Leisure)
          debugPrint("Time Locking trigger pressed");
        },
        backgroundColor: Colors.teal,
        tooltip: 'Add Categorized Time Block',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}