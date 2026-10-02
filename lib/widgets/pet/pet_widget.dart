import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/pet_models.dart';
import '../../services/pet_service.dart';
import 'pet_painter.dart';
import 'pet_effects_painter.dart';
import 'pet_dialog.dart';

class PetWidget extends StatefulWidget {
  const PetWidget({
    super.key,
    this.service,
    this.width = 120,
    this.height = 110,
    this.showSpeechBubble = false,
    this.allowInteractions = true,
  });

  final PetService? service;
  final double width;
  final double height;
  final bool showSpeechBubble;
  final bool allowInteractions;

  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget> with TickerProviderStateMixin {
  late PetService _service;

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  late AnimationController _tailController;
  late Animation<double> _tailAnimation;

  late AnimationController _earController;
  late Animation<double> _leftEarAnimation;
  late Animation<double> _rightEarAnimation;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;

  late AnimationController _effectsController;

  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PetService.instance;

    // 1. Breathing Controller
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 2. Tail Wag Controller
    _tailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _tailAnimation = Tween<double>(begin: -0.22, end: 0.22).animate(
      CurvedAnimation(parent: _tailController, curve: Curves.easeInOutSine),
    );

    // 3. Ear Twitch Controller
    _earController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _leftEarAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.18), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.08), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 35),
    ]).animate(_earController);
    _rightEarAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.16), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: -0.06), weight: 35),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.0), weight: 35),
    ]).animate(_earController);

    // 4. Jump / Bounce Controller
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -16.0,
        ).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -16.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(_jumpController);

    // 5. Visual Effects (hearts, sparkles, zzz)
    _effectsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _service.effectTriggerNotifier.addListener(_onEffectTriggered);
    _service.stateNotifier.addListener(_onStateChanged);
  }

  void _onEffectTriggered() {
    if (!mounted) return;
    _earController.forward(from: 0.0);
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _service.currentState;

    if (state == PetState.happy ||
        state == PetState.celebrating ||
        state == PetState.eating) {
      _jumpController.forward(from: 0.0);
    } else if (state == PetState.surprised) {
      _jumpController
          .animateTo(
            -8.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted) _jumpController.reverse();
          });
    }

    // Adjust breathing tempo for sleep and hunger states (Section 2: less energetic when hungry)
    if (state == PetState.sleeping) {
      _breathingController.duration = const Duration(milliseconds: 3200);
      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
    } else if (_service.preferences.hungerState == HungerState.veryHungry ||
        _service.preferences.hungerState == HungerState.empty) {
      _breathingController.duration = const Duration(milliseconds: 2400);
      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
    } else {
      _breathingController.duration = const Duration(milliseconds: 1800);
      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _service.effectTriggerNotifier.removeListener(_onEffectTriggered);
    _service.stateNotifier.removeListener(_onStateChanged);
    _breathingController.dispose();
    _tailController.dispose();
    _earController.dispose();
    _jumpController.dispose();
    _effectsController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.allowInteractions) return;
    _service.onTap();
    _jumpController.forward(from: 0.0);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.allowInteractions) return;
    _dragDistance += details.primaryDelta?.abs() ?? 0.0;
    if (_dragDistance > 35.0) {
      _dragDistance = 0.0;
      _service.onPetSwipe();
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    _dragDistance = 0.0;
  }

  void _handleLongPress() {
    if (!widget.allowInteractions) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetInteractionDialog(service: _service),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _service.stateNotifier,
        _service.moodNotifier,
        _service.preferencesNotifier,
        _service.lookDirectionNotifier,
        _service.horizontalWalkPositionNotifier,
        _service.speechNotifier,
        _service.hasBackpackNotifier,
        _service.hasBirthdayTodayNotifier,
        _breathingAnimation,
        _tailAnimation,
        _leftEarAnimation,
        _rightEarAnimation,
        _jumpAnimation,
        _effectsController,
      ]),
      builder: (context, _) {
        final prefs = _service.preferences;
        if (!prefs.enabled) {
          return const SizedBox.shrink();
        }

        final state = _service.currentState;
        final mood = _service.currentMood;
        final lookDir = _service.lookDirectionNotifier.value;
        final walkOffset = _service.horizontalWalkPositionNotifier.value;
        final speech = _service.speechNotifier.value;

        final isWalking = state == PetState.walking;
        final inSchoolOrStudy =
            state == PetState.studying ||
            _service.isClassHappening ||
            _service.isStudyTimerRunning;
        final hasBackpack =
            _service.hasBackpackNotifier.value ||
            inSchoolOrStudy ||
            _service.isClassHappening ||
            _service.isClassUpcoming;
        final hasBook = inSchoolOrStudy || _service.isClassHappening;
        final hasBirthdayToday = _service.hasBirthdayTodayNotifier.value;

        return Semantics(
          label:
              'ReminderHub companion: ${prefs.name}, status: ${state.name}, mood: ${mood.name}',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            onLongPress: _handleLongPress,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Speech Bubble if active
                  if (widget.showSpeechBubble && speech.isNotEmpty)
                    Positioned(
                      top: -18,
                      child: _buildSpeechBubble(context, speech),
                    ),

                  // Subtle hunger indicator badge when very hungry or empty
                  if (prefs.hungerState == HungerState.veryHungry ||
                      prefs.hungerState == HungerState.empty)
                    Positioned(
                      top: -2,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (prefs.hungerState == HungerState.empty
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFF97316))
                                  .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.restaurant_rounded,
                              size: 9.5,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${prefs.hunger.round()}%',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Cat & Effects Canvas with jump and walk translations
                  Transform.translate(
                    offset: Offset(walkOffset * 40.0, _jumpAnimation.value),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Modular 2D Cat Painter
                        CustomPaint(
                          size: Size(widget.width, widget.height),
                          painter: PetCatPainter(
                            state: state,
                            mood: mood,
                            coatStyle: prefs.coatStyle,
                            lookDirection: lookDir,
                            breathOffset: _breathingAnimation.value,
                            tailAngle: _tailAnimation.value,
                            leftEarAngle: _leftEarAnimation.value,
                            rightEarAngle: _rightEarAnimation.value,
                            pawStepOffset: _effectsController.value * 2 * pi,
                            blinkProgress: state == PetState.blinking
                                ? 1.0
                                : 0.0,
                            isWalking: isWalking,
                            isStudying: inSchoolOrStudy,
                            hasBackpack: hasBackpack,
                            hasBook: hasBook,
                            hasBirthday: hasBirthdayToday,
                            growthStage: prefs.growthStage,
                            bodyCondition: prefs.bodyCondition,
                          ),
                        ),

                        // Floating Visual Effects (Hearts, Sparkles, Zzz)
                        CustomPaint(
                          size: Size(widget.width, widget.height),
                          painter: PetEffectsPainter(
                            state: state,
                            animationProgress: _effectsController.value,
                          ),
                        ),
                      ],
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

  Widget _buildSpeechBubble(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
          ),
        ),
      ),
    );
  }
}
