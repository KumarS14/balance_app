import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'dart:math'; 
import 'database_helper.dart';
import 'heuristic_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        // UI/UX PSYCHOLOGY: I deliberately selected a Teal and Green colour palette to reduce cognitive 
        // visual stress, contrasting sharply with the anxiety-inducing reds prevalent in competitor apps.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, primary: Colors.teal, secondary: Colors.green, surface: const Color(0xFFF5F7FA)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0),
      ),
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
  
  Map<String, double> _dailyStats = {'Study': 0, 'Sleep': 0, 'Leisure': 0};
  Map<String, Map<String, double>> _trendStats = {};
  List<String> _currentNudges = [];
  int _selectedTrendDays = 7;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllStats(_focusedDay); 
  }

  Future<void> _loadAllStats(DateTime activeDate) async {
    String dateString = activeDate.toIso8601String().split('T')[0];
    final daily = await DatabaseHelper.instance.getDailyStats(dateString);
    
    DateTime pastDate = activeDate.subtract(Duration(days: _selectedTrendDays - 1));
    final trendData = await DatabaseHelper.instance.getStatsForDateRange(pastDate, activeDate);
    final nudges = await HeuristicEngine.generateDailyNudges(activeDate);

    setState(() {
      _dailyStats = daily;
      _trendStats = trendData;
      _currentNudges = nudges;
    });
  }

  // --- THE COLLECTION STAGE: ACTIVE TIME LOCKING ---
  Future<void> _startTimeLockingProcess(BuildContext context) async {
    final TimeOfDay? startTime = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.now(), 
      helpText: 'SELECT START TIME (24-Hour)',
      // FORMATIVE EVALUATION UPDATE: Observation of Participant 1 revealed severe cognitive friction 
      // with the native AM/PM toggle, leading to database validation errors. I engineered this builder 
      // to force a 24-hour military time format, adhering strictly to Nielsen's 'Error Prevention' heuristic.
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (startTime == null || !context.mounted) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context, 
      initialTime: startTime, 
      helpText: 'SELECT END TIME (24-Hour)',
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (endTime == null || !context.mounted) return;

    final int startMinutes = startTime.hour * 60 + startTime.minute;
    final int endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Time: End time must be after start time!'), backgroundColor: Colors.redAccent),
      );
      return; 
    }

    _showCategoryModal(context, startTime, endTime);
  }

  String _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String();
  }

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
              
              ElevatedButton.icon(
                onPressed: () async { await _saveBlock('Study', 1, startTime, endTime); if (context.mounted) Navigator.pop(context); },
                icon: const Icon(Icons.menu_book), label: const Text('Study (Deep Work)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
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

  Future<void> _saveBlock(String category, int isProductive, TimeOfDay start, TimeOfDay end) async {
    DateTime activeDate = _selectedDay ?? DateTime.now();
    await DatabaseHelper.instance.insertTimeBlock({
      'category': category, 'date': activeDate.toIso8601String().split('T')[0], 
      'start_time': _combineDateAndTime(activeDate, start), 'end_time': _combineDateAndTime(activeDate, end), 'is_productive': isProductive,
    });
    
    // FORMATIVE EVALUATION UPDATE: I introduced this Snackbar to satisfy Nielsen's 'Visibility of System Status' heuristic, 
    // resolving hesitation observed during user testing when blocks were saved.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $category block securely saved!'), backgroundColor: Colors.teal, duration: const Duration(seconds: 2)),
      );
    }
    _loadAllStats(activeDate); 
  }

  Future<void> _showDailyAuditModal(BuildContext context) async {
    DateTime activeDate = _selectedDay ?? DateTime.now();
    String dateString = activeDate.toIso8601String().split('T')[0];
    
    final blocks = await DatabaseHelper.instance.getRawBlocksForDay(dateString);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Daily Log Audit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 16),
              blocks.isEmpty 
                ? const Padding(padding: EdgeInsets.all(16.0), child: Text('No time blocks logged for this day.'))
                : Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: blocks.length,
                      itemBuilder: (context, index) {
                        final block = blocks[index];
                        IconData icon = Icons.menu_book;
                        Color color = Colors.blueGrey;
                        if (block['category'] == 'Sleep') { icon = Icons.bedtime; color = Colors.indigo; }
                        if (block['category'] == 'Leisure') { icon = Icons.coffee; color = Colors.green; }

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 18)),
                            title: Text(block['category'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${DateTime.parse(block['start_time']).hour.toString().padLeft(2, '0')}:${DateTime.parse(block['start_time']).minute.toString().padLeft(2, '0')} - ${DateTime.parse(block['end_time']).hour.toString().padLeft(2, '0')}:${DateTime.parse(block['end_time']).minute.toString().padLeft(2, '0')}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                await DatabaseHelper.instance.deleteTimeBlock(block['id']);
                                _loadAllStats(activeDate); 
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  // --- FORMATIVE EVALUATION UPDATE: VISUAL CONTEXT HELPER ---
  // I engineered this UI component following Participant 2's inability to parse the raw graph data.
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

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
              toY: total == 0 ? 0.1 : total, 
              rodStackItems: [
                BarChartRodStackItem(0, sleep, Colors.indigo), 
                BarChartRodStackItem(sleep, sleep + study, Colors.blueGrey), 
                BarChartRodStackItem(sleep + study, total, Colors.green), 
              ],
              width: 16, 
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
          
          TextButton.icon(
            onPressed: () => _showDailyAuditModal(context),
            icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.teal),
            label: const Text("View / Edit Today's Blocks", style: TextStyle(color: Colors.teal)),
          ),

          if (_currentNudges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _currentNudges.map((nudge) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(nudge, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal)),
                  )).toList(),
                ),
              ),
            ),
          
          const TabBar(
            labelColor: Colors.teal, unselectedLabelColor: Colors.grey, indicatorColor: Colors.teal,
            tabs: [Tab(icon: Icon(Icons.pie_chart), text: "Daily"), Tab(icon: Icon(Icons.auto_graph), text: "Historical Trends")],
          ),

          Expanded(
            child: TabBarView(
              children: [
                _dailyStats.values.every((element) => element == 0)
                    ? const Center(child: Text('No data for this day.', style: TextStyle(color: Colors.black54)))
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2, centerSpaceRadius: 40,
                          sections: [
                            // FORMATIVE EVALUATION UPDATE: I modified these labels to explicitly state the category name alongside the value, 
                            // resolving Participant 1's 'Recall over Recognition' cognitive load issue.
                            if (_dailyStats['Study']! > 0) PieChartSectionData(color: Colors.blueGrey, value: _dailyStats['Study']!, title: 'Study\n${_dailyStats['Study']!.toStringAsFixed(1)}h', radius: 65, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            if (_dailyStats['Sleep']! > 0) PieChartSectionData(color: Colors.indigo, value: _dailyStats['Sleep']!, title: 'Sleep\n${_dailyStats['Sleep']!.toStringAsFixed(1)}h', radius: 65, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            if (_dailyStats['Leisure']! > 0) PieChartSectionData(color: Colors.green, value: _dailyStats['Leisure']!, title: 'Leisure\n${_dailyStats['Leisure']!.toStringAsFixed(1)}h', radius: 65, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Select Timeframe:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          DropdownButton<int>(
                            value: _selectedTrendDays,
                            dropdownColor: Colors.teal.shade50,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text("7 Days")), DropdownMenuItem(value: 14, child: Text("14 Days")),
                              DropdownMenuItem(value: 30, child: Text("1 Month")), DropdownMenuItem(value: 180, child: Text("6 Months")),
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
                    // FORMATIVE EVALUATION UPDATE: Implemented to solve Participant 2's data parsing friction.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(Colors.blueGrey, 'Study'), const SizedBox(width: 16),
                          _buildLegendItem(Colors.indigo, 'Sleep'), const SizedBox(width: 16),
                          _buildLegendItem(Colors.green, 'Leisure'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: max(MediaQuery.of(context).size.width - 32, _selectedTrendDays * 30.0),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround, maxY: 24, barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  // FORMATIVE EVALUATION UPDATE: Direct response to Participant 2 requesting explicit Y-Axis identification.
                                  leftTitles: AxisTitles(
                                    axisNameWidget: const Padding(padding: EdgeInsets.only(bottom: 4.0), child: Text('Hours', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold))),
                                    axisNameSize: 20,
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        DateTime activeDate = _selectedDay ?? DateTime.now();
                                        DateTime day = activeDate.subtract(Duration(days: (_selectedTrendDays - 1) - value.toInt()));
                                        String label = _selectedTrendDays <= 14 ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1] : '${day.month}/${day.day}';
                                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)));
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startTimeLockingProcess(context), 
        backgroundColor: Colors.teal, child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}