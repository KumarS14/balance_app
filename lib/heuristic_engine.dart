import 'database_helper.dart';

class HeuristicEngine {
  // --- ARCHITECTURAL DECISION: ALGORITHMIC TRANSPARENCY ---
  // To fulfill the 'Action' stage of my Personal Informatics model, I engineered 
  // this transparent, rule-based Heuristic Engine. I explicitly rejected the use of 
  // opaque 'black-box' AI to guarantee that users always understand the exact logic 
  // behind their behavioral nudges.

  static Future<List<String>> generateDailyNudges(DateTime date) async {
    List<String> nudges = [];
    final db = await DatabaseHelper.instance.database;

    // 1. BASELINE FORMULATION: Fetching my user's self-defined health goals.
    final List<Map<String, dynamic>> userQuery = await db.query('users', limit: 1);
    if (userQuery.isEmpty) return nudges; 

    int baseSleepGoal = userQuery.first['ideal_sleep_goal']; 
    int baseStudyLimit = userQuery.first['ideal_study_limit']; 

    // 2. CONTEXT-AWARE ADJUSTMENT: Weekend Calibration
    // I implemented this to actively push back against the "always-on" academic hustle culture.
    int activeStudyLimit = baseStudyLimit;
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      activeStudyLimit = (baseStudyLimit * 0.5).round(); 
      nudges.add("📅 Weekend Calibration: Your healthy study limit is automatically reduced to ${activeStudyLimit}h today. Prioritize rest.");
    }

    // 3. LONGITUDINAL DATA AGGREGATION: The past 7 days
    DateTime weekAgo = date.subtract(const Duration(days: 6));
    final trendData = await DatabaseHelper.instance.getStatsForDateRange(weekAgo, date);

    double totalSleepLast7Days = 0;
    int consecutiveBurnoutDays = 0;
    
    for (int i = 0; i < 7; i++) {
      DateTime checkDate = weekAgo.add(Duration(days: i));
      String dateString = checkDate.toIso8601String().split('T')[0];
      
      double dailyStudy = trendData[dateString]?['Study'] ?? 0.0;
      double dailySleep = trendData[dateString]?['Sleep'] ?? 0.0;
      
      totalSleepLast7Days += dailySleep;

      if (dailyStudy > baseStudyLimit) {
        consecutiveBurnoutDays++;
      } else {
        consecutiveBurnoutDays = 0; 
      }
    }

    // 4. ACUTE DATA AGGREGATION: Today's exact metrics
    String todayString = date.toIso8601String().split('T')[0];
    final dailyStats = await DatabaseHelper.instance.getDailyStats(todayString);
    double todayStudy = dailyStats['Study'] ?? 0.0;
    double todaySleep = dailyStats['Sleep'] ?? 0.0;
    double todayLeisure = dailyStats['Leisure'] ?? 0.0;
    double totalLoggedToday = todayStudy + todaySleep + todayLeisure;

    if (totalLoggedToday == 0) {
      return ["👋 Welcome! Add a time block today to receive your personalized balance analysis."];
    }

    // --- 5. APPLYING ADVANCED HCI HEURISTICS ---

    if (todayStudy == 0 && todayLeisure >= 4.0) {
      nudges.add("🌴 RECOVERY DAY DETECTED: You prioritized unstructured rest today. This psychological detachment is crucial for long-term academic sustainability.");
    }

    if (consecutiveBurnoutDays >= 3) {
      nudges.add("🚨 COMPOUND FATIGUE: You have exceeded study limits for $consecutiveBurnoutDays consecutive days. Your cognitive retention is severely compromised.");
    } else if (todayStudy > activeStudyLimit) {
      nudges.add("⚠️ BURNOUT RISK: You scheduled ${todayStudy.toStringAsFixed(1)}h of study, exceeding your daily limit of ${activeStudyLimit}h.");
    } else if (todayStudy > 0 && todayStudy == activeStudyLimit) {
      nudges.add("✅ Max Capacity: You hit your deep work limit for today. Time to transition to rest.");
    }

    double wakingHours = todayStudy + todayLeisure;
    if (wakingHours > 5 && (todayStudy / wakingHours) > 0.85) {
      nudges.add("⚖️ BALANCE SKEW: Over 85% of your waking logged time is dedicated to study. You need unstructured leisure to prevent mental fatigue.");
    }

    double idealWeeklySleep = baseSleepGoal * 7.0;
    double sleepDebt = idealWeeklySleep - totalSleepLast7Days;
    
    if (todaySleep > 0 && todaySleep <= 4.0) {
      nudges.add("🆘 ACUTE DEPRIVATION: You logged 4 hours or less of sleep. Your immune function and memory consolidation are highly compromised today. Avoid deep work.");
    } else if (sleepDebt > 4.0 && totalSleepLast7Days > 10) {
      nudges.add("🪫 CHRONIC SLEEP DEBT: You are missing ${sleepDebt.toStringAsFixed(1)}h of sleep this week. Chronic deprivation impairs emotional regulation.");
    } else if (totalLoggedToday > 12 && todaySleep < baseSleepGoal) {
      // FORMATIVE EVALUATION UPDATE: Following Participant 2's feedback, I updated this string 
      // from 'Recovery Deficit' to 'Sleep Deficit' to better align with the natural vocabulary of my users.
      nudges.add("🪫 SLEEP DEFICIT: You only scheduled ${todaySleep.toStringAsFixed(1)}h of sleep today. You need at least ${baseSleepGoal}h for adequate cognitive recovery.");
    }

    if (todayStudy > 0 && todayStudy <= activeStudyLimit && todaySleep >= baseSleepGoal && todayLeisure > 0) {
      nudges.add("🌟 OPTIMAL BALANCE: Your schedule perfectly aligns with your holistic wellbeing goals!");
    }

    return nudges;
  }
}