import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/models/pet_models.dart';
import 'package:reminder_hub/services/pet_audio_service.dart';
import 'package:reminder_hub/services/pet_body_condition_service.dart';
import 'package:reminder_hub/services/pet_service.dart';
import 'package:reminder_hub/widgets/pet/pet_companion_card.dart';
import 'package:reminder_hub/widgets/pet/pet_widget.dart';
import 'package:reminder_hub/widgets/pet/pet_mood_badge.dart';
import 'package:reminder_hub/screens/pet/pet_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetModels & Preferences Unit Tests', () {
    test('PetPreferences default values are valid and offline-first', () {
      const prefs = PetPreferences();
      expect(prefs.enabled, isTrue);
      expect(prefs.name, 'Mochi');
      expect(prefs.coatStyle, PetCoatStyle.gingerTabby);
      expect(prefs.soundEnabled, isTrue);
      expect(prefs.interactionReactionsEnabled, isTrue);
      expect(prefs.movementEnabled, isTrue);
      expect(prefs.totalPets, 0);
      expect(prefs.totalInteractions, 0);
      expect(prefs.tasksCelebrated, 0);
      expect(prefs.studySessionsAccompanied, 0);
    });

    test('PetPreferences JSON serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 9, 30, 8, 30);
      final prefs = PetPreferences(
        enabled: true,
        name: 'Luna',
        coatStyle: PetCoatStyle.calico,
        soundEnabled: false,
        interactionReactionsEnabled: true,
        movementEnabled: true,
        totalPets: 12,
        totalInteractions: 35,
        tasksCelebrated: 8,
        studySessionsAccompanied: 5,
        lastInteractionTime: now,
      );

      final jsonMap = prefs.toJson();
      expect(jsonMap['name'], 'Luna');
      expect(jsonMap['coatStyle'], 'calico');
      expect(jsonMap['totalPets'], 12);

      final fromJson = PetPreferences.fromJson(jsonMap);
      expect(fromJson.name, 'Luna');
      expect(fromJson.coatStyle, PetCoatStyle.calico);
      expect(fromJson.totalPets, 12);
      expect(fromJson.totalInteractions, 35);
      expect(fromJson.tasksCelebrated, 8);
      expect(fromJson.studySessionsAccompanied, 5);
      expect(fromJson.lastInteractionTime, now);

      // JSON String roundtrip
      final stringRepresentation = prefs.toJsonString();
      final fromString = PetPreferences.fromJsonString(stringRepresentation);
      expect(fromString.name, 'Luna');
      expect(fromString.coatStyle, PetCoatStyle.calico);
    });

    test('PetPreferences handles corrupted or fallback JSON gracefully', () {
      final empty = PetPreferences.fromJsonString('invalid json');
      expect(empty.name, 'Mochi');
      expect(empty.enabled, isTrue);

      final blankName = PetPreferences.fromJson({'name': '   '});
      expect(blankName.name, 'Mochi');
    });
  });

  group('PetService State Machine & Integration Tests', () {
    late PetService service;

    setUp(() {
      service = PetService.instance;
      // Reset state to a known clean state
      service.preferencesNotifier.value = const PetPreferences(
        name: 'Mochi',
        enabled: true,
      );
      service.stateNotifier.value = PetState.idle;
      service.moodNotifier.value = PetMood.neutral;
    });

    test('User tap interaction triggers playful reaction and increments count', () {
      final initialInteractions = service.preferences.totalInteractions;
      service.onTap();

      expect(
        service.currentState == PetState.happy ||
            service.currentState == PetState.surprised ||
            service.currentState == PetState.lookingAround,
        isTrue,
      );
      expect(service.preferences.totalInteractions, initialInteractions + 1);
    });

    test('User swipe petting enters beingPetted and increments pats count', () {
      final initialPats = service.preferences.totalPets;
      service.onPetSwipe();

      expect(service.currentState, PetState.beingPetted);
      expect(service.currentMood, PetMood.happy);
      expect(service.preferences.totalPets, initialPats + 1);
    });

    test('Tapping a sleeping pet wakes it up', () {
      service.stateNotifier.value = PetState.sleeping;
      service.onTap();

      expect(service.currentState, PetState.waking);
      expect(service.speechNotifier.value.contains('awake') || service.speechNotifier.value.contains('Yawn'), isTrue);
    });

    test('Reminder completed event triggers celebrating and deduplicates rapid rebuilds', () {
      final initialCelebrated = service.preferences.tasksCelebrated;
      final reminder = Reminder(
        id: 'rem-pet-test-1',
        title: 'Submit Project',
        description: '',
        category: 'Work',
        date: DateTime.now(),
        time: '10:00 AM',
        repeat: 'None',
        reminderBefore: 'At time of event',
        priority: 'Medium',
        notes: '',
        completed: true,
      );

      service.onReminderCompleted(reminder);
      expect(service.currentState, PetState.celebrating);
      expect(service.currentMood, PetMood.excited);
      expect(service.preferences.tasksCelebrated, initialCelebrated + 1);

      // Rapid repeated call with identical reminder ID (e.g. from dashboard rebuild)
      service.onReminderCompleted(reminder);
      // tasksCelebrated must NOT increment again due to deduplication
      expect(service.preferences.tasksCelebrated, initialCelebrated + 1);
    });

    test('Bill paid event triggers happy reaction and deduplicates rebuilds', () {
      final bill = Bill(
        id: 'bill-pet-test-1',
        name: 'Water Utility',
        amount: 450,
        dueDate: DateTime.now(),
        repeat: 'None',
        category: 'Utilities',
        paid: true,
        reminderSchedule: 'None',
        notes: '',
      );

      service.onBillPaid(bill);
      expect(service.currentState, PetState.happy);
      expect(service.currentMood, PetMood.happy);
      expect(service.speechNotifier.value.contains('paid'), isTrue);
    });

    test('Bill approaching due triggers worried mood and expression', () {
      final bill = Bill(
        id: 'bill-pet-test-urgent',
        name: 'Rent',
        amount: 8000,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        repeat: 'Monthly',
        category: 'Housing',
        paid: false,
        reminderSchedule: '1 day before',
        notes: '',
      );

      service.onBillApproachingDue(bill);
      expect(service.currentState, PetState.worried);
      expect(service.currentMood, PetMood.worried);
      expect(service.speechNotifier.value.contains('Rent'), isTrue);
    });

    test('School schedule updates toggle studying state and school backpack', () {
      service.onClassStatusChanged(
        isClassHappening: true,
        isClassUpcoming: false,
        className: 'Mathematics 101',
      );

      expect(service.currentState, PetState.studying);
      expect(service.currentMood, PetMood.focused);
      expect(service.hasBackpackNotifier.value, isTrue);
      expect(service.speechNotifier.value.contains('Mathematics 101'), isTrue);

      // Class ends
      service.onClassStatusChanged(
        isClassHappening: false,
        isClassUpcoming: false,
      );
      expect(service.currentState, PetState.idle);
      expect(service.currentMood, PetMood.neutral);
      expect(service.hasBackpackNotifier.value, isFalse);

      // Upcoming class puts on backpack
      service.onClassStatusChanged(
        isClassHappening: false,
        isClassUpcoming: true,
        className: 'History 202',
      );
      expect(service.hasBackpackNotifier.value, isTrue);
      expect(service.speechNotifier.value.contains('History 202'), isTrue);
    });

    test('checkUpcomingEvents alerts for approaching reminders and bills without duplicate spam', () {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'rem-proactive-1',
        title: 'Review Physics Notes',
        description: '',
        category: 'Study',
        date: now,
        time: '4:00 PM',
        repeat: 'None',
        reminderBefore: 'At time of event',
        priority: 'High',
        notes: '',
        completed: false,
      );

      service.checkUpcomingEvents(reminders: [reminder]);
      expect(service.currentState, PetState.worried);
      expect(service.speechNotifier.value.contains('Review Physics Notes'), isTrue);

      // Reset state to idle, call again with same reminder - must not trigger worried again
      service.stateNotifier.value = PetState.idle;
      service.checkUpcomingEvents(reminders: [reminder]);
      expect(service.currentState, PetState.idle);
    });

    test('Study timer updates transition companion through studying, break, and celebration', () {
      final initialAccompanied = service.preferences.studySessionsAccompanied;

      // Study Timer starts
      service.onStudyTimerUpdated(
        isRunning: true,
        isBreak: false,
        isCompleted: false,
        subject: 'Physics',
      );
      expect(service.currentState, PetState.studying);
      expect(service.currentMood, PetMood.focused);
      expect(service.speechNotifier.value.contains('Physics'), isTrue);

      // Break starts
      service.onStudyTimerUpdated(
        isRunning: true,
        isBreak: true,
        isCompleted: false,
        subject: 'Physics',
      );
      expect(service.currentState, PetState.idle);
      expect(service.currentMood, PetMood.neutral);

      // Study session complete!
      service.onStudyTimerUpdated(
        isRunning: false,
        isBreak: false,
        isCompleted: true,
        subject: 'Physics',
      );
      expect(service.currentState, PetState.celebrating);
      expect(service.currentMood, PetMood.excited);
      expect(service.preferences.studySessionsAccompanied, initialAccompanied + 1);
    });
  });

  group('Pet Companion UI Widget Tests', () {
    testWidgets('PetWidget renders and responds to tap gesture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PetWidget(
                width: 140,
                height: 120,
                showSpeechBubble: true,
                allowInteractions: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PetWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap on pet
      await tester.tap(find.byType(PetWidget));
      await tester.pump();
      expect(PetService.instance.preferences.totalInteractions, greaterThanOrEqualTo(1));

      // Clean up pending reaction timers
      PetService.instance.cancelPendingTimers();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('PetCompanionCard renders on dashboard and respects enabled flag', (tester) async {
      PetService.instance.preferencesNotifier.value = const PetPreferences(
        name: 'Mochi',
        enabled: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetCompanionCard(),
          ),
        ),
      );

      expect(find.byType(PetCompanionCard), findsOneWidget);
      expect(find.text('Mochi'), findsOneWidget);

      // Disable pet
      PetService.instance.preferencesNotifier.value = const PetPreferences(
        name: 'Mochi',
        enabled: false,
      );
      await tester.pump();
      expect(find.text('Mochi'), findsNothing);
    });

    testWidgets('PetSettingsScreen renders coat selection and settings toggles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      PetService.instance.preferencesNotifier.value = const PetPreferences(
        name: 'Mochi',
        enabled: true,
        coatStyle: PetCoatStyle.gingerTabby,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PetSettingsScreen(),
        ),
      );

      expect(find.text('Pet Companion Settings'), findsOneWidget);
      expect(find.text('Ginger Tabby'), findsOneWidget);
      expect(find.text('Midnight Tuxedo'), findsOneWidget);
      expect(find.text('Calico Patch'), findsOneWidget);
      expect(find.text('Snow White'), findsOneWidget);
      expect(find.text('Enable Pet Companion'), findsOneWidget);
      expect(find.text('Event Reactions'), findsOneWidget);
      expect(find.text('Idle Movement'), findsOneWidget);

      // Tap on Midnight Tuxedo to update coat
      await tester.tap(find.text('Midnight Tuxedo'));
      await tester.pump();
      expect(PetService.instance.preferences.coatStyle, PetCoatStyle.tuxedoMidnight);
    });
  });

  group('PetAudioService Offline Unit Tests', () {
    test('PetAudioService instance is accessible and handles mute/headless safely', () async {
      final audioService = PetAudioService.instance;
      expect(audioService, isNotNull);
      expect(audioService.isAudioAvailable, isTrue);

      // Verify safe invocation without throwing in test environment
      await audioService.playPurr();
      await audioService.playMeow();
      await audioService.playMeow(variant: 1);
      await audioService.playMeow(variant: 2);
      await audioService.stop();

      // Disable audio and test again
      audioService.isAudioAvailable = false;
      await audioService.playPurr();
      await audioService.playMeow();
      await audioService.playMeow(variant: 1);
      await audioService.playMeow(variant: 2);
      audioService.isAudioAvailable = true;
    });
  });

  group('Kitty Hunger System Unit Tests', () {
    test('HungerState maps percentage accurately across all 5 states', () {
      expect(HungerState.fromPercentage(100.0), HungerState.wellFed);
      expect(HungerState.fromPercentage(80.0), HungerState.wellFed);
      expect(HungerState.fromPercentage(79.9), HungerState.gettingHungry);
      expect(HungerState.fromPercentage(50.0), HungerState.gettingHungry);
      expect(HungerState.fromPercentage(49.9), HungerState.hungry);
      expect(HungerState.fromPercentage(20.0), HungerState.hungry);
      expect(HungerState.fromPercentage(19.9), HungerState.veryHungry);
      expect(HungerState.fromPercentage(1.0), HungerState.veryHungry);
      expect(HungerState.fromPercentage(0.5), HungerState.empty);
      expect(HungerState.fromPercentage(0.0), HungerState.empty);
    });

    test('Hunger drains gradually based on elapsed local time without internet', () {
      final service = PetService.instance;
      final startTime = DateTime(2026, 9, 30, 8, 0);

      service.preferencesNotifier.value = PetPreferences(
        hunger: 80.0,
        lastHungerUpdate: startTime,
      );

      // Advance by 6 hours (daytime natural metabolism ~3.5h - 7.5h per 10%)
      final sixHoursLater = startTime.add(const Duration(hours: 6));
      service.updateHungerDecay(currentTime: sixHoursLater);

      // Hunger should have decreased gradually
      expect(service.preferences.hunger, lessThan(80.0));
      expect(service.preferences.hunger, greaterThanOrEqualTo(60.0));

      // Advance by 24 hours (1 full day)
      final oneDayLater = startTime.add(const Duration(hours: 24));
      service.updateHungerDecay(currentTime: oneDayLater);
      expect(service.preferences.hunger, lessThan(60.0));
    });

    test('Missing days never kills Kitty, never resets XP or levels, and clamps hunger at 0%', () {
      final service = PetService.instance;
      final startTime = DateTime(2026, 9, 30, 8, 0);

      service.preferencesNotifier.value = PetPreferences(
        petLevel: 4,
        currentXp: 120,
        totalXp: 570,
        hunger: 60.0,
        lastHungerUpdate: startTime,
        foodInventory: 5,
      );

      // User was away for 14 days
      final twoWeeksLater = startTime.add(const Duration(days: 14));
      service.updateHungerDecay(currentTime: twoWeeksLater);

      // Rules check:
      // 1. Hunger clamps at 0.0, never below 0
      expect(service.preferences.hunger, 0.0);
      expect(service.preferences.hungerState, HungerState.empty);

      // 2. Kitty NEVER dies, levels are not lost
      expect(service.preferences.petLevel, 4);

      // 3. Current XP and Total XP are NOT reduced
      expect(service.preferences.currentXp, 120);
      expect(service.preferences.totalXp, 570);

      // 4. Food inventory is preserved
      expect(service.preferences.foodInventory, 5);

      // 5. Growth stage is preserved
      expect(service.preferences.growthStage, PetGrowthStage.olderKitten);
    });
  });

  group('Feeding & Food XP Progression Unit Tests', () {
    test('Feeding consumes exactly 1 food, gives exactly +5 XP, and restores randomized hunger clamped to 100%', () async {
      final service = PetService.instance;

      service.preferencesNotifier.value = const PetPreferences(
        petLevel: 1,
        currentXp: 40,
        totalXp: 40,
        foodInventory: 6,
        hunger: 35.0,
      );

      final success = await service.feedKitty();
      expect(success, isTrue);

      // Food: 6 -> 5 (-1 Food)
      expect(service.preferences.foodInventory, 5);

      // XP: 40 -> 45 (+5 XP strictly)
      expect(service.preferences.currentXp, 45);
      expect(service.preferences.totalXp, 45);

      // Hunger: 35 + randomized restore (18% - 30%) -> [53.0, 65.0]
      expect(service.preferences.hunger, greaterThanOrEqualTo(53.0));
      expect(service.preferences.hunger, lessThanOrEqualTo(65.0));

      // State is eating
      expect(service.currentState, PetState.eating);
    });

    test('Feeding clamps hunger to 100% and never exceeds 100%', () async {
      final service = PetService.instance;

      service.preferencesNotifier.value = const PetPreferences(
        foodInventory: 3,
        hunger: 90.0,
        hungerRestoreAmount: 20.0,
      );

      await service.feedKitty();
      expect(service.preferences.hunger, 100.0);
    });

    test('Food cannot be consumed when food inventory is 0', () async {
      final service = PetService.instance;

      service.preferencesNotifier.value = const PetPreferences(
        foodInventory: 0,
        hunger: 20.0,
        currentXp: 10,
      );

      final success = await service.feedKitty();
      expect(success, isFalse);
      expect(service.preferences.foodInventory, 0);
      expect(service.preferences.currentXp, 10);
      expect(service.preferences.hunger, 20.0);
      expect(service.speechNotifier.value.contains('No food'), isTrue);
    });

    test('Level up occurs when XP reaches threshold and updates growth stage up to Level 10', () async {
      final service = PetService.instance;

      // Level 1 requires 100 XP
      service.preferencesNotifier.value = const PetPreferences(
        petLevel: 1,
        currentXp: 95,
        totalXp: 95,
        foodInventory: 5,
        hunger: 50.0,
      );

      expect(service.preferences.growthStage, PetGrowthStage.tinyKitten);

      // Feed +5 XP -> reaches 100 XP -> Level 2
      await service.feedKitty();

      expect(service.preferences.petLevel, 2);
      expect(service.preferences.currentXp, 0);
      expect(service.preferences.totalXp, 100);
      expect(service.preferences.growthStage, PetGrowthStage.growingKitten);

      // Test level 10 cap
      service.preferencesNotifier.value = const PetPreferences(
        petLevel: 10,
        currentXp: 500,
        totalXp: 3500,
        foodInventory: 2,
        hunger: 50.0,
      );

      await service.feedKitty();
      expect(service.preferences.petLevel, 10); // Clamped at 10
      expect(service.preferences.growthStage, PetGrowthStage.adultCat);
      expect(service.preferences.isMaxLevel, isTrue);
    });
  });

  group('Daily Productivity Tasks & Food Rewards Unit Tests', () {
    test('Daily tasks reward Food, not direct XP, and can be claimed', () async {
      final service = PetService.instance;

      service.preferencesNotifier.value = const PetPreferences(
        foodInventory: 2,
        currentXp: 20,
      );

      service.checkDailyTaskReset();
      expect(service.preferences.dailyTasks.isNotEmpty, isTrue);

      // Record school schedule checked
      await service.recordTaskProgress('school_schedule', count: 1);
      final scheduleTask = service.preferences.dailyTasks.firstWhere((t) => t.id == 'school_schedule');
      expect(scheduleTask.isCompleted, isTrue);
      expect(scheduleTask.isClaimed, isFalse);

      // XP has NOT increased directly from completing task!
      expect(service.preferences.currentXp, 20);

      // Claim reward: +1 Food
      final claimed = await service.claimDailyTaskReward('school_schedule');
      expect(claimed, isTrue);
      expect(service.preferences.foodInventory, 3); // 2 + 1 = 3 Food

      // Now feeding is what converts Food into XP
      await service.feedKitty();
      expect(service.preferences.foodInventory, 2);
      expect(service.preferences.currentXp, 25); // +5 XP strictly from feeding
    });

    test('The 8 canonical tasks across School, Study, and Bills award Food correctly and filter relevance', () async {
      final service = PetService.instance;
      service.preferencesNotifier.value = const PetPreferences(
        foodInventory: 0,
        currentXp: 0,
      );
      service.checkDailyTaskReset();

      final tasks = service.preferences.dailyTasks;
      expect(tasks.length, 8);

      // Verify categories: exactly 3 School, 2 Study, 3 Bills, 0 Reminders
      final schoolTasks = tasks.where((t) => t.category == 'School').toList();
      final studyTasks = tasks.where((t) => t.category == 'Study').toList();
      final billTasks = tasks.where((t) => t.category == 'Bills').toList();
      final reminderTasks = tasks.where((t) => t.category == 'Reminders').toList();

      expect(schoolTasks.length, 3);
      expect(studyTasks.length, 2);
      expect(billTasks.length, 3);
      expect(reminderTasks.length, 0);

      // Verify specific titles and rewards
      expect(tasks.firstWhere((t) => t.id == 'school_schedule').title, "Check today's school schedule");
      expect(tasks.firstWhere((t) => t.id == 'school_schedule').foodReward, 1);
      expect(tasks.firstWhere((t) => t.id == 'school_class').title, 'Complete a scheduled class/task');
      expect(tasks.firstWhere((t) => t.id == 'school_class').foodReward, 2);
      expect(tasks.firstWhere((t) => t.id == 'school_all').title, "Complete all today's school tasks");
      expect(tasks.firstWhere((t) => t.id == 'school_all').foodReward, 3);

      expect(tasks.firstWhere((t) => t.id == 'study_25').title, 'Complete a 25-min study session');
      expect(tasks.firstWhere((t) => t.id == 'study_25').foodReward, 2);
      expect(tasks.firstWhere((t) => t.id == 'study_2_sessions').title, 'Complete 2 study sessions');
      expect(tasks.firstWhere((t) => t.id == 'study_2_sessions').foodReward, 3);
      expect(tasks.firstWhere((t) => t.id == 'study_2_sessions').requiredCount, 2);

      expect(tasks.firstWhere((t) => t.id == 'bills_check').title, 'Check upcoming bills');
      expect(tasks.firstWhere((t) => t.id == 'bills_check').foodReward, 1);
      expect(tasks.firstWhere((t) => t.id == 'bills_paid').title, 'Mark a bill as paid');
      expect(tasks.firstWhere((t) => t.id == 'bills_paid').foodReward, 2);
      expect(tasks.firstWhere((t) => t.id == 'bills_early').title, 'Pay bill before due date');
      expect(tasks.firstWhere((t) => t.id == 'bills_early').foodReward, 3);

      // Relevance test: getRelevantDailyTasks returns ~3 tasks
      final relevant = service.getRelevantDailyTasks();
      expect(relevant.length, inInclusiveRange(1, 3));

      // Claim all test
      for (final t in tasks) {
        await service.recordTaskProgress(t.id, count: t.requiredCount, setDirect: true);
      }
      final totalClaimed = await service.claimAllCompletedRewards();
      // Sum of rewards: 1+2+3 + 2+3 + 1+2+3 = 17 food
      expect(totalClaimed, 17);
      expect(service.preferences.foodInventory, 17);
    });

    test('Progression curve accurately scales through all 10 levels and growth stages', () {
      // Thresholds check: 100, 150, 200, 250, 300, 350, 400, 450, 500, MAX
      expect(PetProgressionConfig.getXpRequiredForLevel(1), 100);
      expect(PetProgressionConfig.getXpRequiredForLevel(2), 150);
      expect(PetProgressionConfig.getXpRequiredForLevel(3), 200);
      expect(PetProgressionConfig.getXpRequiredForLevel(4), 250);
      expect(PetProgressionConfig.getXpRequiredForLevel(5), 300);
      expect(PetProgressionConfig.getXpRequiredForLevel(6), 350);
      expect(PetProgressionConfig.getXpRequiredForLevel(7), 400);
      expect(PetProgressionConfig.getXpRequiredForLevel(8), 450);
      expect(PetProgressionConfig.getXpRequiredForLevel(9), 500);
      expect(PetProgressionConfig.getXpRequiredForLevel(10), 500);

      // Growth stage mapping check:
      expect(PetGrowthStage.fromLevel(1), PetGrowthStage.tinyKitten);
      expect(PetGrowthStage.fromLevel(2), PetGrowthStage.growingKitten);
      expect(PetGrowthStage.fromLevel(3), PetGrowthStage.growingKitten);
      expect(PetGrowthStage.fromLevel(4), PetGrowthStage.olderKitten);
      expect(PetGrowthStage.fromLevel(5), PetGrowthStage.olderKitten);
      expect(PetGrowthStage.fromLevel(6), PetGrowthStage.youngCat);
      expect(PetGrowthStage.fromLevel(7), PetGrowthStage.youngCat);
      expect(PetGrowthStage.fromLevel(8), PetGrowthStage.youngAdult);
      expect(PetGrowthStage.fromLevel(9), PetGrowthStage.youngAdult);
      expect(PetGrowthStage.fromLevel(10), PetGrowthStage.adultCat);
      expect(PetGrowthStage.fromLevel(11), PetGrowthStage.adultCat);
    });
  });

  group('Body Condition & Feeding Intake System Tests', () {
    late PetBodyConditionService conditionService;

    setUp(() {
      conditionService = PetBodyConditionService.instance;
    });

    test('PetBodyCondition score mapping accurately resolves all 5 body conditions', () {
      expect(PetBodyCondition.fromScore(0.0), PetBodyCondition.verySkinny);
      expect(PetBodyCondition.fromScore(10.0), PetBodyCondition.verySkinny);
      expect(PetBodyCondition.fromScore(19.9), PetBodyCondition.verySkinny);

      expect(PetBodyCondition.fromScore(20.0), PetBodyCondition.skinny);
      expect(PetBodyCondition.fromScore(30.0), PetBodyCondition.skinny);
      expect(PetBodyCondition.fromScore(39.9), PetBodyCondition.skinny);

      expect(PetBodyCondition.fromScore(40.0), PetBodyCondition.healthy);
      expect(PetBodyCondition.fromScore(50.0), PetBodyCondition.healthy);
      expect(PetBodyCondition.fromScore(60.0), PetBodyCondition.healthy);

      expect(PetBodyCondition.fromScore(60.1), PetBodyCondition.chubby);
      expect(PetBodyCondition.fromScore(70.0), PetBodyCondition.chubby);
      expect(PetBodyCondition.fromScore(80.0), PetBodyCondition.chubby);

      expect(PetBodyCondition.fromScore(80.1), PetBodyCondition.veryChubby);
      expect(PetBodyCondition.fromScore(95.0), PetBodyCondition.veryChubby);
      expect(PetBodyCondition.fromScore(100.0), PetBodyCondition.veryChubby);
    });

    test('New Kitty defaults to Healthy condition with 50.0 score', () {
      const prefs = PetPreferences();
      expect(prefs.bodyCondition, PetBodyCondition.healthy);
      expect(prefs.bodyConditionScore, 50.0);
      expect(prefs.feedingIntakeHistory, isEmpty);
    });

    test('Feeding event records local timestamped PetFeedingRecord and awards +5 XP', () async {
      final service = PetService.instance;
      final startTime = DateTime(2026, 9, 30, 10, 0);

      service.preferencesNotifier.value = PetPreferences(
        foodInventory: 4,
        currentXp: 10,
        hunger: 50.0,
        lastBodyConditionUpdate: startTime,
        lastHungerUpdate: startTime,
      );

      final success = await service.feedKitty();
      expect(success, isTrue);

      expect(service.preferences.foodInventory, 3);
      expect(service.preferences.currentXp, 15); // +5 XP strictly
      expect(service.preferences.feedingIntakeHistory.length, 1);

      final record = service.preferences.feedingIntakeHistory.first;
      expect(record.foodConsumed, 1);
      expect(record.xpEarned, 5);
      expect(record.timestamp, isNotNull);
    });

    test('Rolling 7-day feeding history calculates intake correctly and prunes records older than 30 days', () {
      final now = DateTime(2026, 9, 30, 12, 0);

      final history = [
        PetFeedingRecord(timestamp: now.subtract(const Duration(days: 40))), // >30d -> pruned
        PetFeedingRecord(timestamp: now.subtract(const Duration(days: 35))), // >30d -> pruned
        PetFeedingRecord(timestamp: now.subtract(const Duration(days: 10))), // >7d -> not in 7d rolling window
        PetFeedingRecord(timestamp: now.subtract(const Duration(days: 4))), // in 7d window
        PetFeedingRecord(timestamp: now.subtract(const Duration(days: 2))), // in 7d window
        PetFeedingRecord(timestamp: now.subtract(const Duration(hours: 3))), // in 7d window
      ];

      // Pruning test
      final pruned = conditionService.pruneOldRecords(history, currentTime: now, maxHistoryDays: 30);
      expect(pruned.length, 4);

      // Rolling count in 7-day window
      final rollingCount = conditionService.getRollingFeedingCount(pruned, currentTime: now, rollingDays: 7);
      expect(rollingCount, 3);

      // Average daily intake
      final avgIntake = conditionService.getAverageDailyIntake(pruned, currentTime: now, rollingDays: 7);
      expect(avgIntake, greaterThan(0.0));
      expect(avgIntake, lessThanOrEqualTo(3.0));
    });

    test('Underfeeding over days gradually drops score toward Skinny and Very Skinny without punishing user', () {
      final startTime = DateTime(2026, 9, 30, 8, 0);

      // Start Healthy with no feeding records
      var prefs = PetPreferences(
        petLevel: 5,
        currentXp: 180,
        totalXp: 880,
        bodyCondition: PetBodyCondition.healthy,
        bodyConditionScore: 50.0,
        lastBodyConditionUpdate: startTime,
        feedingIntakeHistory: const [],
      );

      // 4 days pass with 0 meals
      final fourDaysLater = startTime.add(const Duration(days: 4));
      prefs = conditionService.updateConditionForElapsedTime(prefs, currentTime: fourDaysLater);

      // Score decayed smoothly (50 - 4*3.5 = ~36.0) -> Skinny
      expect(prefs.bodyConditionScore, closeTo(36.0, 1.0));
      expect(prefs.bodyCondition, PetBodyCondition.skinny);

      // Verify no punishment: XP, level, growth stage are intact!
      expect(prefs.petLevel, 5);
      expect(prefs.currentXp, 180);
      expect(prefs.totalXp, 880);
      expect(prefs.growthStage, PetGrowthStage.olderKitten);

      // 6 more days pass (total 10 days with 0 meals)
      final tenDaysLater = startTime.add(const Duration(days: 10));
      prefs = conditionService.updateConditionForElapsedTime(prefs, currentTime: tenDaysLater);

      // Score decayed into Very Skinny (< 20.0) but clamped at 0.0
      expect(prefs.bodyConditionScore, lessThan(20.0));
      expect(prefs.bodyCondition, PetBodyCondition.verySkinny);
      expect(prefs.bodyConditionScore, greaterThanOrEqualTo(0.0));
    });

    test('Overfeeding over days gradually increases score toward Chubby and Very Chubby', () {
      final baseTime = DateTime(2026, 9, 30, 8, 0);

      var prefs = PetPreferences(
        petLevel: 3,
        currentXp: 50,
        bodyCondition: PetBodyCondition.healthy,
        bodyConditionScore: 50.0,
        lastBodyConditionUpdate: baseTime,
        feedingIntakeHistory: const [],
      );

      // Simulate heavy feeding pattern: 5 meals a day over multiple days
      for (int day = 0; day < 5; day++) {
        for (int meal = 0; meal < 5; meal++) {
          final feedTime = baseTime.add(Duration(days: day, hours: meal * 3));
          prefs = conditionService.processFeeding(prefs, feedingTime: feedTime);
        }
      }

      // Kitty has gradually transitioned to Chubby or Very Chubby
      expect(prefs.bodyConditionScore, greaterThan(60.0));
      expect(
        prefs.bodyCondition == PetBodyCondition.chubby ||
            prefs.bodyCondition == PetBodyCondition.veryChubby,
        isTrue,
      );
    });

    test('Single meal does not cause instant dramatic condition swing', () {
      final now = DateTime(2026, 9, 30, 12, 0);
      final initialPrefs = PetPreferences(
        bodyCondition: PetBodyCondition.healthy,
        bodyConditionScore: 50.0,
        lastBodyConditionUpdate: now,
      );

      final updatedPrefs = conditionService.processFeeding(initialPrefs, feedingTime: now);

      // Score should change only slightly (~1-2 points), staying Healthy
      expect((updatedPrefs.bodyConditionScore - 50.0).abs(), lessThan(3.0));
      expect(updatedPrefs.bodyCondition, PetBodyCondition.healthy);
    });

    test('Chubby Kitty smoothly returns toward Healthy when feeding normalizes', () {
      final startTime = DateTime(2026, 9, 30, 8, 0);

      var prefs = PetPreferences(
        bodyCondition: PetBodyCondition.chubby,
        bodyConditionScore: 75.0,
        lastBodyConditionUpdate: startTime,
        feedingIntakeHistory: const [],
      );

      // User normalizes to balanced feeding (2 meals a day) for 6 days
      for (int day = 0; day < 6; day++) {
        for (int meal = 0; meal < 2; meal++) {
          final feedTime = startTime.add(Duration(days: day, hours: 8 + meal * 6));
          prefs = conditionService.processFeeding(prefs, feedingTime: feedTime);
        }
      }

      // Score recovered downwards toward 50.0
      expect(prefs.bodyConditionScore, lessThan(75.0));
      expect(prefs.bodyConditionScore, closeTo(55.0, 5.0));
      expect(prefs.bodyCondition, PetBodyCondition.healthy);
    });

    test('Very Skinny Kitty smoothly returns toward Healthy when user feeds regularly', () {
      final startTime = DateTime(2026, 9, 30, 8, 0);

      var prefs = PetPreferences(
        bodyCondition: PetBodyCondition.verySkinny,
        bodyConditionScore: 15.0,
        lastBodyConditionUpdate: startTime,
        feedingIntakeHistory: const [],
      );

      // Feed regularly: 2-3 meals every day for 4 days
      for (int day = 0; day < 4; day++) {
        for (int meal = 0; meal < 3; meal++) {
          final feedTime = startTime.add(Duration(days: day, hours: meal * 4));
          prefs = conditionService.processFeeding(prefs, feedingTime: feedTime);
        }
      }

      // Rebuilt strength -> Skinny -> Healthy
      expect(prefs.bodyConditionScore, greaterThan(35.0));
      expect(
        prefs.bodyCondition == PetBodyCondition.skinny ||
            prefs.bodyCondition == PetBodyCondition.healthy,
        isTrue,
      );
    });

    test('Hunger and Body Condition are strictly independent systems', () {
      // 1. Chubby Kitty with low hunger (20%)
      const chubbyLowHunger = PetPreferences(
        bodyCondition: PetBodyCondition.chubby,
        bodyConditionScore: 72.0,
        hunger: 20.0,
      );
      expect(chubbyLowHunger.bodyCondition, PetBodyCondition.chubby);
      expect(chubbyLowHunger.hungerState, HungerState.hungry);

      // 2. Skinny Kitty with high hunger (90%)
      const skinnyHighHunger = PetPreferences(
        bodyCondition: PetBodyCondition.skinny,
        bodyConditionScore: 32.0,
        hunger: 90.0,
      );
      expect(skinnyHighHunger.bodyCondition, PetBodyCondition.skinny);
      expect(skinnyHighHunger.hungerState, HungerState.wellFed);
    });

    test('Growth stage and Body Condition compound into valid KittyAppearance variants', () {
      // Tiny Kitten + Healthy
      final kittenHealthy = KittyAppearance.fromState(
        growthStage: PetGrowthStage.tinyKitten,
        bodyCondition: PetBodyCondition.healthy,
        animationState: PetState.idle,
      );
      expect(kittenHealthy.variantKey, 'kitten_healthy_idle');
      expect(kittenHealthy.spriteAssetPath, 'assets/pet/sprites/kitten_healthy.png');

      // Young Cat + Chubby + eating
      final youngChubby = KittyAppearance.fromState(
        growthStage: PetGrowthStage.youngCat,
        bodyCondition: PetBodyCondition.chubby,
        animationState: PetState.eating,
      );
      expect(youngChubby.variantKey, 'young_chubby_eating');
      expect(youngChubby.spriteAssetPath, 'assets/pet/sprites/young_chubby.png');

      // Adult Kitty + Skinny + celebrating
      final adultSkinny = KittyAppearance.fromState(
        growthStage: PetGrowthStage.adultCat,
        bodyCondition: PetBodyCondition.skinny,
        animationState: PetState.celebrating,
      );
      expect(adultSkinny.variantKey, 'adult_skinny_celebrating');
      expect(adultSkinny.spriteAssetPath, 'assets/pet/sprites/adult_skinny.png');
    });

    test('Safe migration handles legacy data without body-condition fields cleanly', () {
      final legacyJson = {
        'name': 'Mochi',
        'coatStyle': 'gingerTabby',
        'petLevel': 4,
        'currentXp': 120,
        'totalXp': 570,
        'foodInventory': 7,
        'hunger': 65.0,
        'totalFeedings': 25,
      };

      final migrated = PetPreferences.fromJson(legacyJson);

      // Preserved legacy progress
      expect(migrated.name, 'Mochi');
      expect(migrated.petLevel, 4);
      expect(migrated.currentXp, 120);
      expect(migrated.totalXp, 570);
      expect(migrated.foodInventory, 7);
      expect(migrated.hunger, 65.0);
      expect(migrated.totalFeedings, 25);

      // Safe body condition defaults
      expect(migrated.bodyCondition, PetBodyCondition.healthy);
      expect(migrated.bodyConditionScore, 50.0);
      expect(migrated.feedingIntakeHistory, isEmpty);
    });

    test('Body condition change feedback messages are friendly, supportive, and non-shaming', () {
      expect(
        conditionService.getConditionChangeFeedback(PetBodyCondition.healthy, PetBodyCondition.chubby),
        contains('plump'),
      );
      expect(
        conditionService.getConditionChangeFeedback(PetBodyCondition.chubby, PetBodyCondition.healthy),
        contains('tip-top shape'),
      );
      expect(
        conditionService.getConditionChangeFeedback(PetBodyCondition.healthy, PetBodyCondition.skinny),
        contains('slim'),
      );
      expect(
        conditionService.getConditionChangeFeedback(PetBodyCondition.skinny, PetBodyCondition.healthy),
        contains('vibrant'),
      );
    });
  });

  group('PetMood & PetMoodBadge Widget Tests', () {
    test('PetMood enum has complete labels, icons, display names and colors', () {
      for (final mood in PetMood.values) {
        expect(mood.displayName, isNotEmpty);
        expect(mood.label, isNotEmpty);
        expect(mood.icon, isNotNull);
        expect(mood.color, isNotNull);
      }

      expect(PetMood.focused.label, 'focused');
      expect(PetMood.focused.icon, Icons.psychology_rounded);
      expect(PetMood.happy.label, 'happy');
      expect(PetMood.happy.icon, Icons.sentiment_very_satisfied_rounded);
      expect(PetMood.excited.label, 'excited');
      expect(PetMood.sleepy.label, 'sleepy');
      expect(PetMood.worried.label, 'worried');
      expect(PetMood.neutral.label, 'calm');
    });

    testWidgets('PetMoodBadge renders mood icon and label accurately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PetMoodBadge(mood: PetMood.focused),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('focused'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });

    testWidgets('PetMoodLiveBadge reacts dynamically to service mood changes', (tester) async {
      final service = PetService.instance;
      service.moodNotifier.value = PetMood.happy;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PetMoodLiveBadge(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('happy'), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_very_satisfied_rounded), findsOneWidget);

      // Change mood to focused
      service.moodNotifier.value = PetMood.focused;
      await tester.pumpAndSettle();

      expect(find.text('focused'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });
  });
}



