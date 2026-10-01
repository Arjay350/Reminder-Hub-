import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/pet_models.dart';

/// Floating visual particles:
/// - Hearts on petting
/// - Sparkles / stars on celebration & happy
/// - Floating "Z z z" on sleep
/// - Food crumbs and "+5 XP" on eating
/// - Food thought bubble on hungry
class PetEffectsPainter extends CustomPainter {
  PetEffectsPainter({
    required this.state,
    required this.animationProgress, // 0.0 to 1.0 repeating
  });

  final PetState state;
  final double animationProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (state == PetState.beingPetted) {
      _drawHearts(canvas, size);
    } else if (state == PetState.celebrating || state == PetState.happy) {
      _drawSparkles(canvas, size);
    } else if (state == PetState.sleeping) {
      _drawSleepingZzz(canvas, size);
    } else if (state == PetState.eating) {
      _drawEatingEffects(canvas, size);
    } else if (state == PetState.hungry) {
      _drawHungryEffects(canvas, size);
    }
  }

  void _drawEatingEffects(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Floating +5 XP indicator
    final progress = animationProgress;
    final yOffset = -16.0 - (progress * 30.0);
    final alpha = (sin(progress * pi) * 255).clamp(0, 255).toInt();

    final textSpan = TextSpan(
      text: '✨ +5 XP',
      style: TextStyle(
        color: const Color(0xFF10B981).withAlpha(alpha),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, centerY + yOffset),
    );

    // Floating golden food nibbles & sparkles
    final crumbPaint = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(alpha)
      ..style = PaintingStyle.fill;
    final sparklePaint = Paint()
      ..color = const Color(0xFFFBBF24).withAlpha(alpha)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = (i * (2 * pi / 4)) + (progress * 2.0);
      final dist = 12.0 + (progress * 14.0);
      final pos = Offset(
        centerX + cos(angle) * dist,
        centerY + 16 + sin(angle) * dist * 0.7,
      );
      if (i % 2 == 0) {
        canvas.drawCircle(pos, 1.8, crumbPaint);
      } else {
        // Star sparkle
        final starPath = Path()
          ..moveTo(pos.dx, pos.dy - 2.5)
          ..lineTo(pos.dx + 0.8, pos.dy - 0.8)
          ..lineTo(pos.dx + 2.5, pos.dy)
          ..lineTo(pos.dx + 0.8, pos.dy + 0.8)
          ..lineTo(pos.dx, pos.dy + 2.5)
          ..lineTo(pos.dx - 0.8, pos.dy + 0.8)
          ..lineTo(pos.dx - 2.5, pos.dy)
          ..lineTo(pos.dx - 0.8, pos.dy - 0.8)
          ..close();
        canvas.drawPath(starPath, sparklePaint);
      }
    }
  }

  void _drawHungryEffects(Canvas canvas, Size size) {
    final centerX = size.width / 2 + 20;
    final centerY = size.height / 2 - 25;

    final alpha = (sin(animationProgress * pi) * 230).clamp(0, 255).toInt();

    // Thought bubble
    final bubblePaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(alpha)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(centerX - 10, centerY + 12), 2.8, bubblePaint);
    canvas.drawCircle(Offset(centerX - 6, centerY + 7), 3.8, bubblePaint);

    final mainBubbleRect = Rect.fromCenter(
      center: Offset(centerX + 6, centerY - 2),
      width: 25,
      height: 20,
    );
    canvas.drawOval(mainBubbleRect, bubblePaint);
    canvas.drawOval(mainBubbleRect, borderPaint);

    // Food treat icon (cute golden salmon fish) inside thought bubble
    final fishPaint = Paint()
      ..color = const Color(0xFFF97316).withAlpha(alpha)
      ..style = PaintingStyle.fill;

    final fishPath = Path()
      ..moveTo(centerX - 2, centerY - 2)
      ..quadraticBezierTo(centerX + 3, centerY - 5.5, centerX + 8.5, centerY - 2)
      ..quadraticBezierTo(centerX + 3, centerY + 1.5, centerX - 2, centerY - 2)
      ..moveTo(centerX + 8.5, centerY - 2)
      ..lineTo(centerX + 12.5, centerY - 4.5)
      ..lineTo(centerX + 12.5, centerY + 0.5)
      ..close();
    canvas.drawPath(fishPath, fishPaint);

    // Fish eye & glint
    final fishEyePaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX + 1, centerY - 2.4), 0.9, fishEyePaint);
  }

  void _drawHearts(Canvas canvas, Size size) {
    final heartPaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < 4; i++) {
      final seed = (i * 0.25 + animationProgress) % 1.0;
      final xOffset = sin(seed * 2 * pi + i) * 24.0 + (i == 0 ? -16 : (i == 1 ? 18 : 0));
      final yOffset = -20.0 - (seed * 45.0);
      final alpha = (sin(seed * pi) * 255).clamp(0, 255).toInt();
      final scale = 0.5 + (seed * 0.6);

      heartPaint.color = const Color(0xFFF43F5E).withAlpha(alpha);

      canvas.save();
      canvas.translate(centerX + xOffset, centerY + yOffset);
      canvas.scale(scale);

      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(-4, -6, -10, -3, -10, 2)
        ..cubicTo(-10, 7, 0, 12, 0, 16)
        ..cubicTo(0, 12, 10, 7, 10, 2)
        ..cubicTo(10, -3, 4, -6, 0, 0);

      canvas.drawPath(path, heartPaint);
      canvas.restore();
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final sparklePaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (i * (pi / 3)) + (animationProgress * 0.8);
      final distance = 30.0 + (animationProgress * 28.0);
      final alpha = (sin(animationProgress * pi) * 255).clamp(0, 255).toInt();

      sparklePaint.color = (i % 2 == 0 ? const Color(0xFFFBBF24) : const Color(0xFF6366F1))
          .withAlpha(alpha);

      final x = centerX + cos(angle) * distance;
      final y = centerY - 15 + sin(angle) * (distance * 0.7);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(animationProgress * pi);

      // Star particle
      final star = Path();
      const spikes = 4;
      const outerRadius = 5.0;
      const innerRadius = 2.0;
      for (int s = 0; s < spikes * 2; s++) {
        final r = s.isEven ? outerRadius : innerRadius;
        final a = s * pi / spikes;
        final px = cos(a) * r;
        final py = sin(a) * r;
        if (s == 0) {
          star.moveTo(px, py);
        } else {
          star.lineTo(px, py);
        }
      }
      star.close();
      canvas.drawPath(star, sparklePaint);

      canvas.restore();
    }
  }

  void _drawSleepingZzz(Canvas canvas, Size size) {
    final centerX = size.width / 2 + 18;
    final centerY = size.height / 2 - 20;

    final letters = ['z', 'Z', 'z'];
    for (int i = 0; i < letters.length; i++) {
      final seed = (animationProgress + (i * 0.33)) % 1.0;
      final x = centerX + (seed * 22.0);
      final y = centerY - (seed * 35.0);
      final alpha = (sin(seed * pi) * 240).clamp(0, 255).toInt();

      final textSpan = TextSpan(
        text: letters[i],
        style: TextStyle(
          color: const Color(0xFF93C5FD).withAlpha(alpha),
          fontSize: 11.0 + (i * 3.5),
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant PetEffectsPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.animationProgress != animationProgress;
  }
}
