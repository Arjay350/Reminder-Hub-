import 'dart:math';
import '../models/pet_models.dart';

/// Centralized service managing the Kitty's Body Condition, Feeding Intake,
/// and rolling history over time.
class PetBodyConditionService {
  static final PetBodyConditionService instance =
      PetBodyConditionService._internal();
  PetBodyConditionService._internal();

  /// Returns the number of feeding events recorded within the rolling intake window.
  int getRollingFeedingCount(
    List<PetFeedingRecord> history, {
    DateTime? currentTime,
    int rollingDays = PetBodyConditionConfig.rollingDays,
  }) {
    if (history.isEmpty) return 0;
    final now = currentTime ?? DateTime.now();
    final windowStart = now.subtract(Duration(days: rollingDays));
    return history.where((r) => r.timestamp.isAfter(windowStart)).length;
  }

  /// Calculates the average meals consumed per day across the rolling intake window.
  /// Handles newly adopted/started Kitties gracefully without penalizing them as starved.
  double getAverageDailyIntake(
    List<PetFeedingRecord> history, {
    DateTime? currentTime,
    int rollingDays = PetBodyConditionConfig.rollingDays,
  }) {
    if (history.isEmpty) return 0.0;
    final now = currentTime ?? DateTime.now();
    final windowStart = now.subtract(Duration(days: rollingDays));

    final recentRecords =
        history.where((r) => r.timestamp.isAfter(windowStart)).toList();
    if (recentRecords.isEmpty) return 0.0;

    final totalFood =
        recentRecords.fold<int>(0, (sum, r) => sum + r.foodConsumed);

    // Span from first recorded feed in this window to now, clamped between 1 and rollingDays
    final earliest = recentRecords.first.timestamp;
    final spanSeconds = now.difference(earliest).inSeconds;
    final spanDays = max(1.0, spanSeconds / 86400.0);
    final effectiveDays = min(rollingDays.toDouble(), max(1.0, spanDays));

    return totalFood / effectiveDays;
  }

  /// Retains recent history up to [maxHistoryDays] (default 30 days) for battery and storage efficiency.
  List<PetFeedingRecord> pruneOldRecords(
    List<PetFeedingRecord> history, {
    DateTime? currentTime,
    int maxHistoryDays = 30,
  }) {
    if (history.isEmpty) return history;
    final now = currentTime ?? DateTime.now();
    final cutoff = now.subtract(Duration(days: maxHistoryDays));
    return history.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  /// Evaluates offline elapsed device time since [lastBodyConditionUpdate]
  /// and adjusts the Kitty's body condition score gradually.
  ///
  /// - Underfeeding over days (< 1 meal/day): gradually drifts toward Skinny / Very Skinny.
  /// - Overfeeding over days (> 3 meals/day): gradually drifts toward Chubby / Very Chubby.
  /// - Balanced feeding (1 to 3 meals/day): smoothly recovers score toward 50.0 (Healthy).
  PetPreferences updateConditionForElapsedTime(
    PetPreferences prefs, {
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final lastUpdate = prefs.lastBodyConditionUpdate ?? now;
    final elapsedSeconds = now.difference(lastUpdate).inSeconds;

    if (elapsedSeconds <= 0) return prefs;

    final elapsedDays = elapsedSeconds / 86400.0;
    // Debounce small increments under 1 hour (~0.04 days) to conserve battery
    if (elapsedDays < 0.04) {
      return prefs;
    }

    final avgDaily =
        getAverageDailyIntake(prefs.feedingIntakeHistory, currentTime: now);
    double score = prefs.bodyConditionScore;

    if (avgDaily < PetBodyConditionConfig.healthyMinMealsPerDay) {
      // Underfeeding: score drops gradually based on elapsed time and feeding deficit
      final deficit = (PetBodyConditionConfig.healthyMinMealsPerDay - avgDaily) /
          PetBodyConditionConfig.healthyMinMealsPerDay;
      final decay = elapsedDays *
          PetBodyConditionConfig.scoreDecayPerDayWithoutFood *
          deficit.clamp(0.25, 1.0);
      score = (score - decay).clamp(0.0, 100.0);
    } else if (avgDaily > PetBodyConditionConfig.healthyMaxMealsPerDay) {
      // Overfeeding: score increases gradually towards Chubby / Very Chubby
      final excess = (avgDaily - PetBodyConditionConfig.healthyMaxMealsPerDay) /
          PetBodyConditionConfig.healthyMaxMealsPerDay;
      final gain = elapsedDays * 2.5 * excess.clamp(0.25, 2.0);
      score = (score + gain).clamp(0.0, 100.0);
    } else {
      // Balanced feeding: smoothly moves back towards the healthy midpoint (50.0)
      if (score > PetBodyConditionConfig.defaultScore) {
        final recovery = elapsedDays * 2.8; // ~2.8 points/day recovery
        score = max(PetBodyConditionConfig.defaultScore, score - recovery);
      } else if (score < PetBodyConditionConfig.defaultScore) {
        final recovery = elapsedDays * 2.8;
        score = min(PetBodyConditionConfig.defaultScore, score + recovery);
      }
    }

    final newCondition = PetBodyCondition.fromScore(score);

    return prefs.copyWith(
      bodyCondition: newCondition,
      bodyConditionScore: score,
      lastBodyConditionUpdate: now,
    );
  }

  /// Processes a single feeding event consuming 1 food:
  /// - Appends a timestamped [PetFeedingRecord].
  /// - Updates the rolling intake history.
  /// - Gradually adjusts the body condition score without abrupt jumps.
  PetPreferences processFeeding(
    PetPreferences prefs, {
    DateTime? feedingTime,
  }) {
    final now = feedingTime ?? DateTime.now();

    // 1. Catch up offline elapsed time first
    var currentPrefs = updateConditionForElapsedTime(prefs, currentTime: now);

    // 2. Add feeding record
    final record = PetFeedingRecord(
      timestamp: now,
      foodConsumed: 1,
      xpEarned: PetProgressionConfig.xpPerFood,
    );

    final updatedHistory =
        List<PetFeedingRecord>.from(currentPrefs.feedingIntakeHistory)..add(record);
    final prunedHistory = pruneOldRecords(updatedHistory, currentTime: now);

    // 3. Calculate rolling daily intake
    final avgDaily = getAverageDailyIntake(prunedHistory, currentTime: now);

    // 4. Gradual score adjustment
    double newScore = currentPrefs.bodyConditionScore;

    if (currentPrefs.bodyConditionScore < PetBodyConditionConfig.healthyMin) {
      // Recovering from skinny: each meal gives positive recovery (+1.8 to +2.4 points)
      newScore += PetBodyConditionConfig.scoreDeltaPerFeed * 1.35;
    } else if (avgDaily > PetBodyConditionConfig.healthyMaxMealsPerDay) {
      // Consistently high feeding rate: gradual nudge (+1.6 points)
      newScore += PetBodyConditionConfig.scoreDeltaPerFeed;
    } else if (currentPrefs.bodyConditionScore >
        PetBodyConditionConfig.healthyMax) {
      // Currently chubby, but user is feeding within healthy range: nudge back toward healthy
      newScore -= 0.6;
    } else {
      // In healthy range (40–60): keep stabilized toward midpoint 50.0
      if (newScore < PetBodyConditionConfig.defaultScore) {
        newScore = min(PetBodyConditionConfig.defaultScore, newScore + 0.8);
      } else if (newScore > PetBodyConditionConfig.defaultScore + 3) {
        newScore = max(PetBodyConditionConfig.defaultScore, newScore - 0.4);
      }
    }

    newScore = newScore.clamp(0.0, 100.0);
    final newCondition = PetBodyCondition.fromScore(newScore);

    return currentPrefs.copyWith(
      bodyCondition: newCondition,
      bodyConditionScore: newScore,
      feedingIntakeHistory: prunedHistory,
      lastBodyConditionUpdate: now,
    );
  }

  /// Returns friendly, supportive feedback whenever the Kitty transitions body condition.
  String? getConditionChangeFeedback(
    PetBodyCondition previous,
    PetBodyCondition current,
  ) {
    if (previous == current) return null;

    switch (current) {
      case PetBodyCondition.verySkinny:
        return 'Kitty is looking quite slender. Extra meals will help rebuild strength! 🐾';
      case PetBodyCondition.skinny:
        if (previous == PetBodyCondition.verySkinny) {
          return 'Kitty is gaining energy and getting healthier! Keep it up! ✨';
        }
        return 'Kitty is looking a bit slim. A tasty meal now and then would be great! 🍖';
      case PetBodyCondition.healthy:
        if (previous == PetBodyCondition.chubby ||
            previous == PetBodyCondition.veryChubby) {
          return 'Kitty is back in tip-top shape! Perfectly balanced and active! ❤️';
        } else {
          return 'Kitty is looking vibrant, healthy, and happy! Great care! 🌟';
        }
      case PetBodyCondition.chubby:
        if (previous == PetBodyCondition.veryChubby) {
          return 'Kitty is slimming down nicely into a cute cuddly shape! 🐱';
        }
        return 'Kitty is getting a little plump and cuddly from generous meals! 🐾';
      case PetBodyCondition.veryChubby:
        return 'Kitty has grown super round and fluffy! Lots of tasty treats recently! 🐱✨';
    }
  }

  /// Friendly descriptor of the intake pattern.
  String getIntakeDescription(double avgMealsPerDay) {
    if (avgMealsPerDay < 0.5) return 'Very Light Intake';
    if (avgMealsPerDay < PetBodyConditionConfig.healthyMinMealsPerDay) {
      return 'Light Intake';
    }
    if (avgMealsPerDay <= PetBodyConditionConfig.healthyMaxMealsPerDay) {
      return 'Balanced Intake';
    }
    if (avgMealsPerDay <= 5.0) return 'Generous Intake';
    return 'Very Generous Intake';
  }
}
