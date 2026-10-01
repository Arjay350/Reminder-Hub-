import 'package:flutter/material.dart';
import '../../models/pet_models.dart';
import '../../services/pet_service.dart';
import '../../services/pet_body_condition_service.dart';
import '../../screens/pet/pet_settings_screen.dart';
import 'pet_widget.dart';
import 'pet_mood_badge.dart';

class PetInteractionDialog extends StatefulWidget {
  const PetInteractionDialog({super.key, required this.service});

  final PetService service;

  @override
  State<PetInteractionDialog> createState() => _PetInteractionDialogState();
}

class _PetInteractionDialogState extends State<PetInteractionDialog> {
  PetService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<PetPreferences>(
      valueListenable: service.preferencesNotifier,
      builder: (context, prefs, _) {
        final hungerState = prefs.hungerState;
        final hungerColor = _getHungerColor(hungerState);
        final isMaxLevel = prefs.isMaxLevel;
        final xpRequired = prefs.xpRequired;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 20, left: 18, right: 18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Row: Name & Level & Hunger Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.pets,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            prefs.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Lv. ${prefs.petLevel}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Hunger & Condition Pills Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 4),
                            decoration: BoxDecoration(
                              color: hungerColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: hungerColor.withValues(alpha: 0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_rounded,
                                  size: 11,
                                  color: hungerColor,
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  '${prefs.hunger.round()}%',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: hungerColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getBodyConditionColor(prefs.bodyCondition)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: _getBodyConditionColor(prefs.bodyCondition)
                                    .withValues(alpha: 0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 11,
                                  color: _getBodyConditionColor(prefs.bodyCondition),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  prefs.bodyCondition.displayName,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _getBodyConditionColor(prefs.bodyCondition),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Growth Stage & Condition Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Stage: ${prefs.growthStage.displayName} • ${hungerState.description}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pet Interactive Preview & Mood Pill
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PetWidget(
                          service: service,
                          width: 140,
                          height: 115,
                          showSpeechBubble: true,
                          allowInteractions: true,
                        ),
                        const SizedBox(height: 8),
                        PetMoodLiveBadge(
                          service: service,
                          fontSize: 11,
                          iconSize: 12.5,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Feed Action Card & Hunger/XP Bars
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hunger Bar
                        _dialogProgressBar(
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

                        const SizedBox(height: 10),

                        // XP Bar
                        _dialogProgressBar(
                          icon: Icons.auto_awesome_rounded,
                          label: 'XP PROGRESSION',
                          valueText: isMaxLevel ? 'MAX (Level 10)' : '${prefs.currentXp} / $xpRequired XP',
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

                        const SizedBox(height: 10),

                        // Body Condition Bar
                        _dialogProgressBar(
                          icon: Icons.health_and_safety_rounded,
                          label: 'BODY CONDITION',
                          valueText:
                              '${prefs.bodyCondition.displayName} (${prefs.bodyConditionScore.round()}/100)',
                          progress: (prefs.bodyConditionScore / 100.0).clamp(0.0, 1.0),
                          accentColor: _getBodyConditionColor(prefs.bodyCondition),
                          fillGradient: LinearGradient(
                            colors: [
                              _getBodyConditionColor(prefs.bodyCondition).withValues(alpha: 0.70),
                              _getBodyConditionColor(prefs.bodyCondition),
                            ],
                          ),
                          isDark: isDark,
                        ),

                        const SizedBox(height: 5),
                        Text(
                          '${prefs.bodyCondition.description} (${PetBodyConditionService.instance.getAverageDailyIntake(prefs.feedingIntakeHistory).toStringAsFixed(1)} meals/day • 7d rolling)',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Hero Feed Button Card
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              service.feedKitty();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: prefs.foodInventory > 0
                                      ? const [Color(0xFF10B981), Color(0xFF059669)]
                                      : [
                                          isDark ? const Color(0xFF334155) : const Color(0xFF64748B),
                                          isDark ? const Color(0xFF1E293B) : const Color(0xFF475569),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (prefs.foodInventory > 0)
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.set_meal_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          prefs.foodInventory > 0
                                              ? 'Feed ${prefs.name}'
                                              : 'Out of Cat Food',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          prefs.foodInventory > 0
                                              ? '${prefs.foodInventory} treat${prefs.foodInventory == 1 ? '' : 's'} available • 1 meal per feed'
                                              : 'Complete daily tasks below to earn food',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.88),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          '+5 XP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Gestures Row: Pet, Say Hi, Sleep/Wake
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionButton(
                        context,
                        icon: Icons.favorite,
                        color: const Color(0xFFF43F5E),
                        label: 'Pet',
                        onTap: () {
                          service.onPetSwipe();
                        },
                      ),
                      const SizedBox(width: 10),
                      _actionButton(
                        context,
                        icon: Icons.chat_bubble_outline,
                        color: const Color(0xFF6366F1),
                        label: 'Say Hi',
                        onTap: () {
                          service.onTap();
                        },
                      ),
                      const SizedBox(width: 10),
                      _actionButton(
                        context,
                        icon: Icons.bedtime_outlined,
                        color: const Color(0xFF8B5CF6),
                        label: service.currentState == PetState.sleeping ? 'Wake' : 'Rest',
                        onTap: () {
                          if (service.currentState == PetState.sleeping) {
                            service.onTap();
                          } else {
                            service.stateNotifier.value = PetState.sleeping;
                            service.speak('Zzz... taking a cozy nap! 🌙');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Daily Productivity Food Tasks Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.3 : 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.task_alt, size: 18, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            const Text(
                              "Today's Kitty Tasks",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            // Claim All Button if available
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.done_all, size: 14, color: Color(0xFF10B981)),
                              label: const Text(
                                'Claim All',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                              onPressed: () {
                                service.claimAllCompletedRewards();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete your tasks to earn food. Feed your Kitty to grant +5 XP and grow!',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final relevantTasks = service.getRelevantDailyTasks(prefs);
                            if (relevantTasks.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'All tasks completed for today! 🎉',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: relevantTasks.map((task) => _taskRow(task, isDark)).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mini Bond Stats
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _bondStat(
                          label: 'Pats',
                          value: '${prefs.totalPets}',
                          icon: Icons.favorite_border,
                        ),
                        _divider(isDark),
                        _bondStat(
                          label: 'Meals Fed',
                          value: '${prefs.totalFeedings}',
                          icon: Icons.restaurant,
                        ),
                        _divider(isDark),
                        _bondStat(
                          label: 'Celebrations',
                          value: '${prefs.tasksCelebrated}',
                          icon: Icons.celebration,
                        ),
                        _divider(isDark),
                        _bondStat(
                          label: 'Focus Sesh',
                          value: '${prefs.studySessionsAccompanied}',
                          icon: Icons.timer_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Settings Navigation Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text(
                        'Pet Settings & Appearance',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PetSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _taskRow(PetDailyTask task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 16,
            color: task.isCompleted ? const Color(0xFF10B981) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    decoration: task.isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${task.currentCount}/${task.requiredCount} • +${task.foodReward} Food',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (task.isCompleted && !task.isClaimed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                service.claimDailyTaskReward(task.id);
              },
              child: const Text('Claim', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else if (task.isClaimed)
            const Text('Claimed', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))
          else
            Text('${task.currentCount}/${task.requiredCount}',
                style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      onPressed: onTap,
    );
  }

  Widget _bondStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF6366F1)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 22,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
    );
  }

  Widget _dialogProgressBar({
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

  Color _getHungerColor(HungerState state) {
    switch (state) {
      case HungerState.wellFed:
        return const Color(0xFF10B981);
      case HungerState.gettingHungry:
        return const Color(0xFF0D9488);
      case HungerState.hungry:
        return const Color(0xFFF59E0B);
      case HungerState.veryHungry:
        return const Color(0xFFF97316);
      case HungerState.empty:
        return const Color(0xFFEF4444);
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
