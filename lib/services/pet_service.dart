import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';
import '../models/pet_models.dart';
import 'hive_service.dart';
import 'pet_audio_service.dart';
import 'pet_body_condition_service.dart';
import 'timetable_calculation_service.dart';

class BirthdayReferenceIntent {
  const BirthdayReferenceIntent({
    required this.isUserBirthdayMention,
    required this.isToday,
    required this.isTomorrow,
    required this.isComingUp,
    this.daysAway,
  });

  final bool isUserBirthdayMention;
  final bool isToday;
  final bool isTomorrow;
  final bool isComingUp;
  final int? daysAway;
}

class PetService {
  static final PetService instance = PetService._internal();
  PetService._internal();

  final HiveService _hive = HiveService.instance;
  final Random _random = Random();

  final ValueNotifier<PetState> stateNotifier = ValueNotifier<PetState>(
    PetState.idle,
  );
  final ValueNotifier<PetMood> moodNotifier = ValueNotifier<PetMood>(
    PetMood.neutral,
  );
  final ValueNotifier<PetPreferences> preferencesNotifier =
      ValueNotifier<PetPreferences>(const PetPreferences());
  final ValueNotifier<String> speechNotifier = ValueNotifier<String>('');
  final ValueNotifier<PetLookDirection> lookDirectionNotifier =
      ValueNotifier<PetLookDirection>(PetLookDirection.center);
  final ValueNotifier<double> horizontalWalkPositionNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<int> effectTriggerNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> hasBackpackNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasBirthdayTodayNotifier = ValueNotifier<bool>(
    false,
  );

  Timer? _idleTimer;
  Timer? _speechClearTimer;
  Timer? _reactionResetTimer;
  Timer? _sleepCheckTimer;
  Timer? _feedingNoticeTimer;
  Timer? _eatingTimer;

  DateTime _lastInteractionTime = DateTime.now();
  final Set<String> _recentlyCompletedReminderIds = {};
  final Set<String> _recentlyPaidBillIds = {};
  final Set<String> _warnedReminderIds = {};
  final Set<String> _warnedBillIds = {};
  final Set<String> _celebratedBirthdayDays = {};
  DateTime? _lastProactiveCheck;
  DateTime? _lastHungerSpokenTime;
  bool _initialized = false;
  bool _isSuspended = false;
  bool _isClassHappening = false;
  bool _isClassUpcoming = false;
  bool _isStudyTimerRunning = false;

  PetState get currentState => stateNotifier.value;
  PetMood get currentMood => moodNotifier.value;
  PetPreferences get preferences => preferencesNotifier.value;
  bool get isEnabled => preferences.enabled;
  bool get isClassHappening => _isClassHappening;
  bool get isClassUpcoming => _isClassUpcoming;
  bool get isStudyTimerRunning => _isStudyTimerRunning;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _hive.ensureInitialized();
      var prefs = _hive.getPetPreferences();

      // Ensure lastHungerUpdate & lastBodyConditionUpdate are set
      final now = DateTime.now();
      if (prefs.lastHungerUpdate == null) {
        prefs = prefs.copyWith(lastHungerUpdate: now);
      }
      if (prefs.lastBodyConditionUpdate == null) {
        prefs = prefs.copyWith(lastBodyConditionUpdate: now);
      }

      preferencesNotifier.value = prefs;
      _lastInteractionTime = prefs.lastInteractionTime ?? now;

      // Calculate offline hunger drain, body condition, and check daily tasks
      updateHungerDecay(currentTime: now);
      updateBodyConditionDecay(currentTime: now);
      checkDailyTaskReset(currentTime: now);
    } catch (_) {}
    _initialized = true;

    _evaluateCircadianCycle();
    _startIdleLoop();
  }

  void suspend() {
    _isSuspended = true;
    _idleTimer?.cancel();
    _sleepCheckTimer?.cancel();
  }

  void resume() {
    _isSuspended = false;
    final now = DateTime.now();
    updateHungerDecay(currentTime: now);
    updateBodyConditionDecay(currentTime: now);
    checkDailyTaskReset(currentTime: now);
    _evaluateCircadianCycle();
    _startIdleLoop();
  }

  // --- Hunger Decay & Offline Time Handling ---

  /// Calculates hunger decay based on elapsed local device time since lastHungerUpdate.
  /// Battery-efficient: does not run continuous aggressive background timers.
  /// Natural randomized metabolism: decay varies dynamically between Gentle (~10-12h),
  /// Normal (~5-7h), and Brisk (~3-4.5h), influenced by circadian rhythm and random variance.
  void updateHungerDecay({DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final prefs = preferences;

    final lastUpdate = prefs.lastHungerUpdate ?? now;
    final elapsedSeconds = now.difference(lastUpdate).inSeconds;

    if (elapsedSeconds <= 0) return;

    // Natural randomized metabolic decay rate:
    // Shifts between Gentle (~10-12h), Normal (~5-7h), and Brisk (~3-4.5h)
    final hour = now.hour;
    final isNight = hour >= 22 || hour < 7;
    final randomVariance = (_random.nextDouble() * 2.0) - 1.0; // -1.0 to 1.0

    final double decayHours;
    if (isNight) {
      // Gentle rhythm during rest/sleep
      decayHours = 10.5 + (randomVariance * 1.5); // ~9.0 to 12.0 hours
    } else {
      // Dynamic daytime variation: shifts between brisk (~3.5h), normal (~5.5h), and gentle (~7.5h)
      decayHours = 5.5 + (randomVariance * 2.0); // ~3.5 to 7.5 hours
    }

    final decayPerSecond = 10.0 / (decayHours * 3600.0);
    final decayAmount = elapsedSeconds * decayPerSecond;

    final updatedHunger = (prefs.hunger - decayAmount).clamp(0.0, 100.0);

    // Save updated hunger and timestamp
    final updatedPrefs = prefs.copyWith(
      hunger: updatedHunger,
      lastHungerUpdate: now,
    );
    _updatePreferences(updatedPrefs);
  }

  // --- Body Condition & Offline Time Handling ---

  /// Evaluates offline elapsed time and updates body condition score and condition state.
  void updateBodyConditionDecay({DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final prefs = preferences;
    final updatedPrefs = PetBodyConditionService.instance
        .updateConditionForElapsedTime(prefs, currentTime: now);
    if (updatedPrefs.bodyConditionScore != prefs.bodyConditionScore ||
        updatedPrefs.bodyCondition != prefs.bodyCondition ||
        updatedPrefs.lastBodyConditionUpdate != prefs.lastBodyConditionUpdate) {
      final feedback = PetBodyConditionService.instance
          .getConditionChangeFeedback(
            prefs.bodyCondition,
            updatedPrefs.bodyCondition,
          );
      _updatePreferences(updatedPrefs);
      if (feedback != null && feedback.isNotEmpty) {
        _setSpeech(feedback, duration: const Duration(seconds: 4));
      }
    }
  }

  // --- Feeding & XP Progression ---

  /// Feeds the Kitty consuming exactly 1 food.
  /// Awards exactly +5 XP and restores a naturally randomized amount of hunger
  /// (shifts between gentle ~18-20%, normal ~22-25%, and hearty/brisk ~26-30% satiety gain).
  /// Records feeding intake and updates rolling body condition.
  Future<bool> feedKitty() async {
    if (!isEnabled) return false;
    final prefs = preferences;

    if (prefs.foodInventory <= 0) {
      _setSpeech(
        'No food right now! Complete tasks to earn food',
        duration: const Duration(seconds: 3),
      );
      return false;
    }

    _lastInteractionTime = DateTime.now();

    // 1. Consume food & restore randomized hunger & add +5 XP
    // Natural randomized satiety gain: 18.0% to 30.0% per meal
    final restoreAmount = 18.0 + (_random.nextDouble() * 12.0);
    final newFood = prefs.foodInventory - 1;
    final newHunger = (prefs.hunger + restoreAmount).clamp(0.0, 100.0);
    const xpGain = PetProgressionConfig.xpPerFood; // Strictly +5 XP

    var newCurrentXp = prefs.currentXp + xpGain;
    var newTotalXp = prefs.totalXp + xpGain;
    var newLevel = prefs.petLevel;
    var didLevelUp = false;

    // Check level up (Max Level = 10)
    while (newLevel < PetProgressionConfig.maxLevel) {
      final requiredXp = PetProgressionConfig.getXpRequiredForLevel(newLevel);
      if (newCurrentXp >= requiredXp) {
        newCurrentXp -= requiredXp;
        newLevel++;
        didLevelUp = true;
      } else {
        break;
      }
    }

    if (newLevel >= PetProgressionConfig.maxLevel) {
      newLevel = PetProgressionConfig.maxLevel;
    }

    final feedingTime = DateTime.now();
    final interimPrefs = prefs.copyWith(
      foodInventory: newFood,
      hunger: newHunger,
      lastHungerUpdate: feedingTime,
      currentXp: newCurrentXp,
      totalXp: newTotalXp,
      petLevel: newLevel,
      totalFeedings: prefs.totalFeedings + 1,
      totalInteractions: prefs.totalInteractions + 1,
    );

    // 2. Process Feeding Intake and update rolling history and body condition
    final updatedPrefs = PetBodyConditionService.instance.processFeeding(
      interimPrefs,
      feedingTime: feedingTime,
    );

    final conditionFeedback = PetBodyConditionService.instance
        .getConditionChangeFeedback(
          prefs.bodyCondition,
          updatedPrefs.bodyCondition,
        );

    // Save preferences immediately so state, intake history, and progress persist
    await _updatePreferences(updatedPrefs);

    // Clear any previous transition timers
    _eatingTimer?.cancel();
    _reactionResetTimer?.cancel();

    // 3. Play Eating Animation sequence
    lookDirectionNotifier.value = PetLookDirection.down;
    stateNotifier.value = PetState.eating;
    moodNotifier.value = PetMood.happy;
    effectTriggerNotifier.value++;

    if (prefs.soundEnabled) {
      PetAudioService.instance.playPurr();
    }

    final eatingMoodText = prefs.hunger < 20.0
        ? 'Munch munch... So relieved and happy to eat!'
        : (prefs.hunger < 50.0
              ? 'Nom nom nom... Eating joyfully!'
              : 'Crunch crunch... Feeling cheerful & energized!');

    _setSpeech(
      '$eatingMoodText (+$xpGain XP)',
      duration: const Duration(milliseconds: 1400),
    );

    // After Eating -> Happy Animation or Level Up Celebration
    _eatingTimer = Timer(const Duration(milliseconds: 1400), () {
      if (didLevelUp) {
        // LEVEL UP -> Growth Animation & Celebration
        stateNotifier.value = PetState.celebrating;
        moodNotifier.value = PetMood.excited;
        effectTriggerNotifier.value++;

        if (preferences.soundEnabled) {
          PetAudioService.instance.playMeow();
        }

        _setSpeech(
          'LEVEL UP! Now Level $newLevel (${updatedPrefs.growthStage.displayName})! Mood: Thrilled & Excited!',
          duration: const Duration(seconds: 4),
        );
        _scheduleReturnToIdle(delay: const Duration(milliseconds: 3400));
      } else {
        // Happy Animation -> Return to Idle
        stateNotifier.value = PetState.happy;
        moodNotifier.value = PetMood.happy;
        effectTriggerNotifier.value++;
        if (preferences.soundEnabled) {
          PetAudioService.instance.playPurr();
        }
        if (conditionFeedback != null && conditionFeedback.isNotEmpty) {
          _setSpeech(
            '$conditionFeedback • Mood: Happy & Content',
            duration: const Duration(seconds: 4),
          );
        } else {
          _setSpeech(
            'Yum! Tummy satisfied • Mood: Happy & Content',
            duration: const Duration(milliseconds: 2000),
          );
        }
        _scheduleReturnToIdle(delay: const Duration(milliseconds: 2000));
      }
    });

    return true;
  }

  // --- Daily Task Management ---

  void checkDailyTaskReset({DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = preferences;

    const validTaskIds = {
      'school_schedule',
      'school_class',
      'school_all',
      'study_25',
      'study_2_sessions',
      'bills_check',
      'bills_paid',
      'bills_early',
      'pet_attention',
    };

    final hasLegacyTasks = prefs.dailyTasks.any(
      (t) => !validTaskIds.contains(t.id),
    );

    final isSameDay = prefs.lastTaskGenerationDate == todayKey;
    if (!isSameDay ||
        prefs.dailyTasks.isEmpty ||
        prefs.dailyTasks.length != 3 ||
        hasLegacyTasks) {
      final preserveToday =
          isSameDay && !hasLegacyTasks && prefs.dailyTasks.isNotEmpty;
      final completedUnclaimed = preserveToday
          ? prefs.dailyTasks
                .where((task) => task.isCompleted && !task.isClaimed)
                .toList()
          : <PetDailyTask>[];
      final selectedTasks = <PetDailyTask>[...completedUnclaimed.take(3)];
      final previousTasks = {
        for (final task in prefs.dailyTasks) task.id: task,
      };
      for (final candidate in _generateDailyTasks(currentTime: now)) {
        if (selectedTasks.length >= 3) break;
        if (selectedTasks.any((task) => task.id == candidate.id)) continue;
        final previous = previousTasks[candidate.id];
        selectedTasks.add(
          candidate.copyWith(
            currentCount: previous?.currentCount ?? candidate.currentCount,
            isClaimed:
                previous?.isClaimed ??
                prefs.claimedDailyRewards.contains(candidate.id),
          ),
        );
      }

      final selectedIds = selectedTasks.map((task) => task.id).toSet();
      final claimedRewards = preserveToday
          ? List<String>.from(prefs.claimedDailyRewards)
          : hasLegacyTasks && isSameDay
          ? prefs.claimedDailyRewards.where(validTaskIds.contains).toList()
          : <String>[];
      var foodFromMigratedCompletions = 0;
      for (final task in completedUnclaimed.skip(3)) {
        if (!claimedRewards.contains(task.id)) {
          claimedRewards.add(task.id);
          foodFromMigratedCompletions += task.foodReward;
        }
      }

      final completionState = <String, int>{
        for (final entry in prefs.dailyTaskCompletionState.entries)
          if (selectedIds.contains(entry.key)) entry.key: entry.value,
      };
      for (final task in selectedTasks) {
        if (task.currentCount > 0) {
          completionState[task.id] = task.currentCount;
        }
      }

      _updatePreferences(
        prefs.copyWith(
          lastTaskGenerationDate: todayKey,
          dailyTasks: selectedTasks,
          dailyTaskCompletionState: completionState,
          claimedDailyRewards: claimedRewards,
          foodInventory: prefs.foodInventory + foodFromMigratedCompletions,
        ),
      );
    }
  }

  List<PetDailyTask> _generateDailyTasks({DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classes = _hive.getSchoolClasses();
    final hasClassesToday = classes.any(
      (item) => item.occursOnDay(now.weekday),
    );
    final bills = _hive.getBills();
    final hasBills = bills.isNotEmpty;
    final hasUnpaidBills = bills.any((bill) => !bill.paid);
    final hasUpcomingUnpaidBills = bills.any((bill) {
      final dueDate = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      return !bill.paid && dueDate.isAfter(today);
    });

    final tasks = <PetDailyTask>[
      // School
      PetDailyTask(
        id: 'school_schedule',
        title: "Check today's school schedule",
        category: 'School',
        foodReward: 1,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'school_class',
        title: 'Complete a scheduled class/task',
        category: 'School',
        foodReward: 2,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'school_all',
        title: "Complete all today's school tasks",
        category: 'School',
        foodReward: 3,
        requiredCount: 1,
      ),
      // Study
      PetDailyTask(
        id: 'study_25',
        title: 'Complete a 25-min study session',
        category: 'Study',
        foodReward: 2,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'study_2_sessions',
        title: 'Complete 2 study sessions',
        category: 'Study',
        foodReward: 3,
        requiredCount: 2,
      ),
      // Bills
      PetDailyTask(
        id: 'bills_check',
        title: 'Check upcoming bills',
        category: 'Bills',
        foodReward: 1,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'bills_paid',
        title: 'Mark a bill as paid',
        category: 'Bills',
        foodReward: 2,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'bills_early',
        title: 'Pay bill before due date',
        category: 'Bills',
        foodReward: 3,
        requiredCount: 1,
      ),
      PetDailyTask(
        id: 'pet_attention',
        title: 'Give your Kitty some attention',
        category: 'Pet',
        foodReward: 1,
        requiredCount: 1,
      ),
    ];

    final availableTasks = tasks.where((task) {
      switch (task.id) {
        case 'school_schedule':
        case 'study_25':
        case 'study_2_sessions':
        case 'pet_attention':
          return true;
        case 'school_class':
        case 'school_all':
          return hasClassesToday;
        case 'bills_check':
          return hasBills;
        case 'bills_paid':
          return hasUnpaidBills;
        case 'bills_early':
          return hasUpcomingUnpaidBills;
        default:
          return false;
      }
    }).toList();

    final dailySeed = now.year * 10000 + now.month * 100 + now.day;
    availableTasks.shuffle(Random(dailySeed));
    return availableTasks.take(3).toList();
  }

  /// Returns the three tasks selected and saved for the current day.
  List<PetDailyTask> getRelevantDailyTasks([PetPreferences? currentPrefs]) {
    final prefs = currentPrefs ?? preferences;
    return prefs.dailyTasks.take(3).toList();
  }

  /// Increments or sets progress on a specific daily task.
  Future<void> recordTaskProgress(
    String taskId, {
    int count = 1,
    bool setDirect = false,
  }) async {
    checkDailyTaskReset();
    final prefs = preferences;
    if (!prefs.dailyTasks.any((task) => task.id == taskId)) return;
    final completionMap = Map<String, int>.from(prefs.dailyTaskCompletionState);

    final currentVal = completionMap[taskId] ?? 0;
    final newVal = setDirect ? count : currentVal + count;
    completionMap[taskId] = newVal;

    final updatedTasks = prefs.dailyTasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(currentCount: newVal);
      }
      return task;
    }).toList();

    await _updatePreferences(
      prefs.copyWith(
        dailyTasks: updatedTasks,
        dailyTaskCompletionState: completionMap,
      ),
    );
  }

  /// Claims the food reward for a completed task.
  Future<bool> claimDailyTaskReward(String taskId) async {
    final prefs = preferences;
    final task = prefs.dailyTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => const PetDailyTask(
        id: '',
        title: '',
        category: '',
        foodReward: 0,
        requiredCount: 0,
      ),
    );

    if (task.id.isEmpty || !task.isCompleted || task.isClaimed) {
      return false;
    }

    final updatedClaimed = List<String>.from(prefs.claimedDailyRewards)
      ..add(taskId);
    final updatedTasks = prefs.dailyTasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(isClaimed: true);
      }
      return t;
    }).toList();

    final newFood = prefs.foodInventory + task.foodReward;

    await _updatePreferences(
      prefs.copyWith(
        foodInventory: newFood,
        claimedDailyRewards: updatedClaimed,
        dailyTasks: updatedTasks,
      ),
    );

    _setSpeech(
      '+${task.foodReward} Food earned! 🍖',
      duration: const Duration(seconds: 3),
    );

    return true;
  }

  /// Claims all unclaimed completed tasks at once.
  Future<int> claimAllCompletedRewards() async {
    final prefs = preferences;
    int totalEarned = 0;
    final updatedClaimed = List<String>.from(prefs.claimedDailyRewards);

    final updatedTasks = prefs.dailyTasks.map((t) {
      if (t.isCompleted && !t.isClaimed) {
        totalEarned += t.foodReward;
        updatedClaimed.add(t.id);
        return t.copyWith(isClaimed: true);
      }
      return t;
    }).toList();

    if (totalEarned > 0) {
      await _updatePreferences(
        prefs.copyWith(
          foodInventory: prefs.foodInventory + totalEarned,
          claimedDailyRewards: updatedClaimed,
          dailyTasks: updatedTasks,
        ),
      );
      _setSpeech(
        'Claimed +$totalEarned Food! 🍖',
        duration: const Duration(seconds: 3),
      );
    }

    return totalEarned;
  }

  // --- Idle Loop & Hunger Behavior ---

  void _startIdleLoop() {
    _idleTimer?.cancel();
    _sleepCheckTimer?.cancel();

    // Check idle actions every 4 seconds
    _idleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isSuspended || !isEnabled) return;
      _onIdleTick();
    });

    // Inactivity / sleep check every 15 seconds
    _sleepCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isSuspended || !isEnabled) return;
      _checkSleepState();
    });
  }

  void _onIdleTick() {
    // Priority system: Do not override eating, studying, celebrating, waking, or sleeping
    if (currentState != PetState.idle &&
        currentState != PetState.lookingAround &&
        currentState != PetState.blinking &&
        currentState != PetState.hungry) {
      return;
    }

    // Refresh hunger decay
    updateHungerDecay();

    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;

    if (isNight && _random.nextDouble() < 0.45) {
      _enterSleep();
      return;
    }

    final hungerState = preferences.hungerState;
    final roll = _random.nextDouble();

    // Hunger behavior reactions (Section 2 & 11)
    if (hungerState == HungerState.empty) {
      // 0% Hunger: gentle hungry reminder, never punishing
      if (roll < 0.40) {
        _triggerHungryIdle(
          'Tummy is completely empty! Feed me when you can 🐾🍖',
        );
        return;
      }
    } else if (hungerState == HungerState.veryHungry) {
      // 1-19% Hunger: worried / hungry expression
      if (roll < 0.35) {
        _triggerHungryIdle('Getting very hungry... Got a bite to eat? 🥺🍖');
        return;
      }
    } else if (hungerState == HungerState.hungry) {
      // 20-49% Hunger: occasional subtle hungry animation
      if (roll < 0.25) {
        _triggerHungryIdle('Tummy is rumbling a little... 🍖');
        return;
      }
    } else if (hungerState == HungerState.gettingHungry) {
      // 50-79% Hunger: look toward food area occasionally
      if (roll < 0.18) {
        lookDirectionNotifier.value = PetLookDirection.down;
        stateNotifier.value = PetState.lookingAround;
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (stateNotifier.value == PetState.lookingAround) {
            lookDirectionNotifier.value = PetLookDirection.center;
            stateNotifier.value = PetState.idle;
          }
        });
        return;
      }
    }

    // Normal Idle behaviors (Well Fed 80-100% or normal roll)
    if (roll < 0.28) {
      // Blink
      stateNotifier.value = PetState.blinking;
      Future.delayed(const Duration(milliseconds: 280), () {
        if (stateNotifier.value == PetState.blinking) {
          stateNotifier.value = PetState.idle;
        }
      });
    } else if (roll < 0.52) {
      // Look around
      final dir = _random.nextBool()
          ? PetLookDirection.left
          : PetLookDirection.right;
      lookDirectionNotifier.value = dir;
      stateNotifier.value = PetState.lookingAround;
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (stateNotifier.value == PetState.lookingAround) {
          lookDirectionNotifier.value = PetLookDirection.center;
          stateNotifier.value = PetState.idle;
        }
      });
    } else if (roll < 0.70 && preferences.movementEnabled) {
      // Gentle walk within safe container bounds (-0.5 to 0.5)
      final target = (_random.nextDouble() * 1.0) - 0.5;
      lookDirectionNotifier.value =
          target >= horizontalWalkPositionNotifier.value
          ? PetLookDirection.right
          : PetLookDirection.left;
      stateNotifier.value = PetState.walking;

      _animateWalkTo(
        target,
        onFinished: () {
          if (stateNotifier.value == PetState.walking) {
            lookDirectionNotifier.value = PetLookDirection.center;
            stateNotifier.value = PetState.idle;
          }
        },
      );
    } else if (roll < 0.85) {
      // Gentle ear twitch / subtle tail movement
      stateNotifier.value = PetState.idle;
      effectTriggerNotifier.value++;
    }
  }

  void _triggerHungryIdle(String speechText) {
    stateNotifier.value = PetState.hungry;
    lookDirectionNotifier.value = PetLookDirection.down;

    final now = DateTime.now();
    if (_lastHungerSpokenTime == null ||
        now.difference(_lastHungerSpokenTime!) > const Duration(minutes: 2)) {
      _lastHungerSpokenTime = now;
      _setSpeech(speechText, duration: const Duration(seconds: 3));
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (stateNotifier.value == PetState.hungry) {
        lookDirectionNotifier.value = PetLookDirection.center;
        stateNotifier.value = PetState.idle;
      }
    });
  }

  void _animateWalkTo(double target, {required VoidCallback onFinished}) {
    final start = horizontalWalkPositionNotifier.value;
    final delta = target - start;
    const steps = 15;
    var currentStep = 0;

    Timer.periodic(const Duration(milliseconds: 70), (walkTimer) {
      if (_isSuspended || stateNotifier.value != PetState.walking) {
        walkTimer.cancel();
        return;
      }
      currentStep++;
      final progress = currentStep / steps;
      final eased = sin((progress * pi) / 2);
      horizontalWalkPositionNotifier.value = start + (delta * eased);

      if (currentStep >= steps) {
        walkTimer.cancel();
        onFinished();
      }
    });
  }

  void _checkSleepState() {
    if (currentState == PetState.sleeping ||
        currentState == PetState.studying ||
        currentState == PetState.celebrating ||
        currentState == PetState.eating) {
      return;
    }

    final idleDuration = DateTime.now().difference(_lastInteractionTime);
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;

    final sleepThreshold = isNight
        ? const Duration(seconds: 40)
        : const Duration(seconds: 90);

    if (idleDuration >= sleepThreshold) {
      _enterSleep();
    }
  }

  void _enterSleep() {
    if (currentState == PetState.sleeping ||
        currentState == PetState.studying ||
        currentState == PetState.eating) {
      return;
    }
    stateNotifier.value = PetState.sleeping;
    moodNotifier.value = PetMood.sleepy;
    _setSpeech('Zzz...', duration: const Duration(seconds: 4));
  }

  void _evaluateCircadianCycle() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      if (currentState != PetState.studying) {
        moodNotifier.value = PetMood.happy;
      }
    } else if (hour >= 22 || hour < 6) {
      moodNotifier.value = PetMood.sleepy;
    } else {
      if (currentState != PetState.studying &&
          currentState != PetState.celebrating) {
        moodNotifier.value = PetMood.neutral;
      }
    }
  }

  // --- User Gestures ---

  void onTap() {
    if (!isEnabled) return;
    recordTaskProgress('pet_attention', count: 1, setDirect: true);
    _lastInteractionTime = DateTime.now();

    if (currentState == PetState.sleeping) {
      stateNotifier.value = PetState.waking;
      _setSpeech(
        'Yawn... Good to see you! ☀️',
        duration: const Duration(seconds: 3),
      );
      _scheduleReturnToIdle(delay: const Duration(milliseconds: 1400));
      _incrementInteraction();
      return;
    }

    final roll = _random.nextDouble();
    if (roll < 0.4) {
      stateNotifier.value = PetState.happy;
      moodNotifier.value = PetMood.happy;
      _setSpeech('Purrr! 🐾', duration: const Duration(seconds: 2));
      effectTriggerNotifier.value++;
      if (preferences.soundEnabled) {
        PetAudioService.instance.playPurr();
      }
    } else if (roll < 0.75) {
      stateNotifier.value = PetState.surprised;
      _setSpeech('Meow! ✨', duration: const Duration(seconds: 2));
      if (preferences.soundEnabled) {
        PetAudioService.instance.playMeow();
      }
    } else {
      stateNotifier.value = PetState.lookingAround;
      lookDirectionNotifier.value = PetLookDirection.up;
      _setSpeech(
        "Let's get things done! 💪",
        duration: const Duration(seconds: 2),
      );
      if (preferences.soundEnabled) {
        PetAudioService.instance.playMeow();
      }
    }

    _incrementInteraction();
    _scheduleReturnToIdle(delay: const Duration(milliseconds: 1800));
  }

  void onPetSwipe() {
    if (!isEnabled) return;
    recordTaskProgress('pet_attention', count: 1, setDirect: true);
    _lastInteractionTime = DateTime.now();

    stateNotifier.value = PetState.beingPetted;
    moodNotifier.value = PetMood.happy;
    effectTriggerNotifier.value++;

    if (preferences.soundEnabled) {
      PetAudioService.instance.playPurr();
    }

    final petPhrases = [
      'Purrrrrr~ ❤️',
      'Soft head pats! ✨',
      'Purr purr~ 🐾',
      'So comfy! ❤️',
    ];
    _setSpeech(
      petPhrases[_random.nextInt(petPhrases.length)],
      duration: const Duration(seconds: 3),
    );

    _incrementPetCount();

    _reactionResetTimer?.cancel();
    _reactionResetTimer = Timer(const Duration(milliseconds: 2200), () {
      stateNotifier.value = PetState.happy;
      _scheduleReturnToIdle(delay: const Duration(milliseconds: 1200));
    });
  }

  // --- System Event Integrations ---

  void onReminderCompleted(
    Reminder reminder, {
    int todayTotalCompleted = 1,
    bool allDueCompleted = false,
  }) {
    if (!isEnabled) return;

    if (_recentlyCompletedReminderIds.contains(reminder.id)) {
      return;
    }
    _recentlyCompletedReminderIds.add(reminder.id);
    Timer(const Duration(seconds: 15), () {
      _recentlyCompletedReminderIds.remove(reminder.id);
    });

    _lastInteractionTime = DateTime.now();
    stateNotifier.value = PetState.celebrating;
    moodNotifier.value = PetMood.excited;
    effectTriggerNotifier.value++;

    if (preferences.soundEnabled) {
      PetAudioService.instance.playMeow();
    }

    final celebratoryPhrases = [
      'Task complete! Awesome work! 🎉',
      'High paw! One step closer! 🐾',
      'You crushed that reminder! 🌟',
      'Way to go! Proud of you! 🎉',
    ];
    _setSpeech(
      celebratoryPhrases[_random.nextInt(celebratoryPhrases.length)],
      duration: const Duration(seconds: 4),
    );

    // Productivity tasks tracking
    recordTaskProgress('rem_1', count: 1);
    recordTaskProgress('rem_3', count: 1);
    recordTaskProgress('rem_5', count: 1);
    if (reminder.priority.toLowerCase() == 'high' ||
        reminder.priority.toLowerCase() == 'medium') {
      recordTaskProgress('rem_priority', count: 1);
    }
    if (allDueCompleted) {
      recordTaskProgress('rem_all_due', count: 1, setDirect: true);
    } else {
      try {
        final now = DateTime.now();
        final dueToday = _hive
            .getReminders()
            .where(
              (r) =>
                  r.date.year == now.year &&
                  r.date.month == now.month &&
                  r.date.day == now.day,
            )
            .toList();
        if (dueToday.isNotEmpty &&
            dueToday.every((r) => r.completed || r.id == reminder.id)) {
          recordTaskProgress('rem_all_due', count: 1, setDirect: true);
        }
      } catch (_) {}
    }

    _updatePreferences(
      preferences.copyWith(tasksCelebrated: preferences.tasksCelebrated + 1),
    );

    _scheduleReturnToIdle(delay: const Duration(milliseconds: 3200));
  }

  void onReminderDue(Reminder reminder) {
    if (!isEnabled ||
        currentState == PetState.celebrating ||
        currentState == PetState.eating) {
      return;
    }

    stateNotifier.value = PetState.worried;
    moodNotifier.value = PetMood.focused;
    _setSpeech(
      'Reminder: "${reminder.title}" is due! ⏰',
      duration: const Duration(seconds: 3),
    );
    _scheduleReturnToIdle(delay: const Duration(milliseconds: 2500));
  }

  void onBillPaid(Bill bill, {bool? paidBeforeDueDate}) {
    if (!isEnabled) return;

    if (_recentlyPaidBillIds.contains(bill.id)) {
      return;
    }
    _recentlyPaidBillIds.add(bill.id);
    Timer(const Duration(seconds: 15), () {
      _recentlyPaidBillIds.remove(bill.id);
    });

    _lastInteractionTime = DateTime.now();
    stateNotifier.value = PetState.happy;
    moodNotifier.value = PetMood.happy;
    effectTriggerNotifier.value++;

    if (preferences.soundEnabled) {
      PetAudioService.instance.playPurr();
    }

    _setSpeech(
      '${bill.name} paid! Weight off our shoulders! 💸',
      duration: const Duration(seconds: 4),
    );

    // Productivity tasks tracking
    recordTaskProgress('bills_paid', count: 1);
    if (paidBeforeDueDate ?? _isDueDateAfterToday(bill.dueDate)) {
      recordTaskProgress('bills_early', count: 1);
    }

    _scheduleReturnToIdle(delay: const Duration(milliseconds: 2800));
  }

  bool _isDueDateAfterToday(DateTime dueDate) {
    final today = DateTime.now();
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).isAfter(DateTime(today.year, today.month, today.day));
  }

  void onBillApproachingDue(Bill bill) {
    if (!isEnabled ||
        currentState == PetState.celebrating ||
        currentState == PetState.studying ||
        currentState == PetState.eating) {
      return;
    }

    stateNotifier.value = PetState.worried;
    moodNotifier.value = PetMood.worried;
    _setSpeech(
      'Bill due soon: ${bill.name}! ⚠️',
      duration: const Duration(seconds: 3),
    );
    _scheduleReturnToIdle(delay: const Duration(milliseconds: 2500));
  }

  void onBillsChecked() {
    recordTaskProgress('bills_check', count: 1);
  }

  void onScheduleChecked({bool isTomorrow = false}) {
    if (!isTomorrow) {
      {
        recordTaskProgress('school_schedule', count: 1, setDirect: true);
      }
    }
  }

  void onClassStatusChanged({
    required bool isClassHappening,
    required bool isClassUpcoming,
    String? className,
  }) {
    if (!isEnabled) return;

    _isClassHappening = isClassHappening;
    _isClassUpcoming = isClassUpcoming;
    hasBackpackNotifier.value = isClassHappening || isClassUpcoming;

    if (isClassHappening) {
      if (currentState != PetState.studying &&
          currentState != PetState.eating) {
        stateNotifier.value = PetState.studying;
        moodNotifier.value = PetMood.focused;
        _setSpeech(
          className != null ? 'Class time: $className!' : 'In class right now!',
          duration: const Duration(seconds: 4),
        );
      }
    } else if (isClassUpcoming) {
      if (!_isStudyTimerRunning &&
          currentState != PetState.studying &&
          currentState != PetState.celebrating &&
          currentState != PetState.eating) {
        stateNotifier.value = PetState.worried;
        moodNotifier.value = PetMood.focused;
        _setSpeech(
          className != null
              ? 'Upcoming class: $className!'
              : 'Class starting soon!',
          duration: const Duration(seconds: 3),
        );
        _scheduleReturnToIdle(delay: const Duration(milliseconds: 2500));
      }
    } else {
      if (!_isStudyTimerRunning && currentState == PetState.studying) {
        stateNotifier.value = PetState.idle;
        moodNotifier.value = PetMood.neutral;
        _setSpeech(
          'Class finished! Great job!',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  BirthdayReferenceIntent? parseBirthdayReference(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    final normalized = text
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;

    final hasBirthdayWord = RegExp(
      r'\b(?:birthday|bday|birth day)\b',
    ).hasMatch(normalized);
    if (!hasBirthdayWord) return null;

    final hasUserCue =
        RegExp(r"\b(?:my|mine|me)\b").hasMatch(normalized) ||
        normalized.contains('it s my') ||
        normalized.contains('it is my') ||
        normalized.contains('today is my') ||
        normalized.contains('today s my') ||
        normalized.contains('tomorrow is my') ||
        normalized.contains('i m ') ||
        normalized.contains('im ');

    final explicitUserBirthday =
        hasUserCue &&
        (normalized.contains('my birthday') ||
            normalized.contains('my bday') ||
            normalized.contains('my birth day') ||
            normalized.contains('it s my') ||
            normalized.contains('it is my') ||
            normalized.contains('today is my') ||
            normalized.contains('today s my') ||
            normalized.contains('tomorrow is my')) &&
        !normalized.contains("my friend's birthday") &&
        !normalized.contains("my friend's bday") &&
        !normalized.contains("my friend's birth day");

    if (!explicitUserBirthday && !hasBirthdayWord) {
      return null;
    }

    final normalizedDate = normalized;
    final isToday = normalizedDate.contains('today');
    final isTomorrow = normalizedDate.contains('tomorrow');
    final isComingUp =
        normalizedDate.contains('coming up') ||
        normalizedDate.contains('coming soon');

    int? daysAway;
    final match = RegExp(r'\bin\s+(\d+)\s+days?\b').firstMatch(normalizedDate);
    if (match != null) {
      daysAway = int.tryParse(match.group(1) ?? '') ?? 0;
    }

    return BirthdayReferenceIntent(
      isUserBirthdayMention: explicitUserBirthday,
      isToday: isToday,
      isTomorrow: isTomorrow,
      isComingUp: isComingUp || daysAway != null,
      daysAway: daysAway,
    );
  }

  bool respondToBirthdayText(String text, {List<Birthday>? birthdays}) {
    final intent = parseBirthdayReference(text);
    if (intent == null) return false;

    final allBirthdays = birthdays ?? _hive.getBirthdays();
    final userBirthday = Birthday.findUserBirthday(allBirthdays);
    final now = DateTime.now();
    final userBirthdayDiff = userBirthday?.daysUntilNextFor(now);

    if (intent.isUserBirthdayMention) {
      if (userBirthday == null) {
        _setSpeech(
          "🎂 Happy Birthday!\nI don't have your birthday saved yet.\nWould you like to add it to Reminder Hub?",
          duration: const Duration(seconds: 5),
        );
        return true;
      }

      if (userBirthdayDiff == 0) {
        final key = 'user_birthday_${now.year}_${now.month}_${now.day}';
        if (!_celebratedBirthdayDays.contains(key)) {
          _celebratedBirthdayDays.add(key);
          stateNotifier.value = PetState.celebrating;
          moodNotifier.value = PetMood.excited;
          effectTriggerNotifier.value++;
          if (preferences.soundEnabled) {
            PetAudioService.instance.playMeow();
          }
          _setSpeech(
            "🎂 HAPPY BIRTHDAY!\nIt's your special day! Let's celebrate! 🎉",
            duration: const Duration(seconds: 4),
          );
          _scheduleReturnToIdle(delay: const Duration(milliseconds: 3500));
        }
        return true;
      }

      if (intent.isTomorrow && userBirthdayDiff == 1) {
        _setSpeech(
          "🎉 Your birthday is tomorrow!\nAre you ready to celebrate?",
          duration: const Duration(seconds: 4),
        );
        return true;
      }

      if ((intent.isComingUp || intent.daysAway != null) &&
          userBirthdayDiff != null &&
          userBirthdayDiff == (intent.daysAway ?? userBirthdayDiff)) {
        _setSpeech(
          "🎂 Your birthday is coming up in $userBirthdayDiff days!\nThe countdown begins!",
          duration: const Duration(seconds: 4),
        );
        return true;
      }
    }

    return false;
  }

  void refreshBirthdayAppearance({
    List<Birthday>? birthdays,
    DateTime? currentTime,
  }) {
    final referenceDate = currentTime ?? DateTime.now();
    final birthdayList = birthdays ?? _hive.getBirthdays();
    hasBirthdayTodayNotifier.value = birthdayList.any(
      (birthday) => birthday.daysUntilNextFor(referenceDate) == 0,
    );
  }

  void checkUpcomingEvents({
    List<Reminder>? reminders,
    List<Bill>? bills,
    List<SchoolClass>? schoolClasses,
    List<Birthday>? birthdays,
    DateTime? currentTime,
  }) {
    if (!isEnabled) return;
    final now = currentTime ?? DateTime.now();
    checkDailyTaskReset(currentTime: now);
    refreshBirthdayAppearance(birthdays: birthdays, currentTime: now);

    // Check school classes timetable status proactively so backpack & study notebook activate
    try {
      final classes = schoolClasses ?? _hive.getSchoolClasses();
      if (classes.isNotEmpty) {
        final dayStatus = TimetableCalculationService.instance
            .calculateDayStatus(classes, now);
        final hasActive = dayStatus.currentClasses.isNotEmpty;
        final hasNext = dayStatus.nextClass != null;
        if (dayStatus.classes.any(
          (classStatus) => classStatus.status == ClassState.completed,
        )) {
          recordTaskProgress('school_class', count: 1, setDirect: true);
        }
        if (dayStatus.classes.isNotEmpty && dayStatus.hasNoMoreClasses) {
          recordTaskProgress('school_all', count: 1, setDirect: true);
        }
        final currentName =
            dayStatus.currentClasses.firstOrNull?.schoolClass.subject;
        final nextName = dayStatus.nextClass?.schoolClass.subject;
        if (hasActive || hasNext) {
          onClassStatusChanged(
            isClassHappening: hasActive,
            isClassUpcoming: hasNext,
            className: currentName ?? nextName,
          );
        } else {
          onClassStatusChanged(isClassHappening: false, isClassUpcoming: false);
        }
      }
    } catch (_) {}

    if (_lastProactiveCheck != null &&
        now.difference(_lastProactiveCheck!) < const Duration(minutes: 5)) {
      return;
    }
    _lastProactiveCheck = now;

    if (reminders != null) {
      for (final r in reminders) {
        if (r.completed) continue;
        if (_warnedReminderIds.contains(r.id)) continue;

        if (r.date.year == now.year &&
            r.date.month == now.month &&
            r.date.day == now.day) {
          _warnedReminderIds.add(r.id);
          onReminderDue(r);
          return;
        }
      }
    }

    if (bills != null) {
      for (final b in bills) {
        if (b.paid) continue;
        if (_warnedBillIds.contains(b.id)) continue;

        final diff = b.dueDate.difference(now).inDays;
        if (diff >= 0 && diff <= 2) {
          _warnedBillIds.add(b.id);
          onBillApproachingDue(b);
          return;
        }
      }
    }

    if (birthdays != null) {
      final userBirthday = Birthday.findUserBirthday(birthdays);
      if (userBirthday != null && userBirthday.daysUntilNextFor(now) == 0) {
        final key = 'user_birthday_${now.year}_${now.month}_${now.day}';
        if (!_celebratedBirthdayDays.contains(key)) {
          _celebratedBirthdayDays.add(key);
          stateNotifier.value = PetState.celebrating;
          moodNotifier.value = PetMood.excited;
          effectTriggerNotifier.value++;
          if (preferences.soundEnabled) {
            PetAudioService.instance.playMeow();
          }
          _setSpeech(
            "🎂 Happy Birthday!\nIt's YOUR birthday today!\nLet's celebrate!",
            duration: const Duration(seconds: 4),
          );
          _scheduleReturnToIdle(delay: const Duration(milliseconds: 3500));
        }
        return;
      }

      final todaysBirthdays = birthdays
          .where((birthday) => birthday.daysUntilNext == 0)
          .toList();
      if (todaysBirthdays.isNotEmpty) {
        final key = 'birthday_${now.year}_${now.month}_${now.day}';
        if (!_celebratedBirthdayDays.contains(key)) {
          _celebratedBirthdayDays.add(key);
          final names = todaysBirthdays
              .map((birthday) => birthday.name)
              .toList();
          final birthdayText = names.length == 1
              ? "🎂 It's ${names.first}'s birthday today!"
              : "🎂 It's ${names.take(names.length - 1).join(', ')} and ${names.last}'s birthday today!";
          stateNotifier.value = PetState.celebrating;
          moodNotifier.value = PetMood.excited;
          effectTriggerNotifier.value++;
          _setSpeech(
            '$birthdayText\nLet\'s celebrate!',
            duration: const Duration(seconds: 4),
          );
          _scheduleReturnToIdle(delay: const Duration(milliseconds: 3500));
        }
      }
    }
  }

  void onStudyTimerUpdated({
    required bool isRunning,
    required bool isBreak,
    required bool isCompleted,
    String? subject,
    int durationMinutes = 25,
  }) {
    if (!isEnabled) return;

    _isStudyTimerRunning = isRunning && !isBreak && !isCompleted;

    if (isCompleted) {
      stateNotifier.value = PetState.celebrating;
      moodNotifier.value = PetMood.excited;
      effectTriggerNotifier.value++;

      if (preferences.soundEnabled) {
        PetAudioService.instance.playMeow();
      }

      _setSpeech(
        'Focus session complete! Proud of you!',
        duration: const Duration(seconds: 4),
      );

      // Study productivity tasks tracking
      if (durationMinutes >= 25) {
        recordTaskProgress('study_25', count: 1);
      }
      recordTaskProgress('study_2_sessions', count: 1);

      _updatePreferences(
        preferences.copyWith(
          studySessionsAccompanied: preferences.studySessionsAccompanied + 1,
        ),
      );

      _scheduleReturnToIdle(delay: const Duration(milliseconds: 3500));
    } else if (isRunning) {
      if (isBreak) {
        if (!_isClassHappening) {
          stateNotifier.value = PetState.idle;
          moodNotifier.value = PetMood.neutral;
        }
        _setSpeech(
          'Break time! Stretch and sip water~',
          duration: const Duration(seconds: 3),
        );
      } else {
        stateNotifier.value = PetState.studying;
        moodNotifier.value = PetMood.focused;
        final subText =
            (subject != null && subject.isNotEmpty && subject != 'General')
            ? subject
            : 'Study';
        _setSpeech(
          'Deep focus mode: $subText!',
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      // Only reset to idle if no school class is happening!
      if (!_isClassHappening && currentState == PetState.studying) {
        stateNotifier.value = PetState.idle;
        moodNotifier.value = PetMood.neutral;
      }
    }
  }

  // --- Helper Routines ---

  void _scheduleReturnToIdle({required Duration delay}) {
    _reactionResetTimer?.cancel();
    _reactionResetTimer = Timer(delay, () {
      if (currentState != PetState.studying &&
          !_isClassHappening &&
          !_isStudyTimerRunning) {
        stateNotifier.value = PetState.idle;
        lookDirectionNotifier.value = PetLookDirection.center;
        _evaluateCircadianCycle();
      } else if (_isClassHappening || _isStudyTimerRunning) {
        stateNotifier.value = PetState.studying;
        moodNotifier.value = PetMood.focused;
        lookDirectionNotifier.value = PetLookDirection.center;
      }
    });
  }

  void _setSpeech(String text, {required Duration duration}) {
    speechNotifier.value = text;
    _speechClearTimer?.cancel();
    _speechClearTimer = Timer(duration, () {
      speechNotifier.value = '';
    });
  }

  void speak(String text, {Duration duration = const Duration(seconds: 3)}) {
    _setSpeech(text, duration: duration);
  }

  void _incrementInteraction() {
    _updatePreferences(
      preferences.copyWith(
        totalInteractions: preferences.totalInteractions + 1,
        lastInteractionTime: DateTime.now(),
      ),
    );
  }

  void _incrementPetCount() {
    _updatePreferences(
      preferences.copyWith(
        totalPets: preferences.totalPets + 1,
        totalInteractions: preferences.totalInteractions + 1,
        lastInteractionTime: DateTime.now(),
      ),
    );
  }

  Future<void> updatePreferences(PetPreferences newPrefs) async {
    await _updatePreferences(newPrefs);
  }

  Future<void> _updatePreferences(PetPreferences newPrefs) async {
    preferencesNotifier.value = newPrefs;
    if (!newPrefs.enabled || !newPrefs.soundEnabled) {
      PetAudioService.instance.stop();
    }
    try {
      await _hive.savePetPreferences(newPrefs);
    } catch (_) {}
  }

  void cancelPendingTimers() {
    _speechClearTimer?.cancel();
    _speechClearTimer = null;
    _reactionResetTimer?.cancel();
    _reactionResetTimer = null;
    _feedingNoticeTimer?.cancel();
    _feedingNoticeTimer = null;
    _eatingTimer?.cancel();
    _eatingTimer = null;
  }

  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _speechClearTimer?.cancel();
    _speechClearTimer = null;
    _reactionResetTimer?.cancel();
    _reactionResetTimer = null;
    _sleepCheckTimer?.cancel();
    _sleepCheckTimer = null;
    _feedingNoticeTimer?.cancel();
    _feedingNoticeTimer = null;
    _eatingTimer?.cancel();
    _eatingTimer = null;
  }
}
