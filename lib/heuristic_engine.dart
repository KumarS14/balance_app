import 'database_helper.dart';

class HeuristicEngine {
  // I designed this heuristic engine to act as the core "Action" stage of my Personal Informatics model.
  // By intentionally using transparent, rule-based logic instead of a "black box" AI, 
  // I ensure complete data privacy and algorithmic explainability for the user.
  static Future<List<String>> generateDailyNudges(DateTime date) async {
    List<String> nudges = [];
    final db = await DatabaseHelper.instance.database;

    // 1. Fetching the user's self-defined goals (Ideal Metrics)
    final List<Map<String, dynamic>> userQuery = await db.query('users', limit: 1);
    
    // Defensive Programming: If user data fails to load, I abort to prevent null crashes
    if (userQuery.isEmpty) return nudges;

    int sleepGoal = userQuery.first['ideal_sleep_goal']; 
    int studyLimit = userQuery.first['ideal_study_limit']; 

    // 2. Fetching the actual time allocation for the selected day
    String dateString = date.toIso8601String().split('T')[0];
    final dailyStats = await DatabaseHelper.instance.getDailyStats(dateString);

    double studyHours = dailyStats['Study'] ?? 0.0;
    double sleepHours = dailyStats['Sleep'] ?? 0.0;
    double leisureHours = dailyStats['Leisure'] ?? 0.0;
    double totalLogged = studyHours + sleepHours + leisureHours;

    // Defensive Programming: If the user hasn't logged any time, I prompt them to begin the Collection stage.
    if (totalLogged == 0) {
      return ["👋 Welcome! Add a time block today to receive your personalized balance analysis."];
    }

    // 3. APPLYING MY HEURISTIC RULES
    // These rules are specifically engineered to combat the "achievement society" pressures I identified in my research.

    // Rule A: Mitigating Academic Burnout (Over-studying)
    if (studyHours > studyLimit) {
      nudges.add("⚠️ BURNOUT RISK: You scheduled ${studyHours.toStringAsFixed(1)}h of study, exceeding your healthy limit of ${studyLimit}h. You are at high risk of cognitive fatigue.");
    } else if (studyHours > 0 && studyHours == studyLimit) {
      nudges.add("✅ Max Capacity: You have hit your deep work limit for today. Time to transition to rest.");
    }

    // Rule B: Preventing Recovery Deficits (Under-sleeping)
    // I only trigger this if they have planned a significant portion of their day, to avoid premature warnings.
    if (totalLogged > 12 && sleepHours < sleepGoal) {
      nudges.add("🪫 RECOVERY DEFICIT: Only ${sleepHours.toStringAsFixed(1)}h of sleep scheduled. You need ${sleepGoal}h for adequate memory consolidation and health.");
    }

    // Rule C: Validating Rest (Combating "Hustle Culture")
    if (studyHours >= 2 && leisureHours == 0 && totalLogged > 8) {
      nudges.add("🧘 WARNING: Zero unstructured leisure time scheduled. Constant optimization leads to stress. Please allocate time for a break.");
    }

    // Rule D: Positive Reinforcement 
    if (studyHours > 0 && studyHours <= studyLimit && sleepHours >= sleepGoal && leisureHours > 0) {
      nudges.add("🌟 PERFECT BALANCE: Your schedule aligns optimally with your holistic wellbeing goals!");
    }

    return nudges;
  }
}