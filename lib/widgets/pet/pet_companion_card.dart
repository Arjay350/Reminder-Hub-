import 'package:flutter/material.dart';
import '../../models/pet_models.dart';
import '../../services/pet_service.dart';
import 'pet_widget.dart';
import 'pet_dialog.dart';
import 'pet_mood_badge.dart';

class PetCompanionCard extends StatelessWidget {
  const PetCompanionCard({
    super.key,
    this.service,
    this.onTapCard,
  });

  final PetService? service;
  final VoidCallback? onTapCard;

  @override
  Widget build(BuildContext context) {
    final petService = service ?? PetService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<PetPreferences>(
      valueListenable: petService.preferencesNotifier,
      builder: (context, prefs, _) {
        if (!prefs.enabled) {
          return const SizedBox.shrink();
        }

        final hungerState = prefs.hungerState;
        final hungerColor = _getHungerColor(hungerState);
        final conditionColor = _getBodyConditionColor(prefs.bodyCondition);
        final xpRequired = prefs.xpRequired;
        final isMaxLevel = prefs.isMaxLevel;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                onTapCard?.call();
                petService.onTap();
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PetInteractionDialog(service: petService),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1E1B4B).withValues(alpha: 0.70),
                            const Color(0xFF0F172A).withValues(alpha: 0.90),
                          ]
                        : [
                            const Color(0xFFEEF2FF),
                            const Color(0xFFF8FAFC),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.20),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.14 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Top Row: Info column & Interactive Pet
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name, Level & Status Badges
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 5,
                                children: [
                                  Text(
                                    prefs.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.5,
                                      letterSpacing: -0.2,
                                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                    ),
                                  ),
                                  // Level Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7.5,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.32),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.workspace_premium_rounded,
                                          size: 11.5,
                                          color: Color(0xFF6366F1),
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          'Lv. ${prefs.petLevel} • ${prefs.growthStage.displayName}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF6366F1),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Hunger Status Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.5,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hungerColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: hungerColor.withValues(alpha: 0.32),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.restaurant_rounded,
                                          size: 10.5,
                                          color: hungerColor,
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          '${prefs.hunger.round()}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: hungerColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Body Condition Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.5,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: conditionColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: conditionColor.withValues(alpha: 0.32),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.health_and_safety_rounded,
                                          size: 10.5,
                                          color: conditionColor,
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          prefs.bodyCondition.displayName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: conditionColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // School Class or Focus Session Badge if active
                                  if (petService.isClassHappening)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.school_rounded,
                                            size: 11,
                                            color: Color(0xFF0D9488),
                                          ),
                                          SizedBox(width: 3.5),
                                          Text(
                                            'In Class',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0D9488),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (petService.isClassUpcoming)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.backpack_rounded,
                                            size: 11,
                                            color: Color(0xFFD97706),
                                          ),
                                          SizedBox(width: 3.5),
                                          Text(
                                            'Class Upcoming',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (petService.isStudyTimerRunning)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.timer_rounded,
                                            size: 11,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                          SizedBox(width: 3.5),
                                          Text(
                                            'Deep Focus',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF8B5CF6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Speech / State text Bubble
                              ValueListenableBuilder<String>(
                                valueListenable: petService.speechNotifier,
                                builder: (context, speech, _) {
                                  final textToDisplay = speech.isNotEmpty
                                      ? speech
                                      : _getDefaultCompanionText(
                                          petService.currentState,
                                          petService.currentMood,
                                          hungerState,
                                        );

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.20 : 0.12),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.85),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 250),
                                            child: Text(
                                              textToDisplay,
                                              key: ValueKey(textToDisplay),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.grey.shade200
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Interactive Pet Animated Widget & Centered Mood Pill
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            PetWidget(
                              service: petService,
                              width: 96,
                              height: 82,
                              showSpeechBubble: false,
                              allowInteractions: true,
                            ),
                            const SizedBox(height: 5),
                            PetMoodLiveBadge(service: petService),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Middle Section: Polished Custom Progress Bars
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.32)
                            : Colors.white.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 1. Hunger Bar
                          _buildProgressBar(
                            icon: Icons.restaurant_rounded,
                            label: 'HUNGER SATIETY',
                            valueText: '${prefs.hunger.round()}% (${hungerState.displayName})',
                            progress: prefs.hungerProgress,
                            accentColor: hungerColor,
                            fillGradient: LinearGradient(
                              colors: [
                                hungerColor.withValues(alpha: 0.75),
                                hungerColor,
                              ],
                            ),
                            isDark: isDark,
                          ),

                          const SizedBox(height: 9),

                          // 2. XP Progression Bar
                          _buildProgressBar(
                            icon: Icons.auto_awesome_rounded,
                            label: 'XP PROGRESSION',
                            valueText: isMaxLevel
                                ? 'Level 10 (MAX)'
                                : '${prefs.currentXp} / $xpRequired XP',
                            progress: prefs.xpProgress,
                            accentColor: const Color(0xFF6366F1),
                            fillGradient: const LinearGradient(
                              colors: [
                                Color(0xFF818CF8),
                                Color(0xFF6366F1),
                                Color(0xFF4F46E5),
                              ],
                            ),
                            isDark: isDark,
                          ),

                          const SizedBox(height: 9),

                          // 3. Body Condition Bar
                          _buildProgressBar(
                            icon: Icons.health_and_safety_rounded,
                            label: 'BODY SHAPE',
                            valueText:
                                '${prefs.bodyCondition.displayName} (${prefs.bodyConditionScore.round()}/100)',
                            progress: (prefs.bodyConditionScore / 100.0).clamp(0.0, 1.0),
                            accentColor: conditionColor,
                            fillGradient: LinearGradient(
                              colors: [
                                conditionColor.withValues(alpha: 0.70),
                                conditionColor,
                              ],
                            ),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Row: Food Inventory & Quick Feed Button & Action hint
                    Row(
                      children: [
                        // Food count pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.15),
                                const Color(0xFFD97706).withValues(alpha: isDark ? 0.16 : 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.set_meal_rounded,
                                size: 14.5,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 5.5),
                              Text(
                                '${prefs.foodInventory} Treats',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Feed Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              petService.feedKitty();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: prefs.foodInventory > 0
                                      ? const [Color(0xFF10B981), Color(0xFF059669)]
                                      : [Colors.grey.shade600, Colors.grey.shade700],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  if (prefs.foodInventory > 0)
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.restaurant_rounded,
                                    size: 13.5,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Feed',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '+5 XP',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Subtle gesture hint
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              'Tap • Care menu',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar({
    required IconData icon,
    required String label,
    required String valueText,
    required double progress,
    required Color accentColor,
    required Gradient fillGradient,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, size: 12, color: accentColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 8.5,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
              width: 0.9,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              return Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, _) {
                    return Container(
                      width: maxWidth * animValue,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: fillGradient,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.42),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getDefaultCompanionText(
    PetState state,
    PetMood mood,
    HungerState hungerState,
  ) {
    if (state == PetState.eating) {
      return 'Nom nom nom! Eating joyfully • Mood: Happy & Content';
    }
    if (state == PetState.studying) {
      return 'Studying diligently with you!';
    }
    if (state == PetState.sleeping) {
      return 'Zzz... taking a cozy cat nap.';
    }
    if (state == PetState.celebrating) {
      return 'Woohoo! Celebrating your achievement!';
    }

    if (hungerState == HungerState.empty) {
      return 'Tummy is empty! Ready for food whenever you have some.';
    }
    if (hungerState == HungerState.veryHungry) {
      return 'Getting very hungry... Got any food saved up?';
    }
    if (hungerState == HungerState.hungry) {
      return 'A little hungry! A tasty meal would be great.';
    }

    switch (mood) {
      case PetMood.happy:
        return 'Feeling joyful! Ready to tackle your day.';
      case PetMood.focused:
        return 'Focus mode activated. Let\'s achieve our goals!';
      case PetMood.sleepy:
        return 'Yawning softly... restful evening vibes.';
      case PetMood.worried:
        return 'Checking in! Don\'t forget upcoming tasks.';
      case PetMood.excited:
        return 'So energetic! You\'re doing great!';
      case PetMood.neutral:
        return 'Here with you! Keeping things organized.';
    }
  }

  Color _getHungerColor(HungerState state) {
    switch (state) {
      case HungerState.wellFed:
        return const Color(0xFF10B981); // Emerald
      case HungerState.gettingHungry:
        return const Color(0xFF0D9488); // Teal
      case HungerState.hungry:
        return const Color(0xFFF59E0B); // Amber
      case HungerState.veryHungry:
        return const Color(0xFFF97316); // Orange
      case HungerState.empty:
        return const Color(0xFFEF4444); // Gentle Red
    }
  }

  Color _getBodyConditionColor(PetBodyCondition condition) {
    switch (condition) {
      case PetBodyCondition.verySkinny:
        return const Color(0xFF3B82F6);
      case PetBodyCondition.skinny:
        return const Color(0xFF0EA5E9);
      case PetBodyCondition.healthy:
        return const Color(0xFF10B981);
      case PetBodyCondition.chubby:
        return const Color(0xFFF59E0B);
      case PetBodyCondition.veryChubby:
        return const Color(0xFFEC4899);
    }
  }
}
