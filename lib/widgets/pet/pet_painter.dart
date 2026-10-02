import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/pet_models.dart';

/// Renders the modular 2D cat components (body, head, ears, eyes, mouth, tail, paws, accessories)
/// with smooth curves, gradients, growth stage scaling, and hunger/eating interactions.
class PetCatPainter extends CustomPainter {
  PetCatPainter({
    required this.state,
    required this.mood,
    required this.coatStyle,
    required this.lookDirection,
    required this.breathOffset,
    required this.tailAngle,
    required this.leftEarAngle,
    required this.rightEarAngle,
    required this.pawStepOffset,
    required this.blinkProgress,
    required this.isWalking,
    required this.isStudying,
    this.hasBackpack = false,
    this.hasBook = false,
    this.hasBirthday = false,
    this.growthStage = PetGrowthStage.tinyKitten,
    this.bodyCondition = PetBodyCondition.healthy,
  });

  final PetState state;
  final PetMood mood;
  final PetCoatStyle coatStyle;
  final PetLookDirection lookDirection;
  final double breathOffset; // -1.0 to 1.0 (breathing vertical/scale)
  final double tailAngle; // in radians
  final double leftEarAngle; // in radians
  final double rightEarAngle; // in radians
  final double pawStepOffset; // stepping cycle offset
  final double blinkProgress; // 0.0 (open) to 1.0 (closed)
  final bool isWalking;
  final bool isStudying;
  final bool hasBackpack;
  final bool hasBook;
  final bool hasBirthday;
  final PetGrowthStage growthStage;
  final PetBodyCondition bodyCondition;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Palette resolution based on coat style
    final palette = _getCoatPalette(coatStyle);

    canvas.save();
    // Center origin
    canvas.translate(centerX, centerY + 8);

    // Apply Growth Stage scale factor (Tiny Kitten -> Adult Kitty)
    final scale = growthStage.scaleFactor;
    canvas.scale(scale, scale);

    // Dynamic vertical breathing bob
    final breathShift = breathOffset * 2.5;

    // Draw Tail (behind body)
    _drawTail(canvas, palette);

    // Draw Backpack (if studying, upcoming class, or school class time, behind body)
    if (isStudying || hasBackpack) {
      _drawBackpack(canvas);
    }

    // Draw Rear Paws
    _drawBackPaws(canvas, palette);

    // Draw Body
    _drawBody(canvas, palette, breathShift);

    // Draw Front Paws
    _drawFrontPaws(canvas, palette, breathShift);

    // Draw Head & Facial Features
    _drawHead(canvas, palette, breathShift);

    // Draw Adult Cat Collar / Crown if Level 10
    if (growthStage == PetGrowthStage.adultCat) {
      _drawAdultCollar(canvas, breathShift);
    }

    if (hasBirthday) {
      _drawBirthdayHat(canvas);
    }

    // Draw Open Book/Notebook in front (if studying or school class time)
    if (isStudying || hasBook) {
      _drawOpenBook(canvas, breathShift);
    }

    // Draw Food Bowl in front (if eating)
    if (state == PetState.eating) {
      _drawFoodBowl(canvas, breathShift);
    }

    if (hasBirthday) {
      _drawBirthdayCake(canvas, breathShift);
    }

    canvas.restore();
  }

  void _drawTail(Canvas canvas, _CatPalette palette) {
    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final isOlderKitten = growthStage == PetGrowthStage.olderKitten;

    canvas.save();
    canvas.translate(-26, 12);
    canvas.rotate(tailAngle);

    final tailPath = Path();
    if (isKitten) {
      // Shorter, cuter kitten tail with soft baby curve
      tailPath.moveTo(0, 0);
      tailPath.cubicTo(-12, -10, -18, -24, -8, -32);
      tailPath.cubicTo(-2, -36, 4, -30, 0, -22);
      tailPath.cubicTo(-3, -16, 5, -6, 3, 0);
      tailPath.close();
    } else if (isOlderKitten) {
      tailPath.moveTo(0, 0);
      tailPath.cubicTo(-15, -12, -23, -29, -11, -39);
      tailPath.cubicTo(-4, -44, 3, -37, -1, -28);
      tailPath.cubicTo(-4, -20, 5, -8, 3.5, 0);
      tailPath.close();
    } else {
      tailPath.moveTo(0, 0);
      tailPath.cubicTo(-18, -14, -28, -34, -14, -46);
      tailPath.cubicTo(-6, -52, 2, -44, -2, -34);
      tailPath.cubicTo(-6, -24, 6, -10, 4, 0);
      tailPath.close();
    }

    final tailPaint = Paint()
      ..color = palette.primary
      ..style = PaintingStyle.fill;
    canvas.drawPath(tailPath, tailPaint);

    if (palette.secondary != null) {
      final tipPaint = Paint()
        ..color = palette.secondary!
        ..style = PaintingStyle.fill;
      final tipOffset = isKitten
          ? const Offset(-7, -28)
          : const Offset(-13, -42);
      canvas.drawCircle(tipOffset, isKitten ? 5.0 : 6.5, tipPaint);
    }

    canvas.restore();
  }

  void _drawBackPaws(Canvas canvas, _CatPalette palette) {
    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final pawScale = isKitten ? 0.85 : 1.0;
    final widthFactor = bodyCondition.bodyWidthFactor;
    final pawWidth = 16 * (0.92 + 0.08 * widthFactor) * pawScale;
    final pawHeight = 12 * (0.92 + 0.08 * widthFactor) * pawScale;

    final pawPaint = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.fill;

    // Left Back Paw
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-34 * widthFactor * pawScale, 18, pawWidth, pawHeight),
        Radius.circular(6 * pawScale),
      ),
      pawPaint,
    );

    // Right Back Paw
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18 * widthFactor * pawScale, 18, pawWidth, pawHeight),
        Radius.circular(6 * pawScale),
      ),
      pawPaint,
    );
  }

  void _drawBody(Canvas canvas, _CatPalette palette, double breathShift) {
    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final isAdult = growthStage == PetGrowthStage.adultCat;

    // Kitten has a smaller, shorter, more compact baby body relative to head
    final growthBodyFactor = isKitten ? 0.88 : (isAdult ? 1.06 : 1.0);
    final widthFactor = bodyCondition.bodyWidthFactor * growthBodyFactor;
    final heightFactor =
        (0.96 + (0.04 * widthFactor)) * (isKitten ? 0.90 : 1.0);

    final bodyRect = Rect.fromCenter(
      center: Offset(0, (isKitten ? 10 : 8) + breathShift),
      width: (58 + (breathOffset * 1.5)) * widthFactor,
      height: (52 + (breathOffset * 2.0)) * heightFactor,
    );

    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.primary, palette.primaryDark],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(bodyRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(26 * widthFactor)),
      bodyPaint,
    );

    // Chest / Belly Fur Patch
    final bellyPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final bellyRect = Rect.fromCenter(
      center: Offset(0, (isKitten ? 13 : 12) + breathShift),
      width: 30 * widthFactor,
      height: 32 * heightFactor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bellyRect, Radius.circular(15 * widthFactor)),
      bellyPaint,
    );

    // Tabby Stripes or Calico Spot
    if (coatStyle == PetCoatStyle.gingerTabby) {
      final stripePaint = Paint()
        ..color = palette.stripeColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(-20 * widthFactor, 4 + breathShift),
        Offset(-10 * widthFactor, 8 + breathShift),
        stripePaint,
      );
      canvas.drawLine(
        Offset(20 * widthFactor, 4 + breathShift),
        Offset(10 * widthFactor, 8 + breathShift),
        stripePaint,
      );
    } else if (coatStyle == PetCoatStyle.calico && palette.secondary != null) {
      final spotPaint = Paint()
        ..color = palette.secondary!
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromLTWH(
          -22 * widthFactor,
          -2 + breathShift,
          14 * widthFactor,
          18,
        ),
        spotPaint,
      );
    }
  }

  void _drawFrontPaws(Canvas canvas, _CatPalette palette, double breathShift) {
    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final pawScale = isKitten ? 0.85 : 1.0;
    final widthFactor = bodyCondition.bodyWidthFactor;
    final pawWidth = 14 * (0.92 + 0.08 * widthFactor) * pawScale;
    final pawHeight = 13 * (0.92 + 0.08 * widthFactor) * pawScale;

    final pawPaint = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.fill;

    final pawBorder = Paint()
      ..color = palette.primaryDark.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final leftPawOffset = isWalking ? sin(pawStepOffset) * 4.0 : 0.0;
    final rightPawOffset = isWalking ? -sin(pawStepOffset) * 4.0 : 0.0;

    final liftPaw =
        (state == PetState.happy ||
        state == PetState.celebrating ||
        state == PetState.eating);
    final leftLift = liftPaw ? -6.0 : 0.0;

    // Left Front Paw
    final leftRect = Rect.fromLTWH(
      -18 * (0.92 + 0.08 * widthFactor) * pawScale,
      20 + breathShift + leftPawOffset + leftLift,
      pawWidth,
      pawHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftRect, Radius.circular(6 * pawScale)),
      pawPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftRect, Radius.circular(6 * pawScale)),
      pawBorder,
    );

    // Right Front Paw
    final rightRect = Rect.fromLTWH(
      4 * (0.92 + 0.08 * widthFactor) * pawScale,
      20 + breathShift + rightPawOffset,
      pawWidth,
      pawHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRect, Radius.circular(6 * pawScale)),
      pawPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRect, Radius.circular(6 * pawScale)),
      pawBorder,
    );
  }

  void _drawHead(Canvas canvas, _CatPalette palette, double breathShift) {
    canvas.save();

    double headTilt = 0.0;
    if (state == PetState.beingPetted) {
      headTilt = 0.08;
    } else if (state == PetState.lookingAround) {
      headTilt = lookDirection == PetLookDirection.left ? -0.06 : 0.06;
    } else if (state == PetState.happy || state == PetState.eating) {
      headTilt = -0.04;
    }

    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final headCenterY = (isKitten ? -22 : -24) + breathShift * 0.7;
    canvas.translate(0, headCenterY);
    canvas.rotate(headTilt);

    // 1. Draw Ears
    _drawEars(canvas, palette);

    // 2. Draw Head Base (Kittens have a larger, rounder head relative to body)
    final cheekFactor = bodyCondition.cheekFactor;
    final headScale = isKitten
        ? 1.06
        : (growthStage == PetGrowthStage.adultCat ? 0.98 : 1.0);
    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: 64 * cheekFactor * headScale,
      height: 52 * (0.96 + 0.04 * cheekFactor) * headScale,
    );

    final headGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.primary, palette.primaryDark],
    );

    final headPaint = Paint()
      ..shader = headGradient.createShader(headRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        headRect,
        Radius.circular(24 * cheekFactor * headScale),
      ),
      headPaint,
    );

    // Head Spot for Calico
    if (coatStyle == PetCoatStyle.calico && palette.secondary != null) {
      final spotPaint = Paint()
        ..color = palette.secondary!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(-16 * headScale, -10 * headScale),
        10 * headScale,
        spotPaint,
      );
    } else if (coatStyle == PetCoatStyle.gingerTabby) {
      final stripePaint = Paint()
        ..color = palette.stripeColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(-6 * headScale, -18 * headScale),
        Offset(-4 * headScale, -10 * headScale),
        stripePaint,
      );
      canvas.drawLine(
        Offset(0, -19 * headScale),
        Offset(0, -9 * headScale),
        stripePaint,
      );
      canvas.drawLine(
        Offset(6 * headScale, -18 * headScale),
        Offset(4 * headScale, -10 * headScale),
        stripePaint,
      );
    }

    // 3. Draw Eyes
    _drawEyes(canvas, palette);

    // 4. Draw Muzzle, Nose, Mouth & Whiskers
    _drawMuzzle(canvas, palette);

    canvas.restore();
  }

  void _drawEars(Canvas canvas, _CatPalette palette) {
    // Subtle ear droop when hungry (Section 2 & 11)
    final hungryDroop = state == PetState.hungry ? 0.12 : 0.0;

    // Left Ear
    canvas.save();
    canvas.translate(-18, -20);
    canvas.rotate(leftEarAngle - hungryDroop);

    final leftEarPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-12, -22)
      ..quadraticBezierTo(-2, -26, 10, -8)
      ..close();

    final earPaint = Paint()
      ..color = palette.primary
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftEarPath, earPaint);

    final innerPath = Path()
      ..moveTo(-1, -2)
      ..lineTo(-8, -17)
      ..quadraticBezierTo(-2, -20, 6, -8)
      ..close();
    final innerPaint = Paint()
      ..color = palette.earInner
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);

    canvas.restore();

    // Right Ear
    canvas.save();
    canvas.translate(18, -20);
    canvas.rotate(rightEarAngle + hungryDroop);

    final rightEarPath = Path()
      ..moveTo(0, 0)
      ..lineTo(12, -22)
      ..quadraticBezierTo(2, -26, -10, -8)
      ..close();

    canvas.drawPath(rightEarPath, earPaint);

    final rightInnerPath = Path()
      ..moveTo(1, -2)
      ..lineTo(8, -17)
      ..quadraticBezierTo(2, -20, -6, -8)
      ..close();
    canvas.drawPath(rightInnerPath, innerPaint);

    canvas.restore();
  }

  void _drawEyes(Canvas canvas, _CatPalette palette) {
    double lookShiftX = 0;
    double lookShiftY = 0;
    if (lookDirection == PetLookDirection.left) {
      lookShiftX = -2.5;
    } else if (lookDirection == PetLookDirection.right) {
      lookShiftX = 2.5;
    } else if (lookDirection == PetLookDirection.up) {
      lookShiftY = -2.5;
    } else if (lookDirection == PetLookDirection.down) {
      lookShiftY = 2.5;
    }

    final isSleeping = state == PetState.sleeping;
    final isEating = state == PetState.eating;
    final isPet = state == PetState.beingPetted || state == PetState.happy;
    final isSurprised = state == PetState.surprised;
    final isBlinking = blinkProgress > 0.4 || state == PetState.blinking;

    if (isSleeping || isEating || (isPet && !isSurprised)) {
      // Happy / Sleeping / Eating curved eyes (^ ^)
      final eyePaint = Paint()
        ..color = const Color(0xFF2D2626)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final leftEyePath = Path();
      leftEyePath.moveTo(-20, -2);
      leftEyePath.quadraticBezierTo(-14, -8, -8, -2);
      canvas.drawPath(leftEyePath, eyePaint);

      final rightEyePath = Path();
      rightEyePath.moveTo(8, -2);
      rightEyePath.quadraticBezierTo(14, -8, 20, -2);
      canvas.drawPath(rightEyePath, eyePaint);
      return;
    }

    if (isBlinking) {
      final blinkPaint = Paint()
        ..color = const Color(0xFF2D2626)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(-19, -3), const Offset(-9, -3), blinkPaint);
      canvas.drawLine(const Offset(9, -3), const Offset(19, -3), blinkPaint);
      return;
    }

    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final isOlderKitten = growthStage == PetGrowthStage.olderKitten;
    final eyeScale = isKitten
        ? 1.20
        : (isOlderKitten
              ? 1.10
              : (growthStage == PetGrowthStage.adultCat ? 0.95 : 1.0));

    final eyeRadiusX = (isSurprised ? 7.5 : 6.0) * eyeScale;
    final eyeRadiusY = (isSurprised ? 8.5 : 7.0) * eyeScale;

    final eyeWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-14, -3),
        width: eyeRadiusX * 2,
        height: eyeRadiusY * 2,
      ),
      eyeWhitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(14, -3),
        width: eyeRadiusX * 2,
        height: eyeRadiusY * 2,
      ),
      eyeWhitePaint,
    );

    final pupilPaint = Paint()
      ..color = palette.eyeColor
      ..style = PaintingStyle.fill;

    final pupilOffsetLeft = Offset(-14 + lookShiftX, -3 + lookShiftY);
    final pupilOffsetRight = Offset(14 + lookShiftX, -3 + lookShiftY);
    final pupilRadius = (isSurprised ? 4.5 : 3.6) * eyeScale;

    canvas.drawCircle(pupilOffsetLeft, pupilRadius, pupilPaint);
    canvas.drawCircle(pupilOffsetRight, pupilRadius, pupilPaint);

    final sparklePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Main highlight sparkle
    canvas.drawCircle(
      pupilOffsetLeft + Offset(-1.2 * eyeScale, -1.2 * eyeScale),
      1.5 * eyeScale,
      sparklePaint,
    );
    canvas.drawCircle(
      pupilOffsetRight + Offset(-1.2 * eyeScale, -1.2 * eyeScale),
      1.5 * eyeScale,
      sparklePaint,
    );

    // Kittens get extra sweet baby glint sparkle!
    if (isKitten) {
      canvas.drawCircle(
        pupilOffsetLeft + Offset(1.5 * eyeScale, 1.4 * eyeScale),
        0.9 * eyeScale,
        sparklePaint,
      );
      canvas.drawCircle(
        pupilOffsetRight + Offset(1.5 * eyeScale, 1.4 * eyeScale),
        0.9 * eyeScale,
        sparklePaint,
      );
    }
  }

  void _drawMuzzle(Canvas canvas, _CatPalette palette) {
    // Nose
    final nosePath = Path()
      ..moveTo(0, 3)
      ..lineTo(-3.5, 0)
      ..lineTo(3.5, 0)
      ..close();

    final nosePaint = Paint()
      ..color = palette.earInner
      ..style = PaintingStyle.fill;
    canvas.drawPath(nosePath, nosePaint);

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF332D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final isWorried =
        mood == PetMood.worried ||
        state == PetState.worried ||
        state == PetState.hungry;
    final isMeowing =
        state == PetState.happy ||
        state == PetState.celebrating ||
        state == PetState.eating;

    if (isWorried) {
      final mouthPath = Path();
      mouthPath.moveTo(-6, 7);
      mouthPath.quadraticBezierTo(0, 4, 6, 7);
      canvas.drawPath(mouthPath, mouthPaint);
    } else if (isMeowing) {
      final openMouth = Path()
        ..moveTo(-4, 4)
        ..quadraticBezierTo(0, 9, 4, 4)
        ..close();
      final fillPaint = Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.fill;
      canvas.drawPath(openMouth, fillPaint);
      canvas.drawPath(openMouth, mouthPaint);
    } else {
      final mouthPath = Path();
      mouthPath.moveTo(-5, 4);
      mouthPath.quadraticBezierTo(-2.5, 6.5, 0, 4);
      mouthPath.quadraticBezierTo(2.5, 6.5, 5, 4);
      canvas.drawPath(mouthPath, mouthPaint);
    }

    // Whiskers scaled to growth maturity (Section 14: Kitten to Adult maturity)
    final whiskerLen = growthStage == PetGrowthStage.tinyKitten
        ? 8.0
        : (growthStage == PetGrowthStage.growingKitten
              ? 10.5
              : (growthStage == PetGrowthStage.adultCat ? 16.5 : 14.0));

    final whiskerPaint = Paint()
      ..color = const Color(0xFF4A4242).withValues(alpha: 0.65)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(-16, 3),
      Offset(-16 - whiskerLen, 0),
      whiskerPaint,
    );
    canvas.drawLine(
      const Offset(-16, 6),
      Offset(-16 - (whiskerLen * 0.9), 7),
      whiskerPaint,
    );

    canvas.drawLine(
      const Offset(16, 3),
      Offset(16 + whiskerLen, 0),
      whiskerPaint,
    );
    canvas.drawLine(
      const Offset(16, 6),
      Offset(16 + (whiskerLen * 0.9), 7),
      whiskerPaint,
    );

    // Blush cheeks (Kittens have subtle persistent cute baby blush)
    final isKitten =
        growthStage == PetGrowthStage.tinyKitten ||
        growthStage == PetGrowthStage.growingKitten;
    final showBlush =
        isKitten ||
        state == PetState.beingPetted ||
        state == PetState.happy ||
        state == PetState.eating ||
        mood == PetMood.happy;

    if (showBlush) {
      final blushOpacity =
          (state == PetState.beingPetted ||
              state == PetState.happy ||
              state == PetState.eating ||
              mood == PetMood.happy)
          ? 0.38
          : 0.20; // Soft sweet idle glow for kittens

      final blushPaint = Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: blushOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(const Offset(-19, 5), isKitten ? 6.0 : 5.5, blushPaint);
      canvas.drawCircle(const Offset(19, 5), isKitten ? 6.0 : 5.5, blushPaint);
    }
  }

  void _drawAdultCollar(Canvas canvas, double breathShift) {
    // Shiny gold collar for Level 10 Adult Kitty
    final collarPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -6 + breathShift * 0.7),
        width: 32,
        height: 14,
      ),
      0.2,
      pi - 0.4,
      false,
      collarPaint,
    );

    final bellPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, 1 + breathShift * 0.7), 3.2, bellPaint);
  }

  void _drawFoodBowl(Canvas canvas, double breathShift) {
    canvas.save();
    canvas.translate(0, 21 + breathShift);

    // 1. Soft Ground Contact Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 10.0), width: 38, height: 8),
      shadowPaint,
    );

    // 2. Bowl Ceramic Outer Body
    final bowlBodyRect = Rect.fromCenter(
      center: const Offset(0, 4.5),
      width: 36,
      height: 15,
    );
    final bowlBodyGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
    );
    final bowlBodyPaint = Paint()
      ..shader = bowlBodyGradient.createShader(bowlBodyRect)
      ..style = PaintingStyle.fill;

    final bowlPath = Path()
      ..moveTo(-17, 0)
      ..lineTo(17, 0)
      ..quadraticBezierTo(18, 9, 12, 12)
      ..lineTo(-12, 12)
      ..quadraticBezierTo(-18, 9, -17, 0)
      ..close();
    canvas.drawPath(bowlPath, bowlBodyPaint);

    // Rim highlight on outer edge
    final rimHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bowlPath, rimHighlight);

    // Cute Fish Logo embossed on the bowl front
    final logoPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final fishLogoPath = Path()
      ..moveTo(-3, 6.5)
      ..quadraticBezierTo(0, 4.5, 3, 6.5)
      ..quadraticBezierTo(0, 8.5, -3, 6.5)
      ..moveTo(3, 6.5)
      ..lineTo(5.5, 4.8)
      ..lineTo(5.5, 8.2)
      ..close();
    canvas.drawPath(fishLogoPath, logoPaint);

    // 3. Inner Bowl Well Cavity
    final innerCavityRect = Rect.fromCenter(
      center: const Offset(0, 0),
      width: 32,
      height: 11,
    );
    final innerPaint = Paint()
      ..color = const Color(0xFF3730A3)
      ..style = PaintingStyle.fill;
    canvas.drawOval(innerCavityRect, innerPaint);

    // 4. Delicious Cat Food Heap (Rich Salmon & Golden Glazed Kibble)
    final foodRect = Rect.fromCenter(
      center: const Offset(0, -0.8),
      width: 28,
      height: 9.5,
    );
    final foodGradient = const RadialGradient(
      center: Alignment(0, -0.3),
      radius: 0.85,
      colors: [Color(0xFFFBBF24), Color(0xFFEA580C)],
    );
    final foodPaint = Paint()
      ..shader = foodGradient.createShader(foodRect)
      ..style = PaintingStyle.fill;
    canvas.drawOval(foodRect, foodPaint);

    // Golden baked crunchy kibble chunks
    final kibblePaint = Paint()
      ..color = const Color(0xFFFED7AA)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-7, -1.8), 1.9, kibblePaint);
    canvas.drawCircle(const Offset(-1, -2.8), 2.2, kibblePaint);
    canvas.drawCircle(const Offset(6, -1.8), 1.9, kibblePaint);
    canvas.drawCircle(const Offset(-4, 0.9), 1.6, kibblePaint);
    canvas.drawCircle(const Offset(4, 0.9), 1.7, kibblePaint);

    // Gourmet Salmon Fish Treat Garnish on top
    final fishTreatPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.fill;
    final fishTreatPath = Path()
      ..moveTo(-5, -3.4)
      ..quadraticBezierTo(0, -5.6, 4.5, -3.4)
      ..quadraticBezierTo(0, -1.6, -5, -3.4)
      ..moveTo(4.5, -3.4)
      ..lineTo(7.5, -5.2)
      ..lineTo(7.5, -1.6)
      ..close();
    canvas.drawPath(fishTreatPath, fishTreatPaint);

    // Fish treat eye & glint
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-2.8, -3.6), 0.8, shinePaint);
    canvas.drawCircle(const Offset(1.8, -4.0), 0.6, shinePaint);

    canvas.restore();
  }

  void _drawBackpack(Canvas canvas) {
    canvas.save();
    canvas.translate(-26, -2);

    // Main Backpack Body
    final bagGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    );
    final bagRect = Rect.fromLTWH(0, 0, 18, 28);
    final bagPaint = Paint()
      ..shader = bagGradient.createShader(bagRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(8)),
      bagPaint,
    );

    // Backpack Top Flap
    final flapRect = Rect.fromLTWH(-1, -2, 20, 11);
    final flapPaint = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(flapRect, const Radius.circular(6)),
      flapPaint,
    );

    // Flap Buckle / Gold Tag
    final bucklePaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.5, 6, 5, 4),
        const Radius.circular(2),
      ),
      bucklePaint,
    );

    // Front Pocket
    final pocketRect = Rect.fromLTWH(2, 13, 14, 12);
    final pocketPaint = Paint()
      ..color = const Color(0xFF042F2E).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pocketRect, const Radius.circular(5)),
      pocketPaint,
    );

    // Backpack Straps
    final strapPaint = Paint()
      ..color = const Color(0xFF134E4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 0), const Offset(12, 26), strapPaint);

    canvas.restore();
  }

  void _drawBirthdayHat(Canvas canvas) {
    canvas.save();
    canvas.translate(0, -43);

    final hatPath = Path()
      ..moveTo(-10, 1)
      ..lineTo(0, -15)
      ..lineTo(10, 1)
      ..close();
    canvas.drawPath(
      hatPath,
      Paint()
        ..color = const Color(0xFFEC4899)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -1, 22, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFBBF24),
    );
    canvas.drawCircle(
      const Offset(0, -16),
      2.5,
      Paint()..color = const Color(0xFFFBBF24),
    );
    canvas.drawCircle(
      const Offset(0, -7),
      1.5,
      Paint()..color = const Color(0xFFFFF1F2),
    );

    canvas.restore();
  }

  void _drawBirthdayCake(Canvas canvas, double breathShift) {
    canvas.save();
    canvas.translate(30, 26 + breathShift);

    canvas.drawOval(
      const Rect.fromLTWH(-13, 11, 27, 6),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-13, 8, 27, 6),
      Paint()..color = const Color(0xFFFFD6E7),
    );

    final cakeRect = const Rect.fromLTWH(-10, -4, 21, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cakeRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF472B6),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-10, -6, 21, 7),
      Paint()..color = const Color(0xFFFFF1F2),
    );

    final icingPath = Path()
      ..moveTo(-7, -3)
      ..lineTo(-5, 1)
      ..lineTo(-3, -3)
      ..lineTo(0, 2)
      ..lineTo(3, -3)
      ..lineTo(6, 1)
      ..lineTo(8, -3);
    canvas.drawPath(
      icingPath,
      Paint()
        ..color = const Color(0xFFFFF1F2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1, -13, 3, 8),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFBBF24),
    );
    final flamePath = Path()
      ..moveTo(-1, -13)
      ..quadraticBezierTo(-3, -17, 1, -19)
      ..quadraticBezierTo(4, -16, 2, -13)
      ..close();
    canvas.drawPath(flamePath, Paint()..color = const Color(0xFFFB923C));

    canvas.restore();
  }

  void _drawOpenBook(Canvas canvas, double breathShift) {
    canvas.save();
    canvas.translate(0, 22 + breathShift);

    // Hardcover drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(const Rect.fromLTWH(-20, 12, 40, 8), shadowPaint);

    // Book Cover (Vibrant Indigo Gradient)
    final coverGradient = const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
    );
    final coverRect = const Rect.fromLTWH(-20, -2, 40, 20);
    final coverPaint = Paint()
      ..shader = coverGradient.createShader(coverRect)
      ..style = PaintingStyle.fill;

    final leftPage = Path()
      ..moveTo(0, 0)
      ..lineTo(-18, -4)
      ..lineTo(-18, 14)
      ..lineTo(0, 16)
      ..close();

    final rightPage = Path()
      ..moveTo(0, 0)
      ..lineTo(18, -4)
      ..lineTo(18, 14)
      ..lineTo(0, 16)
      ..close();

    canvas.drawPath(leftPage, coverPaint);
    canvas.drawPath(rightPage, coverPaint);

    final pagePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final innerLeft = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(-10, -1, -18, -2)
      ..lineTo(-18, 13)
      ..quadraticBezierTo(-10, 14, 0, 16)
      ..close();

    final innerRight = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(10, -1, 18, -2)
      ..lineTo(18, 13)
      ..quadraticBezierTo(10, 14, 0, 16)
      ..close();

    canvas.drawPath(innerLeft, pagePaint);
    canvas.drawPath(innerRight, pagePaint);

    // Red Ribbon Bookmark
    final ribbonPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    final ribbonPath = Path()
      ..moveTo(-1, 2)
      ..lineTo(1, 2)
      ..lineTo(2, 20)
      ..lineTo(0, 18)
      ..lineTo(-2, 20)
      ..close();
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Subtle text lines
    final linePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(-15, 3), const Offset(-4, 4), linePaint);
    canvas.drawLine(const Offset(-15, 7), const Offset(-4, 8), linePaint);
    canvas.drawLine(const Offset(-15, 11), const Offset(-6, 12), linePaint);

    canvas.drawLine(const Offset(4, 4), const Offset(15, 3), linePaint);
    canvas.drawLine(const Offset(4, 8), const Offset(15, 7), linePaint);
    canvas.drawLine(const Offset(6, 12), const Offset(15, 11), linePaint);

    canvas.restore();
  }

  _CatPalette _getCoatPalette(PetCoatStyle style) {
    switch (style) {
      case PetCoatStyle.gingerTabby:
        return const _CatPalette(
          primary: Color(0xFFF59E0B),
          primaryDark: Color(0xFFD97706),
          accent: Color(0xFFFEF3C7),
          stripeColor: Color(0xFFB45309),
          earInner: Color(0xFFFCA5A5),
          eyeColor: Color(0xFF059669),
        );
      case PetCoatStyle.tuxedoMidnight:
        return const _CatPalette(
          primary: Color(0xFF262E3B),
          primaryDark: Color(0xFF161C26),
          accent: Color(0xFFF8FAFC),
          stripeColor: Color(0xFF0F172A),
          earInner: Color(0xFFFDA4AF),
          eyeColor: Color(0xFFEAB308),
        );
      case PetCoatStyle.calico:
        return const _CatPalette(
          primary: Color(0xFFF3F4F6),
          primaryDark: Color(0xFFE5E7EB),
          secondary: Color(0xFFF97316),
          accent: Color(0xFFFFFFFF),
          stripeColor: Color(0xFF374151),
          earInner: Color(0xFFFCA5A5),
          eyeColor: Color(0xFF2563EB),
        );
      case PetCoatStyle.snowWhite:
        return const _CatPalette(
          primary: Color(0xFFFFFFFF),
          primaryDark: Color(0xFFE2E8F0),
          accent: Color(0xFFF8FAFC),
          stripeColor: Color(0xFFCBD5E1),
          earInner: Color(0xFFF472B6),
          eyeColor: Color(0xFF06B6D4),
        );
    }
  }

  @override
  bool shouldRepaint(covariant PetCatPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.mood != mood ||
        oldDelegate.coatStyle != coatStyle ||
        oldDelegate.lookDirection != lookDirection ||
        oldDelegate.breathOffset != breathOffset ||
        oldDelegate.tailAngle != tailAngle ||
        oldDelegate.leftEarAngle != leftEarAngle ||
        oldDelegate.rightEarAngle != rightEarAngle ||
        oldDelegate.pawStepOffset != pawStepOffset ||
        oldDelegate.blinkProgress != blinkProgress ||
        oldDelegate.isWalking != isWalking ||
        oldDelegate.isStudying != isStudying ||
        oldDelegate.hasBackpack != hasBackpack ||
        oldDelegate.hasBook != hasBook ||
        oldDelegate.hasBirthday != hasBirthday ||
        oldDelegate.growthStage != growthStage ||
        oldDelegate.bodyCondition != bodyCondition;
  }
}

class _CatPalette {
  const _CatPalette({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.stripeColor,
    required this.earInner,
    required this.eyeColor,
    this.secondary,
  });

  final Color primary;
  final Color primaryDark;
  final Color? secondary;
  final Color accent;
  final Color stripeColor;
  final Color earInner;
  final Color eyeColor;
}
