import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

enum SceneKind { valley, den, pedestal, arena, sprite }

class LivingScene extends StatefulWidget {
  const LivingScene({
    super.key,
    required this.species,
    required this.stage,
    required this.mood,
    required this.pose,
    required this.poseToken,
    required this.phase,
    this.kind = SceneKind.den,
    this.parade = false,
    this.prop,
    this.flip = false,
    this.onNuzzle,
  });

  final SpeciesId species;
  final int stage;
  final Mood mood;
  final KinPose pose;
  final int poseToken;
  final DayPhase phase;
  final SceneKind kind;
  final bool parade;
  final String? prop;
  final bool flip;
  final VoidCallback? onNuzzle;

  @override
  State<LivingScene> createState() => _LivingSceneState();
}

class _LivingSceneState extends State<LivingScene> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _shot;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _shot = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
  }

  @override
  void didUpdateWidget(LivingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.poseToken != oldWidget.poseToken) {
      _shot.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _shot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onNuzzle,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _shot]),
        builder: (context, _) {
          return CustomPaint(
            painter: _GlenPainter(
              species: widget.species,
              stage: widget.stage,
              mood: widget.mood,
              pose: widget.pose,
              phase: widget.phase,
              kind: widget.kind,
              parade: widget.parade,
              prop: widget.prop,
              flip: widget.flip,
              t: _idle.value,
              shot: Curves.easeOut.transform(_shot.value),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _GlenPainter extends CustomPainter {
  _GlenPainter({
    required this.species,
    required this.stage,
    required this.mood,
    required this.pose,
    required this.phase,
    required this.kind,
    required this.parade,
    required this.prop,
    required this.flip,
    required this.t,
    required this.shot,
  });

  final SpeciesId species;
  final int stage;
  final Mood mood;
  final KinPose pose;
  final DayPhase phase;
  final SceneKind kind;
  final bool parade;
  final String? prop;
  final bool flip;
  final double t;
  final double shot;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == SceneKind.sprite) {
      final anchor = Offset(size.width * 0.5, size.height * 0.84);
      _shadow(canvas, anchor, 78);
      _kin(canvas, anchor, species, stage, mood, pose, t, shot, flip: flip, scale: 1);
      return;
    }
    final sky = _sky(kind == SceneKind.arena ? DayPhase.dusk : phase);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky.top, sky.mid, sky.ground],
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );
    _celestial(canvas, size, sky);
    _clouds(canvas, size);
    _hills(canvas, size, sky.hillFar, 0.46, 0.08);
    _hills(canvas, size, sky.hill, 0.56, 0.12);
    final groundTop = size.height * (kind == SceneKind.pedestal ? 0.72 : 0.6);
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop),
      Paint()..color = sky.ground,
    );
    if (kind != SceneKind.pedestal && kind != SceneKind.arena) {
      _path(canvas, size);
      _flowers(canvas, size);
    }
    if (kind == SceneKind.arena) _ring(canvas, size);
    if (parade) {
      _parade(canvas, size);
    } else {
      final anchor = Offset(size.width * 0.5, size.height * (kind == SceneKind.pedestal ? 0.7 : 0.74));
      if (kind == SceneKind.den || kind == SceneKind.pedestal) {
        _rug(canvas, anchor, kind == SceneKind.pedestal);
      }
      _prop(canvas, anchor);
      _shadow(canvas, anchor, 70 + stage * 8);
      _kin(
        canvas,
        anchor,
        species,
        stage,
        mood,
        pose,
        t,
        shot,
        flip: flip,
        scale: kind == SceneKind.arena ? 0.78 : 1,
      );
      if (kind == SceneKind.den || kind == SceneKind.valley) _tufts(canvas, size);
    }
    if (kind == SceneKind.den) _porch(canvas, size);
    if (kind == SceneKind.den || kind == SceneKind.valley) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0x00000000), Colors.black.withValues(alpha: 0.18)],
          ).createShader(Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22)),
      );
    }
  }

  void _parade(Canvas canvas, Size size) {
    const ids = SpeciesId.values;
    for (var i = 0; i < ids.length; i++) {
      final anchor = Offset(size.width * (0.22 + i * 0.28), size.height * 0.76);
      _shadow(canvas, anchor, 48);
      _kin(
        canvas,
        anchor,
        ids[i],
        1,
        Mood.glad,
        KinPose.idle,
        (t + i * 0.18) % 1,
        0,
        scale: 0.62,
      );
    }
  }

  void _celestial(Canvas canvas, Size size, _Sky sky) {
    final night = phase == DayPhase.night && kind != SceneKind.arena;
    final center = night
        ? Offset(size.width * 0.78, size.height * 0.16)
        : Offset(size.width * (0.18 + t * 0.08), size.height * 0.16);
    canvas.drawCircle(center, night ? 16 : 28, Paint()..color = night ? const Color(0xFFF4E7C4) : sky.sun);
    if (!night) {
      canvas.drawCircle(
        center,
        48,
        Paint()..color = sky.sun.withValues(alpha: 0.25),
      );
    }
    if (night || phase == DayPhase.dusk) {
      final rnd = math.Random(7);
      for (var i = 0; i < 16; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = rnd.nextDouble() * size.height * 0.4;
        final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2 + i));
        canvas.drawCircle(Offset(x, y), 1.4, Paint()..color = Colors.white.withValues(alpha: twinkle));
      }
    }
  }

  void _clouds(Canvas canvas, Size size) {
    if (phase == DayPhase.night) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: phase == DayPhase.dusk ? 0.35 : 0.82);
    for (var i = 0; i < 3; i++) {
      final x = ((0.12 + i * 0.34 + t * 0.04) % 1.1) * size.width;
      final y = size.height * (0.12 + i * 0.06);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 90, height: 28), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 26, y - 8), width: 48, height: 26), paint);
    }
  }

  void _hills(Canvas canvas, Size size, Color color, double baseline, double height) {
    final path = Path()..moveTo(0, size.height * baseline);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * (baseline - height),
      size.width * 0.5,
      size.height * (baseline - height * 0.3),
    );
    path.quadraticBezierTo(
      size.width * 0.78,
      size.height * (baseline - height * 0.9),
      size.width,
      size.height * (baseline - height * 0.2),
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _path(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.46, size.height);
    path.quadraticBezierTo(size.width * 0.42, size.height * 0.78, size.width * 0.5, size.height * 0.64);
    path.quadraticBezierTo(size.width * 0.58, size.height * 0.78, size.width * 0.62, size.height);
    canvas.drawPath(path, Paint()..color = const Color(0xFFE7D3A4).withValues(alpha: 0.85));
  }

  void _flowers(Canvas canvas, Size size) {
    const spots = [
      (0.12, 0.7),
      (0.2, 0.8),
      (0.78, 0.72),
      (0.86, 0.82),
      (0.3, 0.86),
      (0.7, 0.88),
      (0.08, 0.9),
      (0.92, 0.68),
    ];
    for (var i = 0; i < spots.length; i++) {
      final center = Offset(size.width * spots[i].$1, size.height * spots[i].$2);
      final color = i.isEven ? const Color(0xFFFF8FAB) : const Color(0xFFFFD56A);
      canvas.drawCircle(center, 5, Paint()..color = color);
      canvas.drawCircle(center.translate(0, -6), 4, Paint()..color = color.withValues(alpha: 0.9));
      canvas.drawLine(
        center.translate(0, 4),
        center.translate(0, 14),
        Paint()
          ..color = const Color(0xFF2E7A3A)
          ..strokeWidth = 2,
      );
    }
    if (species == SpeciesId.marrow) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.18, size.height * 0.78), width: 70, height: 28),
        Paint()..color = const Color(0xFF8FD4F2).withValues(alpha: 0.85),
      );
    }
  }

  void _ring(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.58);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.78, height: size.height * 0.22),
      Paint()..color = const Color(0xFF6B4A32),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width * 0.78, height: size.height * 0.22),
      Paint()
        ..color = const Color(0xFFE7B556)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _rug(Canvas canvas, Offset anchor, bool pedestal) {
    final width = pedestal ? 190.0 : 210.0;
    final rect = Rect.fromCenter(center: anchor.translate(0, 8), width: width, height: pedestal ? 46 : 36);
    canvas.drawOval(rect, Paint()..color = const Color(0xFFF7E2C0));
    canvas.drawOval(
      rect.deflate(7),
      Paint()
        ..color = _accent(species).withValues(alpha: 0.85),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFFE4B15A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pedestal ? 4 : 3,
    );
  }

  void _prop(Canvas canvas, Offset anchor) {
    if (kind != SceneKind.den || prop == null) return;
    final pulse = 0.55 + 0.45 * math.sin(t * math.pi * 2);
    final glow = Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.35 + 0.35 * pulse);
    if (prop == 'bowl') {
      final c = anchor.translate(-78, 4);
      canvas.drawCircle(c, 22, glow);
      canvas.drawOval(Rect.fromCenter(center: c, width: 36, height: 16), Paint()..color = const Color(0xFF8C5A34));
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -4), width: 28, height: 12), Paint()..color = const Color(0xFFF0C48A));
    } else if (prop == 'brush') {
      final c = anchor.translate(84, -6);
      canvas.drawCircle(c, 20, glow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 10, height: 28), const Radius.circular(4)),
        Paint()..color = const Color(0xFFC9842A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 16), width: 16, height: 10), const Radius.circular(3)),
        Paint()..color = const Color(0xFF6B4424),
      );
    } else if (prop == 'toy') {
      final c = anchor.translate(86, 6);
      canvas.drawCircle(c, 20, glow);
      canvas.drawCircle(c, 12, Paint()..color = const Color(0xFFFF6A3A));
      canvas.drawCircle(c.translate(-3, -3), 3, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
  }

  void _tufts(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3E9A45);
    for (final x in [0.04, 0.14, 0.88, 0.96]) {
      final base = Offset(size.width * x, size.height * 0.94);
      final path = Path()
        ..moveTo(base.dx - 10, base.dy)
        ..quadraticBezierTo(base.dx - 8, base.dy - 22, base.dx, base.dy - 8)
        ..quadraticBezierTo(base.dx + 8, base.dy - 26, base.dx + 12, base.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _porch(Canvas canvas, Size size) {
    final wood = Paint()..color = const Color(0xFF8A5A32);
    final edge = Paint()..color = const Color(0xFFC48A52);
    canvas.drawRect(Rect.fromLTWH(0, 0, 16, size.height), wood);
    canvas.drawRect(Rect.fromLTWH(size.width - 16, 0, 16, size.height), wood);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 14), wood);
    canvas.drawRect(Rect.fromLTWH(16, 0, 3, size.height), edge);
    canvas.drawRect(Rect.fromLTWH(size.width - 19, 0, 3, size.height), edge);
  }

  void _shadow(Canvas canvas, Offset anchor, double width) {
    canvas.drawOval(
      Rect.fromCenter(center: anchor.translate(0, 6), width: width, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
  }

  void _kin(
    Canvas canvas,
    Offset anchor,
    SpeciesId id,
    int stage,
    Mood mood,
    KinPose pose,
    double t,
    double shot, {
    bool flip = false,
    double scale = 1,
  }) {
    final bob = math.sin(t * math.pi * 2) * (mood == Mood.weary || mood == Mood.sulking ? 2.5 : 7);
    final hop = (pose == KinPose.hop || pose == KinPose.cheer || pose == KinPose.eat) ? math.sin(shot * math.pi) * (pose == KinPose.eat ? 8 : 26) : 0.0;
    final stageScale = [0.9, 1.04, 1.18][stage.clamp(0, 2)] * scale;
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy - bob - hop);
    if (flip) canvas.scale(-1, 1);
    canvas.scale(stageScale, stageScale * (pose == KinPose.sleep ? 0.96 : 1));
    final shut = mood == Mood.asleep || pose == KinPose.groom || pose == KinPose.sleep || (math.sin(t * math.pi * 2) > 0.92 && pose == KinPose.idle);
    final look = math.sin(t * math.pi * 2) * 1.4;
    final droop = mood == Mood.sulking || mood == Mood.weary;
    switch (id) {
      case SpeciesId.pipkin:
        _pipkin(canvas, stage, shut, look, droop, pose, t);
      case SpeciesId.marrow:
        _marrow(canvas, stage, shut, look, droop, pose, t);
      case SpeciesId.solbit:
        _solbit(canvas, stage, shut, look, droop, pose, t);
    }
    if (pose == KinPose.sleep || mood == Mood.asleep) _zzz(canvas);
    if (pose == KinPose.cheer || mood == Mood.radiant) _sparkles(canvas, t);
    canvas.restore();
  }

  void _pipkin(Canvas canvas, int stage, bool shut, double look, bool droop, KinPose pose, double t) {
    const body = Color(0xFF7EBE62);
    const shade = Color(0xFF4E8B3C);
    const belly = Color(0xFFFFF6E8);
    const leaf = Color(0xFF2C8A44);
    _tail(canvas, const Offset(-46, -36), 14 + stage * 2.0, body, shade);
    _body(canvas, const Offset(0, -52), 78, 64, body, shade, belly);
    _ear(canvas, const Offset(-18, -92), -0.55 + (droop ? 0.7 : 0) + math.sin(t * math.pi * 2) * 0.05, 18, 58 + stage * 6, body, const Color(0xFFF4A8B8));
    _ear(canvas, const Offset(16, -92), 0.4 + (droop ? -0.45 : 0) - math.sin(t * math.pi * 2) * 0.04, 16, 52 + stage * 5, body, const Color(0xFFF4A8B8));
    _head(canvas, const Offset(4, -98), 36 + stage * 1.5, body, shade);
    _sprout(canvas, Offset(4, -132 - stage * 2), stage, leaf);
    if (stage >= 1) _blossom(canvas, const Offset(26, -118), const Color(0xFFFF8FAB));
    if (stage >= 2) {
      _blossom(canvas, const Offset(-16, -128), const Color(0xFFFFD56A));
      _mantle(canvas, body);
    }
    _face(canvas, const Offset(8, -96), shut, look, const Color(0xFFD0893A), droop, pose);
  }

  void _marrow(Canvas canvas, int stage, bool shut, double look, bool droop, KinPose pose, double t) {
    const body = Color(0xFF6AADD8);
    const shade = Color(0xFF3A78A8);
    const belly = Color(0xFFF4FBFF);
    _body(canvas, const Offset(0, -46), 86, 58, body, shade, belly);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-30, -18), width: 28, height: 16), Paint()..color = shade);
    canvas.drawOval(Rect.fromCenter(center: const Offset(32, -18), width: 28, height: 16), Paint()..color = shade);
    _head(canvas, const Offset(6, -86), 34 + stage.toDouble(), body, shade);
    _shell(canvas, Offset(8, -70 + (stage > 1 ? -4 : 0)), 12 + stage * 2);
    if (stage >= 1) _scarf(canvas, const Color(0xFF2E8F6B));
    if (stage >= 2) {
      canvas.drawCircle(const Offset(6, -124), 7, Paint()..color = const Color(0xFFF7F3EA));
      canvas.drawCircle(const Offset(6, -124), 7, Paint()..color = const Color(0xFFE4B15A)..style = PaintingStyle.stroke..strokeWidth = 2);
      _wave(canvas);
    }
    _face(canvas, const Offset(10, -84), shut, look, const Color(0xFF217E78), droop, pose);
  }

  void _solbit(Canvas canvas, int stage, bool shut, double look, bool droop, KinPose pose, double t) {
    const body = Color(0xFFFF955C);
    const shade = Color(0xFFD86434);
    const belly = Color(0xFFFFF3E8);
    final wag = math.sin(t * math.pi * 2) * 0.18;
    canvas.save();
    canvas.translate(-34, -40);
    canvas.rotate(-0.6 + wag);
    _tail(canvas, Offset.zero, 18 + stage * 3, body, shade);
    canvas.drawCircle(Offset(-8, 6), 8 + stage.toDouble(), Paint()..color = const Color(0xFFFF4E2A));
    canvas.restore();
    _body(canvas, const Offset(0, -50), 72, 60, body, shade, belly);
    _ear(canvas, const Offset(-16, -96), -0.35 + (droop ? 0.45 : 0), 16, 36, body, const Color(0xFFFFC1A8));
    _ear(canvas, const Offset(20, -96), 0.35 - (droop ? 0.45 : 0), 16, 36, body, const Color(0xFFFFC1A8));
    _head(canvas, const Offset(4, -94), 34 + stage.toDouble(), body, shade);
    _sunMark(canvas, Offset(4, -112 - stage * 2));
    if (stage >= 1) _scarf(canvas, const Color(0xFFFFD15A));
    if (stage >= 2) _mane(canvas);
    _face(canvas, const Offset(8, -92), shut, look, const Color(0xFF7A4030), droop, pose);
  }

  void _body(Canvas canvas, Offset center, double w, double h, Color fill, Color shade, Color belly) {
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawOval(rect, Paint()..shader = RadialGradient(center: const Alignment(-0.35, -0.45), radius: 1.05, colors: [Color.lerp(fill, Colors.white, 0.35)!, fill, shade]).createShader(rect));
    canvas.drawOval(rect, _line(2.4));
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(4, 6), width: w * 0.62, height: h * 0.62),
      Paint()..color = belly,
    );
  }

  void _head(Canvas canvas, Offset center, double radius, Color fill, Color shade) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.5), colors: [Color.lerp(fill, Colors.white, 0.4)!, fill, shade]).createShader(rect));
    canvas.drawCircle(center, radius, _line(2.4));
  }

  void _ear(Canvas canvas, Offset pivot, double angle, double w, double h, Color fill, Color inner) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -h / 2), width: w, height: h), const Radius.circular(12));
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(rect, _line(2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -h / 2 + 2), width: w * 0.48, height: h * 0.62), const Radius.circular(10)),
      Paint()..color = inner,
    );
    canvas.restore();
  }

  void _tail(Canvas canvas, Offset center, double radius, Color fill, Color shade) {
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(center, radius, _line(2));
    canvas.drawCircle(center.translate(-radius * 0.2, -radius * 0.2), radius * 0.35, Paint()..color = Color.lerp(fill, Colors.white, 0.4)!);
    canvas.drawCircle(center.translate(radius * 0.15, radius * 0.1), radius * 0.2, Paint()..color = shade.withValues(alpha: 0.35));
  }

  void _face(Canvas canvas, Offset center, bool shut, double look, Color iris, bool droop, KinPose pose) {
    _eye(canvas, center.translate(-12, droop ? 2 : 0), 11, shut: shut, look: look, iris: iris);
    _eye(canvas, center.translate(12, droop ? 2 : 0), 11, shut: shut, look: look, iris: iris);
    canvas.drawOval(Rect.fromCenter(center: center.translate(0, 10), width: 8, height: 6), Paint()..color = const Color(0xFF2A2140));
    final smile = Path();
    final y = droop || pose == KinPose.sulk ? 20.0 : 18.0;
    smile.moveTo(center.dx - 8, center.dy + y);
    smile.quadraticBezierTo(
      center.dx,
      center.dy + y + (droop || pose == KinPose.sulk ? -6 : 8),
      center.dx + 8,
      center.dy + y,
    );
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF2A2140)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final blush = Paint()..color = const Color(0xFFFF8B9A).withValues(alpha: shut ? 0.55 : 0.38);
    canvas.drawOval(Rect.fromCenter(center: center.translate(-22, 8), width: 12, height: 7), blush);
    canvas.drawOval(Rect.fromCenter(center: center.translate(22, 8), width: 12, height: 7), blush);
  }

  void _eye(Canvas canvas, Offset center, double size, {required bool shut, required double look, required Color iris}) {
    if (shut) {
      final path = Path()
        ..moveTo(center.dx - size * 0.55, center.dy)
        ..quadraticBezierTo(center.dx, center.dy + size * 0.35, center.dx + size * 0.55, center.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2A2140)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawOval(Rect.fromCenter(center: center, width: size * 1.2, height: size * 1.4), Paint()..color = const Color(0xFFFFFBF7));
    final pupil = center.translate(look, size * 0.08);
    canvas.drawCircle(pupil, size * 0.48, Paint()..color = iris);
    canvas.drawCircle(pupil.translate(0, size * 0.08), size * 0.24, Paint()..color = const Color(0xFF241C33));
    canvas.drawCircle(pupil.translate(-size * 0.16, -size * 0.18), size * 0.12, Paint()..color = Colors.white);
    canvas.drawCircle(pupil.translate(size * 0.16, 0.4), size * 0.05, Paint()..color = Colors.white);
  }

  void _sprout(Canvas canvas, Offset tip, int stage, Color leaf) {
    canvas.drawLine(tip, tip.translate(0, -10 - stage * 3), Paint()..color = leaf..strokeWidth = 3..strokeCap = StrokeCap.round);
    final path = Path()
      ..moveTo(tip.dx, tip.dy - 10 - stage * 3)
      ..quadraticBezierTo(tip.dx + 14, tip.dy - 18, tip.dx + 6, tip.dy - 4);
    canvas.drawPath(path, Paint()..color = leaf..style = PaintingStyle.fill);
    if (stage >= 2) {
      canvas.drawCircle(tip.translate(0, -18), 6, Paint()..color = const Color(0xFFFF8FAB));
    }
  }

  void _blossom(Canvas canvas, Offset center, Color color) {
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(center + Offset(math.cos(angle) * 5, math.sin(angle) * 5), 3.5, Paint()..color = color);
    }
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFFFFF1C9));
  }

  void _mantle(Canvas canvas, Color color) {
    final path = Path()
      ..moveTo(-28, -78)
      ..quadraticBezierTo(-48, -40, -30, -20)
      ..quadraticBezierTo(-10, -50, -8, -78)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.95));
    canvas.drawPath(path, _line(2));
  }

  void _shell(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF3D2A4));
    canvas.drawCircle(center, radius, _line(2));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.6),
      0.4,
      2.2,
      false,
      Paint()
        ..color = const Color(0xFFC9842A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _scarf(Canvas canvas, Color color) {
    final path = Path()
      ..moveTo(-18, -70)
      ..quadraticBezierTo(0, -58, 20, -72)
      ..quadraticBezierTo(8, -60, -10, -62)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _wave(Canvas canvas) {
    final path = Path()
      ..moveTo(-20, -40)
      ..quadraticBezierTo(-8, -48, 2, -40)
      ..quadraticBezierTo(12, -32, 22, -42);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFEFF8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sunMark(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFFFD15A));
    canvas.drawCircle(center, 6, _line(1.5));
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        center + Offset(math.cos(angle) * 7, math.sin(angle) * 7),
        center + Offset(math.cos(angle) * 11, math.sin(angle) * 11),
        Paint()
          ..color = const Color(0xFFFFD15A)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _mane(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFB15A).withValues(alpha: 0.9);
    for (final dx in [-20.0, -8.0, 6.0, 16.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(dx, -122), width: 14, height: 22), paint);
    }
  }

  void _zzz(Canvas canvas) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'z z',
        style: TextStyle(color: Color(0xFF241B33), fontSize: 16, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(28, -150));
  }

  void _sparkles(Canvas canvas, double t) {
    final paint = Paint()..color = const Color(0xFFFFE08A);
    for (var i = 0; i < 4; i++) {
      final angle = t * math.pi * 2 + i * 1.4;
      canvas.drawCircle(Offset(math.cos(angle) * 52, -90 + math.sin(angle) * 24), 2.4, paint);
    }
  }

  Paint _line(double width) {
    return Paint()
      ..color = const Color(0xFF2A2140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;
  }

  Color _accent(SpeciesId id) {
    return switch (id) {
      SpeciesId.pipkin => const Color(0xFF7EBE62),
      SpeciesId.marrow => const Color(0xFF6AADD8),
      SpeciesId.solbit => const Color(0xFFFF955C),
    };
  }

  _Sky _sky(DayPhase phase) {
    return switch (phase) {
      DayPhase.dawn => const _Sky(Color(0xFFFFB08A), Color(0xFFFFE0C2), Color(0xFF8ED07A), Color(0xFF69B56C), Color(0xFFD5C2B0), Color(0xFFFFF1D2)),
      DayPhase.day => const _Sky(Color(0xFF79C4FF), Color(0xFFD9F3FF), Color(0xFF7BC86F), Color(0xFF4FA85C), Color(0xFFB7D7C6), Color(0xFFFFF4C8)),
      DayPhase.dusk => const _Sky(Color(0xFF3C3A86), Color(0xFFFF9468), Color(0xFF4E8A52), Color(0xFF3C6244), Color(0xFF7D6A98), Color(0xFFFFD0A8)),
      DayPhase.night => const _Sky(Color(0xFF14182E), Color(0xFF2A3464), Color(0xFF1C3B2C), Color(0xFF163024), Color(0xFF2A3358), Color(0xFFF4E7C4)),
    };
  }

  @override
  bool shouldRepaint(covariant _GlenPainter oldDelegate) => true;
}

class _Sky {
  const _Sky(this.top, this.mid, this.ground, this.hill, this.hillFar, this.sun);
  final Color top;
  final Color mid;
  final Color ground;
  final Color hill;
  final Color hillFar;
  final Color sun;
}
