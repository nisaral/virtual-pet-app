import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui; // for ImageFilter (depth of field)
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';

/// Advanced "Claymation / Soft 3D" pet visual per the new spec.
/// - No placeholders: fully procedural toon/clay aesthetic.
/// - Growth morph: growthProgress (0.0 baby -> 1.0 adult) lerps proportions (blend-shape approximation).
/// - Mood-driven: colors, face expression, idle bob intensity.
/// - Species-specific shapes (whale horizontal with tail, cow rounded with ears, snake long/wavy).
/// - Toon/soft look: layered soft shadows, rounded forms, pastel fills, subtle gradients.
/// - Interactive grooming: tap different zones (head/body) to "brush" (simulates raycast hit).
///   Call onGroom(zone) to trigger action + memory.
class PetVisual extends StatefulWidget {
  const PetVisual({
    super.key,
    required this.pet,
    this.onGroom,
    this.size = 240.0,
    this.lastMemoryType, // for contextual idle (sway vs bounce based on recent memory)
  });

  final PetState pet;
  final void Function(String zone)? onGroom; // 'head' or 'body'
  final double size;
  final String? lastMemoryType; // e.g. 'groom', 'stressed', 'play' for emotional idle

  @override
  State<PetVisual> createState() => _PetVisualState();
}

class _PetVisualState extends State<PetVisual> with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  String? _lastGroomZone;
  double _groomFlash = 0.0;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onGroom == null) return;

    final local = details.localPosition;
    final center = Offset(widget.size / 2, widget.size / 2);
    final relative = local - center;

    // Simple zone detection (approximates raycast on mesh)
    String zone;
    if (relative.dy < -widget.size * 0.15) {
      zone = 'head';
    } else {
      zone = 'body';
    }

    setState(() {
      _lastGroomZone = zone;
      _groomFlash = 1.0;
    });

    widget.onGroom!(zone);

    // Flash decay
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _groomFlash = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final growth = widget.pet.growthProgress.clamp(0.0, 1.0);
    final mood = widget.pet.moodDescription;
    final isHappy = mood == 'ecstatic' || mood == 'happy';
    final hygiene = widget.pet.stats.cleanliness;
    final lastMem = widget.lastMemoryType ?? '';

    // Contextual idle: if recent memory suggests stress/comfort, use slow sway instead of fast bounce (spec)
    final isComfortContext = lastMem.toLowerCase().contains('stress') || lastMem.toLowerCase().contains('groom') || lastMem.toLowerCase().contains('pet');
    final bobAmplitude = isComfortContext ? 4.0 : (isHappy ? 9.0 : 3.5);

    // Emotional shake for low hygiene (no generic bars - behavior based)
    final shake = hygiene < 40 ? math.sin(DateTime.now().millisecondsSinceEpoch / 120) * (1.0 - hygiene / 100) * 3.0 : 0.0;

    return GestureDetector(
      onTapDown: _handleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size + 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Living space with Depth-of-Field (Gaussian blur on background for 3D pop - spec)
            ClipRRect(
              borderRadius: BorderRadius.circular(140),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5), // light DoF
                child: _LivingSpaceHint(
                  petType: widget.pet.petType,
                  growth: growth,
                  timeOfDay: DateTime.now().hour,
                ),
              ),
            ),

            // Main clay pet with squash/stretch, procedural lighting, emotional shake, contextual idle
            AnimatedBuilder(
              animation: _idleController,
              builder: (context, child) {
                final t = _idleController.value * 2 * math.pi;
                final bobOffset = math.sin(t) * bobAmplitude * (widget.pet.stats.happiness / 100) + shake;
                
                // Squash & Stretch (classic principle for clay feel - spec)
                // Deform in direction of movement/bob or groom
                final squash = 1.0 + (bobOffset / 25.0) * (isComfortContext ? 0.6 : 1.0);
                final stretch = 1.0 / squash.clamp(0.85, 1.15);

                return Transform.translate(
                  offset: Offset(0, bobOffset),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1.0, stretch, 1.0), // vertical squash/stretch
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _ClayPetPainter(
                        petType: widget.pet.petType,
                        growth: growth,
                        mood: mood,
                        isSleeping: widget.pet.isSleeping,
                        happiness: widget.pet.stats.happiness,
                        hygiene: hygiene,
                        groomZone: _lastGroomZone,
                        groomFlash: _groomFlash,
                        lastMemoryType: widget.lastMemoryType,
                        timeOfDay: DateTime.now().hour, // for procedural lighting & shadows
                      ),
                    ),
                  ),
                );
              },
            ),

            // Groom flash particles (clay "dust" / hearts for emotional connection)
            if (_groomFlash > 0.1)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GroomParticlesPainter(flash: _groomFlash, zone: _lastGroomZone),
                  ),
                ),
              ),

            // Subtle toon highlight rim
            Positioned(
              top: widget.size * 0.12,
              child: Container(
                width: widget.size * 0.65,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.25), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Procedural Claymation / Soft 3D pet painter.
/// Approximates blend shapes via lerped proportions (growth 0->1).
/// Toon shader feel via flat colors + soft shadows + rounded everything.
class _ClayPetPainter extends CustomPainter {
  _ClayPetPainter({
    required this.petType,
    required this.growth,
    required this.mood,
    required this.isSleeping,
    required this.happiness,
    required this.hygiene,
    this.groomZone,
    this.groomFlash = 0.0,
    this.lastMemoryType,
    this.timeOfDay = 12,
  });

  final PetType petType;
  final double growth; // 0.0 baby -> 1.0 adult
  final String mood;
  final bool isSleeping;
  final double happiness;
  final double hygiene;
  final String? groomZone;
  final double groomFlash;
  final String? lastMemoryType;
  final int timeOfDay; // for procedural lighting & shadows (spec)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final progress = growth;

    // Base clay color per species + mood tint
    Color baseClay = _getBaseClayColor();
    if (mood == 'sad' || mood == 'starving') {
      baseClay = Color.lerp(baseClay, Colors.grey.shade400, 0.25)!;
    }

    // Growth morph: baby = squishy/round, adult = more defined proportions
    final babyFactor = (1 - progress);
    final bodyScaleX = 1.0 + (petType == PetType.whale ? progress * 0.35 : progress * 0.15);
    final bodyScaleY = 0.85 + progress * 0.25;

    // Soft multiple shadows for clay depth (toon/claymation feel)
    _drawClayShadow(canvas, center, size, baseClay, bodyScaleX, bodyScaleY, babyFactor);

    // Main body
    final bodyPath = _buildBodyPath(center, size, bodyScaleX, bodyScaleY, petType, progress);
    final bodyPaint = Paint()
      ..color = baseClay
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Toon rim / soft edge
    final rimPaint = Paint()
      ..color = baseClay.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawPath(bodyPath, rimPaint);

    // Face / features (morph with growth + mood)
    _drawFace(canvas, center, size, progress, mood, isSleeping, happiness, petType);

    // Species details (horns/ears for cow, spout/tail for whale, pattern for snake)
    _drawSpeciesDetails(canvas, center, size, progress, baseClay, petType);

    // Hygiene "mess" overlay if low
    if (hygiene < 45) {
      final messPaint = Paint()..color = Colors.brown.withOpacity(0.15);
      canvas.drawCircle(center.translate(0, 8), size.width * 0.18, messPaint);
    }

    // Groom highlight (soft clay "brushed" area)
    if (groomFlash > 0.05 && groomZone != null) {
      final highlightCenter = groomZone == 'head'
          ? center.translate(0, -size.height * 0.12)
          : center.translate(0, size.height * 0.08);
      final hlPaint = Paint()
        ..color = Colors.white.withOpacity(groomFlash * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(highlightCenter, size.width * 0.22, hlPaint);
    }
  }

  Color _getBaseClayColor() {
    switch (petType) {
      case PetType.whale:
        return const Color(0xFF7EB8DA); // soft ocean clay blue
      case PetType.cow:
        return const Color(0xFFF5D5A8); // warm farm clay cream
      case PetType.snake:
        return const Color(0xFF9ACB9A); // gentle jungle clay green
    }
  }

  void _drawClayShadow(Canvas canvas, Offset center, Size size, Color base, double sx, double sy, double babyF) {
    final isDay = timeOfDay > 6 && timeOfDay < 20;
    final shadowOffset = (isDay ? 11.0 : 15.0) + babyF * 4;
    final blur = isDay ? 14.0 : 26.0; // sharp day, soft blurred night (ImageFilter style)
    final opacity = isDay ? 0.16 : 0.24;

    final shadowPaint = Paint()
      ..color = (isDay ? Colors.black : Colors.blueGrey.shade900).withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    final shadowPath = _buildBodyPath(
      center.translate(shadowOffset * (isDay ? 0.55 : 0.7), shadowOffset * 1.15),
      size,
      sx * 0.96,
      sy * 0.92,
      petType,
      growth,
    );
    canvas.drawPath(shadowPath, shadowPaint);

    // Second softer layer for depth
    final softShadow = Paint()
      ..color = Colors.black.withOpacity(isDay ? 0.07 : 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 1.6);
    canvas.drawPath(
      _buildBodyPath(center.translate(shadowOffset * 1.25, shadowOffset * 1.7), size, sx * 1.02, sy * 0.95, petType, growth),
      softShadow,
    );
  }

  Path _buildBodyPath(Offset c, Size s, double sx, double sy, PetType type, double prog) {
    final path = Path();
    final w = s.width * 0.48 * sx;
    final h = s.height * 0.38 * sy;

    if (type == PetType.whale) {
      // Horizontal whale body, grows longer with prog
      final len = w * (0.9 + prog * 0.55);
      path.addOval(Rect.fromCenter(center: c, width: len, height: h * 0.82));
      // Tail
      path.moveTo(c.dx - len * 0.48, c.dy);
      path.quadraticBezierTo(c.dx - len * 0.72, c.dy - 18, c.dx - len * 0.82, c.dy + (prog * 12));
      path.quadraticBezierTo(c.dx - len * 0.72, c.dy + 22, c.dx - len * 0.48, c.dy);
    } else if (type == PetType.cow) {
      // Rounded cow body, grows taller
      final bodyH = h * (0.95 + prog * 0.2);
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w * 0.92, height: bodyH),
        Radius.circular(42 + prog * 8),
      ));
    } else {
      // Snake: long curved body that gets longer and more elegant
      final len = w * (1.1 + prog * 0.7);
      path.moveTo(c.dx - len * 0.5, c.dy);
      path.quadraticBezierTo(c.dx, c.dy - 22 - prog * 8, c.dx + len * 0.52, c.dy + prog * 6);
      path.quadraticBezierTo(c.dx + len * 0.2, c.dy + 18, c.dx - len * 0.3, c.dy);
      path.close();
      // Thicken
      final thick = Path()..addPath(path, Offset.zero);
      // Simple fill approximation
      path.addOval(Rect.fromCenter(center: c.translate(len * 0.1, 0), width: 38, height: 26));
    }
    return path;
  }

  void _drawFace(Canvas canvas, Offset c, Size s, double prog, String mood, bool sleeping, double happy, PetType type) {
    final eyeY = c.dy - s.height * (0.08 + prog * 0.03);
    final eyeSpacing = s.width * (0.14 + prog * 0.04);
    final eyeSize = 7.5 + prog * 2.5;

    final eyePaint = Paint()..color = sleeping ? const Color(0xFF5D4E37) : const Color(0xFF3D2B1F);
    final whitePaint = Paint()..color = Colors.white.withOpacity(0.9);

    // Eyes (baby = bigger relative head, adult = more balanced)
    final leftEye = c.translate(-eyeSpacing, eyeY);
    final rightEye = c.translate(eyeSpacing, eyeY);

    canvas.drawCircle(leftEye, eyeSize, whitePaint);
    canvas.drawCircle(rightEye, eyeSize, whitePaint);
    canvas.drawCircle(leftEye, eyeSize * 0.6, eyePaint);
    canvas.drawCircle(rightEye, eyeSize * 0.6, eyePaint);

    // Mouth / expression (toon style, mood reactive)
    final mouthY = c.dy + s.height * (0.06 + prog * 0.02);
    final mouthPaint = Paint()
      ..color = const Color(0xFF5C4033)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    Path mouth;
    if (sleeping) {
      mouth = Path()..addOval(Rect.fromCenter(center: Offset(c.dx, mouthY), width: 11, height: 4));
    } else if (mood.contains('sad') || mood == 'restless') {
      mouth = Path()
        ..moveTo(c.dx - 10, mouthY - 1)
        ..quadraticBezierTo(c.dx, mouthY + 6, c.dx + 10, mouthY - 1);
    } else {
      // Happy / content smile, stronger with happiness
      final smile = (happy - 40) / 80.0;
      mouth = Path()
        ..moveTo(c.dx - 9, mouthY)
        ..quadraticBezierTo(c.dx, mouthY + 7 + smile * 4, c.dx + 9, mouthY);
    }
    canvas.drawPath(mouth, mouthPaint);

    // Blush / warmth for high affection
    if (happy > 75 && !sleeping) {
      final blush = Paint()..color = const Color(0xFFE8A0A0).withOpacity(0.35);
      canvas.drawOval(Rect.fromCenter(center: leftEye.translate(-4, 6), width: 9, height: 5), blush);
      canvas.drawOval(Rect.fromCenter(center: rightEye.translate(4, 6), width: 9, height: 5), blush);
    }
  }

  void _drawSpeciesDetails(Canvas canvas, Offset c, Size s, double prog, Color clay, PetType type) {
    final detailPaint = Paint()..color = clay.withOpacity(0.55);

    if (type == PetType.whale) {
      // Spout (whale)
      canvas.drawCircle(c.translate(0, -s.height * 0.22), 5 + prog * 2, detailPaint);
      // Flippers
      final flip = Paint()..color = clay.withOpacity(0.7);
      canvas.drawOval(Rect.fromCenter(center: c.translate(-s.width * 0.28, 4), width: 22, height: 11), flip);
      canvas.drawOval(Rect.fromCenter(center: c.translate(s.width * 0.28, 4), width: 22, height: 11), flip);
    } else if (type == PetType.cow) {
      // Ears + horns (soft clay)
      final earPaint = Paint()..color = clay.withOpacity(0.65);
      canvas.drawOval(Rect.fromCenter(center: c.translate(-s.width * 0.26, -s.height * 0.18), width: 16, height: 11), earPaint);
      canvas.drawOval(Rect.fromCenter(center: c.translate(s.width * 0.26, -s.height * 0.18), width: 16, height: 11), earPaint);
      // Simple spots for character
      final spot = Paint()..color = const Color(0xFF8C6642).withOpacity(0.25);
      canvas.drawCircle(c.translate(-8, 2), 7, spot);
      canvas.drawCircle(c.translate(14, -6), 5, spot);
    } else {
      // Snake pattern / tongue hint
      final pattern = Paint()..color = clay.withOpacity(0.4);
      for (int i = -1; i <= 1; i++) {
        canvas.drawCircle(c.translate(8.0 * i, 2), 3.5, pattern);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClayPetPainter oldDelegate) {
    return oldDelegate.growth != growth ||
        oldDelegate.mood != mood ||
        oldDelegate.groomFlash != groomFlash ||
        oldDelegate.hygiene != hygiene;
  }
}

class _GroomParticlesPainter extends CustomPainter {
  _GroomParticlesPainter({required this.flash, this.zone});
  final double flash;
  final String? zone;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(flash * 0.7);
    final heartPaint = Paint()..color = const Color(0xFFFF8A80).withOpacity(flash * 0.85);

    final cx = size.width * 0.5;
    final cy = size.height * 0.48 + (zone == 'head' ? -18 : 12);

    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * 6.28 + (flash * 2);
      final r = 14 + i * 1.5;
      final ox = cx + math.cos(angle) * r;
      final oy = cy + math.sin(angle) * (r * 0.6) - flash * 6;
      canvas.drawCircle(Offset(ox, oy), 2.5 + flash * 1.5, paint);
      if (i % 2 == 0) {
        canvas.drawCircle(Offset(ox + 3, oy - 3), 3.5, heartPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GroomParticlesPainter oldDelegate) => oldDelegate.flash != flash;
}

/// Dynamic living space with procedural lighting (time of day) + Depth of Field already applied in parent.
/// Day: warm bright sharp shadows. Night: cool muted soft-blurred (spec).
class _LivingSpaceHint extends StatelessWidget {
  const _LivingSpaceHint({
    required this.petType,
    required this.growth,
    required this.timeOfDay,
  });

  final PetType petType;
  final double growth;
  final int timeOfDay;

  @override
  Widget build(BuildContext context) {
    final isDay = timeOfDay > 6 && timeOfDay < 20;

    Color bg;
    if (petType == PetType.whale) {
      bg = isDay ? const Color(0xFF9ED1F0) : const Color(0xFF4A6FA5);
    } else if (petType == PetType.cow) {
      bg = isDay ? const Color(0xFFC8E6B3) : const Color(0xFF6B7B5E);
    } else {
      bg = isDay ? const Color(0xFFB8D4A8) : const Color(0xFF5C6B57);
    }

    // Subtle time tint for lighting
    final lightTint = isDay 
        ? Colors.orange.withOpacity(0.08) 
        : Colors.blueGrey.withOpacity(0.15);

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(140),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDay ? 0.12 : 0.22),
            blurRadius: isDay ? 14 : 28, // sharper day, softer night
            offset: Offset(0, isDay ? 5 : 9),
          ),
        ],
      ),
      child: Container(color: lightTint), // procedural lighting tint
    );
  }
}
