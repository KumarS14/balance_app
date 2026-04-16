import 'database_helper.dart';

class HeuristicEngine {
  // I engineered this V2 heuristic engine to perform longitudinal analysis,
  // moving beyond daily metrics to identify chronic behavioral patterns like compound burnout and sleep debt.
  static Future<List<String>> generateDailyNudges(DateTime date) async {
    List<String> nudges = [];
    final db = await DatabaseHelper.instance.database;

    // 1. Fetching the user's self-defined baseline goals
    final List<Map<String, dynamic>> userQuery = await db.query('users', limit: 1);
    if (userQuery.isEmpty) return nudges;

    int baseSleepGoal = userQuery.first['ideal_sleep_goal']; 
    int baseStudyLimit = userQuery.first['ideal_study_limit']; 

    // 2. Context-Aware Goal Adjustment (Weekend Calibration)
    // I implemented this to actively push back against the "always-on" academic culture.
    int activeStudyLimit = baseStudyLimit;
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      activeStudyLimit = (baseStudyLimit * 0.5).round(); // Automatically halve the study limit on weekends
      nudges.add("📅 Weekend Calibration: Your healthy study limit is automatically reduced to ${activeStudyLimit}h today. Prioritize rest.");
    }

    // 3. Fetching Longitudinal Data (The past 7 days)
    DateTime weekAgo = date.subtract(const Duration(days: 6));
    final trendData = await DatabaseHelper.instance.getStatsForDateRange(weekAgo, date);

    // Variables for calculating chronic trends
    double totalSleepLast7Days = 0;
    int consecutiveBurnoutDays = 0;
    
    // Analyze the historical trend data
    for (int i = 0; i < 7; i++) {
      DateTime checkDate = weekAgo.add(Duration(days: i));
      String dateString = checkDate.toIso8601String().split('T')[0];
      
      double dailyStudy = trendData[dateString]?['Study'] ?? 0.0;
      double dailySleep = trendData[dateString]?['Sleep'] ?? 0.0;
      
      totalSleepLast7Days += dailySleep;

      // Check for consecutive burnout (exceeding study limits multiple days in a row)
      if (dailyStudy > baseStudyLimit) {
        consecutiveBurnoutDays++;
      } else {
        consecutiveBurnoutDays = 0; // Reset streak if they rested
      }
    }

    // 4. Fetching Today's Exact Data
    String todayString = date.toIso8601String().split('T')[0];
    final dailyStats = await DatabaseHelper.instance.getDailyStats(todayString);
    double todayStudy = dailyStats['Study'] ?? 0.0;
    double todaySleep = dailyStats['Sleep'] ?? 0.0;
    double todayLeisure = dailyStats['Leisure'] ?? 0.0;
    double totalLoggedToday = todayStudy + todaySleep + todayLeisure;

    if (totalLoggedToday == 0) {
      return ["👋 Welcome! Add a time block today to receive your personalized longitudinal analysis."];
    }

    // 5. APPLYING ADVANCED LONGITUDINAL HEURISTICS

    // Rule A: Chronic Burnout (Compound Fatigue)
    if (consecutiveBurnoutDays >= 3) {
      nudges.add("🚨 COMPOUND FATIGUE: You have exceeded your study limits for $consecutiveBurnoutDays consecutive days. Your cognitive retention is severely compromised. Mandatory rest is advised.");
    } else if (todayStudy > activeStudyLimit) {
      nudges.add("⚠️ BURNOUT RISK: You scheduled ${todayStudy.toStringAsFixed(1)}h of study, exceeding your daily limit of ${activeStudyLimit}h.");
    } else if (todayStudy > 0 && todayStudy == activeStudyLimit) {
      nudges.add("✅ Max Capacity: You have hit your deep work limit for today. Time to transition to rest.");
    }

    // Rule B: Cumulative Sleep Debt
    // We calculate debt based on 7 days to trigger a chronic warning rather than an isolated bad night.
    double idealWeeklySleep = baseSleepGoal * 7.0;
    double sleepDebt = idealWeeklySleep - totalSleepLast7Days;
    
    // Only trigger if they have significant data logged (avoiding false alarms on day 1 of app use)
    if (sleepDebt > 4.0 && totalSleepLast7Days > 10) {
      nudges.add("🪫 CHRONIC SLEEP DEBT: You are missing ${sleepDebt.toStringAsFixed(1)}h of sleep this week. Chronic deprivation impairs emotional regulation and memory consolidation.");
    } else if (totalLoggedToday > 12 && todaySleep < baseSleepGoal) {
      nudges.add("🪫 RECOVERY DEFICIT: Only ${todaySleep.toStringAsFixed(1)}h of sleep scheduled today. You need ${baseSleepGoal}h for adequate recovery.");
    }

    // Rule C: Validating Rest
    if (todayStudy >= 2 && todayLeisure == 0 && totalLoggedToday > 8) {
      nudges.add("🧘 WARNING: Zero unstructured leisure time scheduled today. Please allocate time to decompress.");
    }

    // Rule D: Positive Reinforcement 
    if (todayStudy > 0 && todayStudy <= activeStudyLimit && todaySleep >= baseSleepGoal && todayLeisure > 0) {
      nudges.add("🌟 OPTIMAL BALANCE: Your schedule perfectly aligns with your holistic wellbeing goals!");
    }

    return nudges;
  }
}