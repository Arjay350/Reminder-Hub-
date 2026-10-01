import 'package:flutter/material.dart';
import '../../models/pet_models.dart';
import '../../services/pet_service.dart';

/// A sleek capsule badge/pill that displays the cat's active mood (e.g., focused, happy, excited, sleepy, worried, calm).
/// Matches the dark capsule styling with mood icon, lowercase font, and glowing accents.
class PetMoodBadge extends StatelessWidget {
  const PetMoodBadge({
    super.key,
    required this.mood,
    this.isDark,
    this.fontSize = 10.5,
    this.iconSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
    this.showTooltip = true,
  });

  final PetMood mood;
  final bool? isDark;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final moodColor = mood.color;

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF161936).withValues(alpha: 0.95)
            : moodColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: moodColor.withValues(alpha: dark ? 0.38 : 0.28),
          width: 0.95,
        ),
        boxShadow: [
          BoxShadow(
            color: moodColor.withValues(alpha: dark ? 0.20 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: Row(
          key: ValueKey(mood),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              mood.icon,
              size: iconSize,
              color: moodColor,
            ),
            const SizedBox(width: 4.5),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: moodColor,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: 'Cat Mood: ${mood.displayName}',
        child: badge,
      );
    }

    return badge;
  }
}

/// Reactive mood badge connected directly to [PetService.moodNotifier].
class PetMoodLiveBadge extends StatelessWidget {
  const PetMoodLiveBadge({
    super.key,
    this.service,
    this.isDark,
    this.fontSize = 10.5,
    this.iconSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
    this.showTooltip = true,
  });

  final PetService? service;
  final bool? isDark;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final petService = service ?? PetService.instance;
    return ValueListenableBuilder<PetMood>(
      valueListenable: petService.moodNotifier,
      builder: (context, mood, _) {
        return PetMoodBadge(
          mood: mood,
          isDark: isDark,
          fontSize: fontSize,
          iconSize: iconSize,
          padding: padding,
          showTooltip: showTooltip,
        );
      },
    );
  }
}
