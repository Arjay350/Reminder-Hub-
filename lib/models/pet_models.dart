import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents the active animation/behavior state of the pet companion.
enum PetState {
  idle,
  lookingAround,
  blinking,
  walking,
  happy,
  worried,
  surprised,
  sleeping,
  waking,
  beingPetted,
  studying,
  celebrating,
  eating,
  hungry,
}

/// Represents the overall emotional mood of the pet, derived from app events.
enum PetMood {
  happy,
  neutral,
  sleepy,
  focused,
  worried,
  excited;

  String get displayName {
    switch (this) {
      case PetMood.happy:
        return 'Happy';
      case PetMood.neutral:
        return 'Calm';
      case PetMood.sleepy:
        return 'Sleepy';
      case PetMood.focused:
        return 'Focused';
      case PetMood.worried:
        return 'Worried';
      case PetMood.excited:
        return 'Excited';
    }
  }

  /// Lowercase label matching the pill style (e.g., 'focused', 'happy', 'excited', 'sleepy', 'worried', 'calm')
  String get label {
    switch (this) {
      case PetMood.neutral:
        return 'calm';
      default:
        return name;
    }
  }

  /// Icon corresponding to the mood
  IconData get icon {
    switch (this) {
      case PetMood.focused:
        return Icons.psychology_rounded;
      case PetMood.happy:
        return Icons.sentiment_very_satisfied_rounded;
      case PetMood.excited:
        return Icons.auto_awesome_rounded;
      case PetMood.sleepy:
        return Icons.bedtime_rounded;
      case PetMood.worried:
        return Icons.sentiment_dissatisfied_rounded;
      case PetMood.neutral:
        return Icons.spa_rounded;
    }
  }

  /// Primary theme accent color for the mood
  Color get color {
    switch (this) {
      case PetMood.focused:
        return const Color(0xFF818CF8); // Soft indigo / purple (matches badge mockup)
      case PetMood.happy:
        return const Color(0xFF34D399); // Soft emerald green
      case PetMood.excited:
        return const Color(0xFFF472B6); // Rose / Pink
      case PetMood.sleepy:
        return const Color(0xFFA78BFA); // Lavender / Violet
      case PetMood.worried:
        return const Color(0xFFFB923C); // Amber / Orange
      case PetMood.neutral:
        return const Color(0xFF38BDF8); // Sky blue
    }
  }
}

/// Coat appearance variations for the 2D cat companion.
enum PetCoatStyle {
  gingerTabby,
  tuxedoMidnight,
  calico,
  snowWhite,
}

/// Reaction triggers dispatched by system events or user touch.
enum PetReaction {
  taskCompleted,
  billPaid,
  upcomingBill,
  reminderDue,
  classStarting,
  classEnded,
  studyStarted,
  studyCompleted,
  breakStarted,
  tapped,
  petted,
  userReturned,
}

/// Direction the pet is currently facing or gazing.
enum PetLookDirection {
  center,
  left,
  right,
  up,
  down,
}

/// Discrete hunger states representing the Kitty's current satiety.
enum HungerState {
  wellFed, // 80–100%
  gettingHungry, // 50–79%
  hungry, // 20–49%
  veryHungry, // 1–19%
  empty; // 0%

  String get displayName {
    switch (this) {
      case HungerState.wellFed:
        return 'Well Fed';
      case HungerState.gettingHungry:
        return 'Getting Hungry';
      case HungerState.hungry:
        return 'Hungry';
      case HungerState.veryHungry:
        return 'Very Hungry';
      case HungerState.empty:
        return 'Empty';
    }
  }

  String get description {
    switch (this) {
      case HungerState.wellFed:
        return 'Happy & energetic!';
      case HungerState.gettingHungry:
        return 'Looking towards the food area.';
      case HungerState.hungry:
        return 'Tummy is rumbling a little.';
      case HungerState.veryHungry:
        return 'Needs a tasty meal soon!';
      case HungerState.empty:
        return 'Ready for food whenever you have some.';
    }
  }

  static HungerState fromPercentage(double hunger) {
    if (hunger >= 80.0) return HungerState.wellFed;
    if (hunger >= 50.0) return HungerState.gettingHungry;
    if (hunger >= 20.0) return HungerState.hungry;
    if (hunger >= 1.0) return HungerState.veryHungry;
    return HungerState.empty;
  }
}

/// Body condition representing the Kitty's physical appearance and feeding intake over time.
enum PetBodyCondition {
  verySkinny, // 0–19 score
  skinny, // 20–39 score
  healthy, // 40–60 score (default)
  chubby, // 61–80 score
  veryChubby; // 81–100 score

  String get displayName {
    switch (this) {
      case PetBodyCondition.verySkinny:
        return 'Very Skinny';
      case PetBodyCondition.skinny:
        return 'Skinny';
      case PetBodyCondition.healthy:
        return 'Healthy';
      case PetBodyCondition.chubby:
        return 'Chubby';
      case PetBodyCondition.veryChubby:
        return 'Very Chubby';
    }
  }

  String get description {
    switch (this) {
      case PetBodyCondition.verySkinny:
        return 'Looking quite slender. Could use more regular meals over time.';
      case PetBodyCondition.skinny:
        return 'A bit slim. An extra meal now and then would be welcome!';
      case PetBodyCondition.healthy:
        return 'Ideal body condition! Active, vibrant, and well-balanced.';
      case PetBodyCondition.chubby:
        return 'A little plump and cuddly from generous treats!';
      case PetBodyCondition.veryChubby:
        return 'Super round and fluffy! Lots of tasty feedings recently.';
    }
  }

  /// Body width factor multiplier applied during canvas painting
  double get bodyWidthFactor {
    switch (this) {
      case PetBodyCondition.verySkinny:
        return 0.86;
      case PetBodyCondition.skinny:
        return 0.93;
      case PetBodyCondition.healthy:
        return 1.00;
      case PetBodyCondition.chubby:
        return 1.10;
      case PetBodyCondition.veryChubby:
        return 1.20;
    }
  }

  /// Cheek fullness factor multiplier
  double get cheekFactor {
    switch (this) {
      case PetBodyCondition.verySkinny:
        return 0.90;
      case PetBodyCondition.skinny:
        return 0.95;
      case PetBodyCondition.healthy:
        return 1.00;
      case PetBodyCondition.chubby:
        return 1.08;
      case PetBodyCondition.veryChubby:
        return 1.16;
    }
  }

  static PetBodyCondition fromScore(double score) {
    if (score < PetBodyConditionConfig.verySkinnyMax) return PetBodyCondition.verySkinny;
    if (score < PetBodyConditionConfig.skinnyMax) return PetBodyCondition.skinny;
    if (score <= PetBodyConditionConfig.healthyMax) return PetBodyCondition.healthy;
    if (score <= PetBodyConditionConfig.chubbyMax) return PetBodyCondition.chubby;
    return PetBodyCondition.veryChubby;
  }
}

/// A recorded feeding intake event stored locally.
class PetFeedingRecord {
  const PetFeedingRecord({
    required this.timestamp,
    this.foodConsumed = 1,
    this.xpEarned = 5,
  });

  final DateTime timestamp;
  final int foodConsumed;
  final int xpEarned;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'foodConsumed': foodConsumed,
    'xpEarned': xpEarned,
  };

  factory PetFeedingRecord.fromJson(Map<String, dynamic> json) {
    return PetFeedingRecord(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      foodConsumed: json['foodConsumed'] as int? ?? 1,
      xpEarned: json['xpEarned'] as int? ?? 5,
    );
  }
}

/// Central configuration for Body Condition and Rolling Intake calculations.
class PetBodyConditionConfig {
  static const double defaultScore = 50.0; // Centered in Healthy (40–60)
  static const int rollingDays = 7; // 7-day rolling window

  // Score thresholds (0 to 100)
  static const double verySkinnyMax = 20.0;
  static const double skinnyMax = 40.0;
  static const double healthyMin = 40.0;
  static const double healthyMax = 60.0;
  static const double chubbyMax = 80.0;

  // Balanced feeding target range (meals per day average over rolling window)
  static const double healthyMinMealsPerDay = 1.0;
  static const double healthyMaxMealsPerDay = 3.0;
  static const double idealMealsPerDay = 2.0;

  // Gradual score step adjustments
  static const double scoreDeltaPerFeed = 1.6;
  static const double scoreDecayPerDayWithoutFood = 3.5;
}

/// Compatibility helper mapping Growth Stage, Body Condition, and Animation to sprite keys.
class KittyVisualVariantHelper {
  static String mapGrowthCategory(PetGrowthStage stage) {
    switch (stage) {
      case PetGrowthStage.tinyKitten:
      case PetGrowthStage.growingKitten:
      case PetGrowthStage.olderKitten:
        return 'kitten';
      case PetGrowthStage.youngCat:
        return 'young';
      case PetGrowthStage.youngAdult:
      case PetGrowthStage.adultCat:
        return 'adult';
    }
  }

  static String mapBodyCategory(PetBodyCondition condition) {
    switch (condition) {
      case PetBodyCondition.verySkinny:
      case PetBodyCondition.skinny:
        return 'skinny';
      case PetBodyCondition.healthy:
        return 'healthy';
      case PetBodyCondition.chubby:
      case PetBodyCondition.veryChubby:
        return 'chubby';
    }
  }

  static String getVariantKey({
    required PetGrowthStage growthStage,
    required PetBodyCondition bodyCondition,
    required PetState animationState,
  }) {
    final growth = mapGrowthCategory(growthStage);
    final body = mapBodyCategory(bodyCondition);
    final anim = animationState.name;
    return '${growth}_${body}_$anim';
  }

  static String resolveSpriteAssetPath({
    required PetGrowthStage growthStage,
    required PetBodyCondition bodyCondition,
  }) {
    final growth = mapGrowthCategory(growthStage);
    final body = mapBodyCategory(bodyCondition);
    return 'assets/pet/sprites/${growth}_$body.png';
  }
}

/// Represents the compound visual appearance of the Kitty, combining Growth Stage,
/// Body Condition, and Animation State.
class KittyAppearance {
  const KittyAppearance({
    required this.growthStage,
    required this.bodyCondition,
    required this.animationState,
    required this.variantKey,
    required this.spriteAssetPath,
  });

  final PetGrowthStage growthStage;
  final PetBodyCondition bodyCondition;
  final PetState animationState;
  final String variantKey;
  final String spriteAssetPath;

  static KittyAppearance fromState({
    required PetGrowthStage growthStage,
    required PetBodyCondition bodyCondition,
    required PetState animationState,
  }) {
    return KittyAppearance(
      growthStage: growthStage,
      bodyCondition: bodyCondition,
      animationState: animationState,
      variantKey: KittyVisualVariantHelper.getVariantKey(
        growthStage: growthStage,
        bodyCondition: bodyCondition,
        animationState: animationState,
      ),
      spriteAssetPath: KittyVisualVariantHelper.resolveSpriteAssetPath(
        growthStage: growthStage,
        bodyCondition: bodyCondition,
      ),
    );
  }
}

/// Growth stages reflecting the Kitty's age and maturity progression.
enum PetGrowthStage {
  tinyKitten, // Level 1
  growingKitten, // Level 2–3
  olderKitten, // Level 4–5
  youngCat, // Level 6–7
  youngAdult, // Level 8–9
  adultCat; // Level 10

  String get displayName {
    switch (this) {
      case PetGrowthStage.tinyKitten:
        return 'Tiny Kitten';
      case PetGrowthStage.growingKitten:
        return 'Growing Kitten';
      case PetGrowthStage.olderKitten:
        return 'Older Kitten';
      case PetGrowthStage.youngCat:
        return 'Young Cat';
      case PetGrowthStage.youngAdult:
        return 'Young Adult Cat';
      case PetGrowthStage.adultCat:
        return 'Fully Grown Adult Kitty';
    }
  }

  double get scaleFactor {
    switch (this) {
      case PetGrowthStage.tinyKitten:
        return 0.76;
      case PetGrowthStage.growingKitten:
        return 0.85;
      case PetGrowthStage.olderKitten:
        return 0.93;
      case PetGrowthStage.youngCat:
        return 1.00;
      case PetGrowthStage.youngAdult:
        return 1.08;
      case PetGrowthStage.adultCat:
        return 1.15;
    }
  }

  static PetGrowthStage fromLevel(int level) {
    if (level <= 1) return PetGrowthStage.tinyKitten;
    if (level <= 3) return PetGrowthStage.growingKitten;
    if (level <= 5) return PetGrowthStage.olderKitten;
    if (level <= 7) return PetGrowthStage.youngCat;
    if (level <= 9) return PetGrowthStage.youngAdult;
    return PetGrowthStage.adultCat;
  }
}

/// Central configuration for Kitty progression, hunger, and food XP.
class PetProgressionConfig {
  static const int maxLevel = 10;
  static const int xpPerFood = 5; // Exactly 5 XP per food
  static const double defaultHungerRestore = 20.0; // +20 Hunger clamped to 100%
  static const double defaultDecayHoursFor10Percent = 6.0; // 10% decay every 6 hours

  static const Map<int, int> levelXpThresholds = {
    1: 100,
    2: 150,
    3: 200,
    4: 250,
    5: 300,
    6: 350,
    7: 400,
    8: 450,
    9: 500,
    10: 500, // Level 10 is max
  };

  static int getXpRequiredForLevel(int level) {
    if (level < 1) return levelXpThresholds[1]!;
    if (level >= maxLevel) return levelXpThresholds[maxLevel]!;
    return levelXpThresholds[level] ?? 500;
  }
}

/// Model representing a daily productivity task that awards food.
class PetDailyTask {
  const PetDailyTask({
    required this.id,
    required this.title,
    required this.category,
    required this.foodReward,
    required this.requiredCount,
    this.currentCount = 0,
    this.isClaimed = false,
  });

  final String id;
  final String title;
  final String category; // 'Reminders', 'School', 'Study', 'Bills'
  final int foodReward;
  final int requiredCount;
  final int currentCount;
  final bool isClaimed;

  bool get isCompleted => currentCount >= requiredCount;

  PetDailyTask copyWith({
    String? id,
    String? title,
    String? category,
    int? foodReward,
    int? requiredCount,
    int? currentCount,
    bool? isClaimed,
  }) {
    return PetDailyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      foodReward: foodReward ?? this.foodReward,
      requiredCount: requiredCount ?? this.requiredCount,
      currentCount: currentCount ?? this.currentCount,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'foodReward': foodReward,
    'requiredCount': requiredCount,
    'currentCount': currentCount,
    'isClaimed': isClaimed,
  };

  factory PetDailyTask.fromJson(Map<String, dynamic> json) {
    return PetDailyTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Reminders',
      foodReward: json['foodReward'] as int? ?? 1,
      requiredCount: json['requiredCount'] as int? ?? 1,
      currentCount: json['currentCount'] as int? ?? 0,
      isClaimed: json['isClaimed'] as bool? ?? false,
    );
  }
}

/// Local persistence settings, stats, hunger, and body condition state for the pet companion.
class PetPreferences {
  const PetPreferences({
    this.enabled = true,
    this.name = 'Mochi',
    this.coatStyle = PetCoatStyle.gingerTabby,
    this.soundEnabled = true,
    this.interactionReactionsEnabled = true,
    this.movementEnabled = true,
    this.totalPets = 0,
    this.totalInteractions = 0,
    this.tasksCelebrated = 0,
    this.studySessionsAccompanied = 0,
    this.lastInteractionTime,
    // Progression & Hunger fields
    this.petLevel = 1,
    this.currentXp = 0,
    this.totalXp = 0,
    this.foodInventory = 5, // Starts with 5 food so user can immediately feed
    this.hunger = 80.0, // Starts well-fed
    this.lastHungerUpdate,
    this.hungerDecayHours = 6.0,
    this.hungerRestoreAmount = 20.0,
    this.totalFeedings = 0,
    this.lastTaskGenerationDate,
    this.dailyTasks = const [],
    this.dailyTaskCompletionState = const {},
    this.claimedDailyRewards = const [],
    this.weeklyTaskState = const {},
    // Body Condition & Feeding Intake fields
    this.bodyCondition = PetBodyCondition.healthy,
    this.bodyConditionScore = 50.0,
    this.feedingIntakeHistory = const [],
    this.lastBodyConditionUpdate,
  });

  final bool enabled;
  final String name;
  final PetCoatStyle coatStyle;
  final bool soundEnabled;
  final bool interactionReactionsEnabled;
  final bool movementEnabled;
  final int totalPets;
  final int totalInteractions;
  final int tasksCelebrated;
  final int studySessionsAccompanied;
  final DateTime? lastInteractionTime;

  // Progression & Hunger state
  final int petLevel;
  final int currentXp;
  final int totalXp;
  final int foodInventory;
  final double hunger;
  final DateTime? lastHungerUpdate;
  final double hungerDecayHours;
  final double hungerRestoreAmount;
  final int totalFeedings;
  final String? lastTaskGenerationDate;
  final List<PetDailyTask> dailyTasks;
  final Map<String, int> dailyTaskCompletionState;
  final List<String> claimedDailyRewards;
  final Map<String, dynamic> weeklyTaskState;

  // Body Condition & Feeding Intake
  final PetBodyCondition bodyCondition;
  final double bodyConditionScore;
  final List<PetFeedingRecord> feedingIntakeHistory;
  final DateTime? lastBodyConditionUpdate;

  PetGrowthStage get growthStage => PetGrowthStage.fromLevel(petLevel);
  HungerState get hungerState => HungerState.fromPercentage(hunger);
  int get xpRequired => PetProgressionConfig.getXpRequiredForLevel(petLevel);
  double get xpProgress =>
      petLevel >= PetProgressionConfig.maxLevel
          ? 1.0
          : (currentXp / xpRequired).clamp(0.0, 1.0);
  double get hungerProgress => (hunger / 100.0).clamp(0.0, 1.0);
  bool get isMaxLevel => petLevel >= PetProgressionConfig.maxLevel;
  KittyAppearance get appearance => KittyAppearance.fromState(
        growthStage: growthStage,
        bodyCondition: bodyCondition,
        animationState: PetState.idle,
      );

  PetPreferences copyWith({
    bool? enabled,
    String? name,
    PetCoatStyle? coatStyle,
    bool? soundEnabled,
    bool? interactionReactionsEnabled,
    bool? movementEnabled,
    int? totalPets,
    int? totalInteractions,
    int? tasksCelebrated,
    int? studySessionsAccompanied,
    DateTime? lastInteractionTime,
    int? petLevel,
    int? currentXp,
    int? totalXp,
    int? foodInventory,
    double? hunger,
    DateTime? lastHungerUpdate,
    double? hungerDecayHours,
    double? hungerRestoreAmount,
    int? totalFeedings,
    String? lastTaskGenerationDate,
    List<PetDailyTask>? dailyTasks,
    Map<String, int>? dailyTaskCompletionState,
    List<String>? claimedDailyRewards,
    Map<String, dynamic>? weeklyTaskState,
    PetBodyCondition? bodyCondition,
    double? bodyConditionScore,
    List<PetFeedingRecord>? feedingIntakeHistory,
    DateTime? lastBodyConditionUpdate,
  }) {
    return PetPreferences(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      coatStyle: coatStyle ?? this.coatStyle,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      interactionReactionsEnabled:
          interactionReactionsEnabled ?? this.interactionReactionsEnabled,
      movementEnabled: movementEnabled ?? this.movementEnabled,
      totalPets: totalPets ?? this.totalPets,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      tasksCelebrated: tasksCelebrated ?? this.tasksCelebrated,
      studySessionsAccompanied:
          studySessionsAccompanied ?? this.studySessionsAccompanied,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      petLevel: (petLevel ?? this.petLevel).clamp(1, PetProgressionConfig.maxLevel),
      currentXp: currentXp ?? this.currentXp,
      totalXp: totalXp ?? this.totalXp,
      foodInventory: (foodInventory ?? this.foodInventory).clamp(0, 99999),
      hunger: (hunger ?? this.hunger).clamp(0.0, 100.0),
      lastHungerUpdate: lastHungerUpdate ?? this.lastHungerUpdate,
      hungerDecayHours: hungerDecayHours ?? this.hungerDecayHours,
      hungerRestoreAmount: hungerRestoreAmount ?? this.hungerRestoreAmount,
      totalFeedings: totalFeedings ?? this.totalFeedings,
      lastTaskGenerationDate:
          lastTaskGenerationDate ?? this.lastTaskGenerationDate,
      dailyTasks: dailyTasks ?? this.dailyTasks,
      dailyTaskCompletionState:
          dailyTaskCompletionState ?? this.dailyTaskCompletionState,
      claimedDailyRewards: claimedDailyRewards ?? this.claimedDailyRewards,
      weeklyTaskState: weeklyTaskState ?? this.weeklyTaskState,
      bodyCondition: bodyCondition ?? this.bodyCondition,
      bodyConditionScore:
          (bodyConditionScore ?? this.bodyConditionScore).clamp(0.0, 100.0),
      feedingIntakeHistory: feedingIntakeHistory ?? this.feedingIntakeHistory,
      lastBodyConditionUpdate:
          lastBodyConditionUpdate ?? this.lastBodyConditionUpdate,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'name': name,
    'coatStyle': coatStyle.name,
    'soundEnabled': soundEnabled,
    'interactionReactionsEnabled': interactionReactionsEnabled,
    'movementEnabled': movementEnabled,
    'totalPets': totalPets,
    'totalInteractions': totalInteractions,
    'tasksCelebrated': tasksCelebrated,
    'studySessionsAccompanied': studySessionsAccompanied,
    'lastInteractionTime': lastInteractionTime?.toIso8601String(),
    // Progression & Hunger
    'petLevel': petLevel,
    'currentXp': currentXp,
    'totalXp': totalXp,
    'foodInventory': foodInventory,
    'hunger': hunger,
    'lastHungerUpdate': lastHungerUpdate?.toIso8601String(),
    'growthStage': growthStage.name,
    'hungerDecayHours': hungerDecayHours,
    'hungerRestoreAmount': hungerRestoreAmount,
    'totalFeedings': totalFeedings,
    'lastTaskGenerationDate': lastTaskGenerationDate,
    'dailyTasks': dailyTasks.map((t) => t.toJson()).toList(),
    'dailyTaskCompletionState': dailyTaskCompletionState,
    'claimedDailyRewards': claimedDailyRewards,
    'weeklyTaskState': weeklyTaskState,
    // Body Condition & Feeding Intake
    'bodyCondition': bodyCondition.name,
    'bodyConditionScore': bodyConditionScore,
    'feedingIntakeHistory': feedingIntakeHistory.map((r) => r.toJson()).toList(),
    'lastBodyConditionUpdate': lastBodyConditionUpdate?.toIso8601String(),
  };

  factory PetPreferences.fromJson(Map<String, dynamic> json) {
    PetCoatStyle parseCoat(dynamic val) {
      if (val is String) {
        for (final style in PetCoatStyle.values) {
          if (style.name == val) return style;
        }
      }
      return PetCoatStyle.gingerTabby;
    }

    PetBodyCondition parseBodyCondition(dynamic val) {
      if (val is String) {
        for (final c in PetBodyCondition.values) {
          if (c.name == val) return c;
        }
      }
      return PetBodyCondition.healthy;
    }

    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    List<PetDailyTask> parseTasks(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map((e) => PetDailyTask.fromJson(e))
            .toList();
      }
      return [];
    }

    List<PetFeedingRecord> parseFeedingHistory(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map((e) => PetFeedingRecord.fromJson(e))
            .toList();
      }
      return const [];
    }

    Map<String, int> parseCountMap(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    Map<String, dynamic> parseGenericMap(dynamic val) {
      if (val is Map) {
        return Map<String, dynamic>.from(val);
      }
      return {};
    }

    final rawLevel = json['petLevel'] as int? ?? 1;
    final rawHunger = (json['hunger'] as num?)?.toDouble() ?? 80.0;
    final rawFood = json['foodInventory'] as int? ?? 5;
    final rawScore = (json['bodyConditionScore'] as num?)?.toDouble() ??
        PetBodyConditionConfig.defaultScore;

    return PetPreferences(
      enabled: json['enabled'] as bool? ?? true,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Mochi',
      coatStyle: parseCoat(json['coatStyle']),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      interactionReactionsEnabled:
          json['interactionReactionsEnabled'] as bool? ?? true,
      movementEnabled: json['movementEnabled'] as bool? ?? true,
      totalPets: json['totalPets'] as int? ?? 0,
      totalInteractions: json['totalInteractions'] as int? ?? 0,
      tasksCelebrated: json['tasksCelebrated'] as int? ?? 0,
      studySessionsAccompanied:
          json['studySessionsAccompanied'] as int? ?? 0,
      lastInteractionTime: parseDate(json['lastInteractionTime']),
      // Progression & Hunger
      petLevel: rawLevel.clamp(1, PetProgressionConfig.maxLevel),
      currentXp: json['currentXp'] as int? ?? 0,
      totalXp: json['totalXp'] as int? ?? 0,
      foodInventory: rawFood < 0 ? 0 : rawFood,
      hunger: rawHunger.clamp(0.0, 100.0),
      lastHungerUpdate: parseDate(json['lastHungerUpdate']),
      hungerDecayHours: (json['hungerDecayHours'] as num?)?.toDouble() ?? 6.0,
      hungerRestoreAmount:
          (json['hungerRestoreAmount'] as num?)?.toDouble() ?? 20.0,
      totalFeedings: json['totalFeedings'] as int? ?? 0,
      lastTaskGenerationDate: json['lastTaskGenerationDate'] as String?,
      dailyTasks: parseTasks(json['dailyTasks']),
      dailyTaskCompletionState: parseCountMap(json['dailyTaskCompletionState']),
      claimedDailyRewards: parseStringList(json['claimedDailyRewards']),
      weeklyTaskState: parseGenericMap(json['weeklyTaskState']),
      // Body Condition & Feeding Intake (safe fallback migration)
      bodyCondition: parseBodyCondition(json['bodyCondition']),
      bodyConditionScore: rawScore.clamp(0.0, 100.0),
      feedingIntakeHistory: parseFeedingHistory(json['feedingIntakeHistory']),
      lastBodyConditionUpdate: parseDate(json['lastBodyConditionUpdate']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PetPreferences.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return PetPreferences.fromJson(decoded);
      }
    } catch (_) {}
    return const PetPreferences();
  }
}
