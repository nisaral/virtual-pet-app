import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../vale/models.dart';

enum Face { down, up, left, right }

enum TileKind { grass, dirt, cobble, water, bridge, cliff, porch }

class BuildBox {
  const BuildBox(this.name, this.rect, this.kind);
  final String name;
  final Rect rect;
  final String kind;
}

class ActorDraw {
  const ActorDraw({
    required this.x,
    required this.y,
    required this.z,
    required this.face,
    required this.kind,
    required this.anim,
    required this.asleep,
    required this.label,
    this.stretch = 1,
    this.crest = false,
  });

  final double x;
  final double y;
  final double z;
  final Face face;
  final String kind;
  final double anim;
  final bool asleep;
  final String label;
  final double stretch;
  final bool crest;
}

enum SkyMood { sun, petals, rain, fireflies }

class PickupDraw {
  const PickupDraw(this.id, this.x, this.y, this.taken);
  final String id;
  final double x;
  final double y;
  final bool taken;
}

class OverworldFrame {
  const OverworldFrame({
    required this.phase,
    required this.anim,
    required this.camX,
    required this.camY,
    required this.zoom,
    required this.pet,
    required this.actors,
    required this.pickups,
    required this.thought,
    required this.lantern,
    required this.ball,
    required this.ballZ,
    required this.berriesLeft,
    this.weather = SkyMood.sun,
    this.planter = false,
    this.chimes = false,
    this.lure,
    this.buff = '',
  });

  final DayPhase phase;
  final double anim;
  final double camX;
  final double camY;
  final double zoom;
  final ActorDraw pet;
  final List<ActorDraw> actors;
  final List<PickupDraw> pickups;
  final String thought;
  final bool lantern;
  final Offset? ball;
  final double ballZ;
  final Set<int> berriesLeft;
  final SkyMood weather;
  final bool planter;
  final bool chimes;
  final Offset? lure;
  final String buff;
}

const double tile = 48;
const int mapTiles = 60;
const double mapSize = tile * mapTiles;

const homestead = BuildBox('Homestead', Rect.fromLTWH(6 * tile, 26 * tile, 7 * tile, 6 * tile), 'house');
const shed = BuildBox('Tool shed', Rect.fromLTWH(16 * tile, 22 * tile, 5 * tile, 4 * tile), 'shed');
const pavilion = BuildBox('Care pavilion', Rect.fromLTWH(10 * tile, 34 * tile, 6 * tile, 4 * tile), 'pavilion');

const treeSpots = <Offset>[
  Offset(4 * tile, 8 * tile),
  Offset(8 * tile, 6 * tile),
  Offset(12 * tile, 9 * tile),
  Offset(18 * tile, 7 * tile),
  Offset(22 * tile, 12 * tile),
  Offset(7 * tile, 14 * tile),
  Offset(14 * tile, 16 * tile),
  Offset(40 * tile, 18 * tile),
  Offset(46 * tile, 10 * tile),
  Offset(50 * tile, 8 * tile),
  Offset(44 * tile, 30 * tile),
  Offset(36 * tile, 48 * tile),
  Offset(18 * tile, 50 * tile),
  Offset(8 * tile, 46 * tile),
];

TileKind tileAt(int x, int y) {
  if (x < 0 || y < 0 || x >= mapTiles || y >= mapTiles) return TileKind.cliff;
  if (y < 3 || x < 2 || x > 57 || y > 57) return TileKind.cliff;
  if ((x > 38 && x < 46 && y > 16 && y < 40) || (x > 20 && x < 28 && y > 18 && y < 24)) return TileKind.water;
  if (x > 37 && x < 47 && y > 27 && y < 31) return TileKind.bridge;
  if ((x - 30).abs() < 2 || (y - 30).abs() < 2 && x > 8 && x < 52) return TileKind.cobble;
  if ((x > 6 && x < 24 && y > 6 && y < 16) || (x % 9 == 0 && y % 7 == 0)) return TileKind.dirt;
  if (homestead.rect.contains(Offset(x * tile, y * tile))) return TileKind.porch;
  return TileKind.grass;
}

String zoneAt(double x, double y) {
  if (y < 900) return 'woods';
  if (x > 1800 && y < 1100) return 'ruins';
  if (x > 1700) return 'brook';
  if (y > 2100) return 'meadow';
  if (shed.rect.inflate(80).contains(Offset(x, y))) return 'shed';
  if (homestead.rect.inflate(90).contains(Offset(x, y))) return 'house';
  if (pavilion.rect.inflate(70).contains(Offset(x, y))) return 'pavilion';
  return 'glen';
}

bool solidAt(double x, double y) {
  if (x < 80 || y < 80 || x > mapSize - 80 || y > mapSize - 80) return true;
  final door = Rect.fromCenter(center: Offset(homestead.rect.center.dx, homestead.rect.bottom - 8), width: 36, height: 28);
  for (final box in [homestead, shed]) {
    final body = box.rect.deflate(6);
    if (body.contains(Offset(x, y)) && !door.contains(Offset(x, y))) return true;
  }
  final tx = (x / tile).floor();
  final ty = (y / tile).floor();
  final kind = tileAt(tx, ty);
  return kind == TileKind.cliff || kind == TileKind.water;
}

class TileWindow {
  const TileWindow(this.minX, this.maxX, this.minY, this.maxY);
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
  int get count => (maxX - minX) * (maxY - minY);
}

/// Visible tile range for the camera, plus two tiles of padding.
TileWindow visibleTiles(OverworldFrame frame, Size size) {
  const pad = 2;
  final zoom = frame.zoom <= 0 ? 1.0 : frame.zoom;
  final halfW = size.width / (2 * zoom);
  final halfH = size.height / (2 * zoom * 0.78);
  final minX = ((frame.camX - halfW) / tile).floor() - pad;
  final maxX = ((frame.camX + halfW) / tile).ceil() + pad;
  final minY = ((frame.camY - halfH) / tile).floor() - pad;
  final maxY = ((frame.camY + halfH) / tile).ceil() + pad;
  return TileWindow(
    minX.clamp(0, mapTiles - 1),
    maxX.clamp(0, mapTiles),
    minY.clamp(0, mapTiles - 1),
    maxY.clamp(0, mapTiles),
  );
}

class OverworldRenderer {
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _line = Paint()..strokeCap = StrokeCap.round;

  Paint _f(Color color) {
    _fill
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = null
      ..strokeWidth = 1;
    return _fill;
  }

  Paint _s(Color color, double width) {
    _stroke
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;
    return _stroke;
  }

  bool _seen(OverworldFrame frame, Size size, double x, double y) {
    final window = visibleTiles(frame, size);
    final tx = (x / tile).floor();
    final ty = (y / tile).floor();
    return tx >= window.minX - 1 && tx < window.maxX + 1 && ty >= window.minY - 1 && ty < window.maxY + 1;
  }

  void paint(Canvas canvas, Size size, OverworldFrame frame) {
    final sky = switch (frame.phase) {
      DayPhase.dawn => const [Color(0xFFFFB08A), Color(0xFF9ED0FF)],
      DayPhase.day => const [Color(0xFF8ED4FF), Color(0xFFD7F3FF)],
      DayPhase.dusk => const [Color(0xFFFF8A5A), Color(0xFF6E4A86)],
      DayPhase.night => const [Color(0xFF10162E), Color(0xFF2A3358)],
    };
    canvas.drawRect(
      Offset.zero & size,
      _f(sky.first)..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky).createShader(Offset.zero & size),
    );
    Offset proj(double x, double y, double z) {
      final sx = (x - frame.camX) * frame.zoom + size.width / 2;
      final sy = (y - frame.camY) * frame.zoom * 0.78 - z * frame.zoom + size.height * 0.46;
      return Offset(sx, sy);
    }

    final window = visibleTiles(frame, size);
    for (var y = window.minY; y < window.maxY; y++) {
      for (var x = window.minX; x < window.maxX; x++) {
        _tile(canvas, proj(x * tile + 24, y * tile + 24, 0), tileAt(x, y), frame.anim, x, y, frame.zoom);
      }
    }

    final layers = <_Sort>[
      for (final spot in treeSpots)
        if (_seen(frame, size, spot.dx, spot.dy))
          _Sort(spot.dy + 40, (c) => _tree(c, proj(spot.dx, spot.dy, 0), frame.zoom, frame.anim, frame.berriesLeft.contains(treeSpots.indexOf(spot)))),
      _Sort(homestead.rect.bottom, (c) => _house(c, proj, frame)),
      _Sort(shed.rect.bottom, (c) => _shed(c, proj, frame)),
      _Sort(pavilion.rect.bottom, (c) => _pavilion(c, proj, frame)),
      for (final item in frame.pickups)
        if (!item.taken) _Sort(item.y, (c) => _pickup(c, proj(item.x, item.y, 10 + math.sin(frame.anim * 3 + item.x) * 4), item.id, frame.zoom)),
      if (frame.ball != null) _Sort(frame.ball!.dy, (c) => _ball(c, proj(frame.ball!.dx, frame.ball!.dy, frame.ballZ), frame.zoom)),
      for (final actor in frame.actors) _Sort(actor.y, (c) => _actor(c, proj(actor.x, actor.y, actor.z), actor, frame.zoom)),
      _Sort(frame.pet.y, (c) => _actor(c, proj(frame.pet.x, frame.pet.y, frame.pet.z), frame.pet, frame.zoom)),
    ];
    layers.sort((a, b) => a.y.compareTo(b.y));
    for (final layer in layers) {
      layer.draw(canvas);
    }
    if (frame.thought.isNotEmpty) {
      _bubble(canvas, proj(frame.pet.x, frame.pet.y, frame.pet.z + 78), frame.thought);
    }
    if (frame.lantern && (frame.phase == DayPhase.dusk || frame.phase == DayPhase.night)) {
      final o = proj(frame.pet.x, frame.pet.y, 0);
      canvas.drawCircle(o, 90 * frame.zoom, _f(const Color(0x33FFD27A)));
    }
    _weather(canvas, size, frame, proj);
    _reflection(canvas, frame, proj);
  }

  void _weather(Canvas canvas, Size size, OverworldFrame frame, Offset Function(double, double, double) proj) {
    if (frame.weather == SkyMood.sun && zoneAt(frame.pet.x, frame.pet.y) == 'woods') {
      final ray = _s(const Color(0x33FFE08A), 18);
      for (var i = 0; i < 4; i++) {
        final x = 40.0 + i * 90;
        canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), ray);
      }
    }
    if (frame.weather == SkyMood.petals) {
      for (var i = 0; i < 18; i++) {
        final x = (i * 67 + frame.anim * 24) % size.width;
        final y = (i * 41 + frame.anim * 30) % size.height;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 7, height: 4), _f(const Color(0xCCF2A3B5)));
      }
    }
    if (frame.weather == SkyMood.rain) {
      final streak = _s(const Color(0x889EC8EA), 1.4);
      for (var i = 0; i < 40; i++) {
        final x = (i * 37 + frame.anim * 80) % size.width;
        final y = (i * 53 + frame.anim * 140) % size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 8, y + 16), streak);
      }
      final ripple = proj(frame.pet.x, frame.pet.y, 0);
      canvas.drawCircle(ripple, 10 + (frame.anim * 20 % 18), _s(const Color(0x669EC8EA), 1.5));
    }
    if (frame.weather == SkyMood.fireflies || frame.phase == DayPhase.night) {
      for (var i = 0; i < 12; i++) {
        final x = (i * 80 + math.sin(frame.anim + i) * 20) % size.width;
        final y = (i * 60 + math.cos(frame.anim * 0.7 + i) * 16) % (size.height * 0.7);
        canvas.drawCircle(Offset(x, y), 2.2, _f(const Color(0xCCFFE08A)));
      }
      if (frame.phase == DayPhase.night || frame.phase == DayPhase.dusk) {
        canvas.drawRect(Offset.zero & size, _f(const Color(0x33101830)));
        canvas.drawCircle(proj(homestead.rect.center.dx, homestead.rect.center.dy, 20), 36, _f(const Color(0x44FFE08A)));
        canvas.drawCircle(proj(shed.rect.center.dx, shed.rect.center.dy, 10), 28, _f(const Color(0x33FFD27A)));
        if (zoneAt(frame.pet.x, frame.pet.y) == 'ruins') {
          canvas.drawCircle(proj(frame.pet.x, frame.pet.y, 0), 22, _f(const Color(0x667A4AD0)));
        }
      }
    }
  }

  void _reflection(Canvas canvas, OverworldFrame frame, Offset Function(double, double, double) proj) {
    final tx = (frame.pet.x / tile).floor();
    final ty = (frame.pet.y / tile).floor();
    var near = false;
    for (var y = ty - 1; y <= ty + 1 && !near; y++) {
      for (var x = tx - 1; x <= tx + 1; x++) {
        if (tileAt(x, y) == TileKind.water) near = true;
      }
    }
    if (!near) return;
    canvas.save();
    final o = proj(frame.pet.x, frame.pet.y + 18, 0);
    canvas.translate(o.dx, o.dy);
    canvas.scale(1, -0.45);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28, height: 16), _f(const Color(0x663C92C8)));
    canvas.restore();
  }

  void _tile(Canvas canvas, Offset o, TileKind kind, double anim, int x, int y, double zoom) {
    final w = tile * zoom * 1.05;
    final h = tile * zoom * 0.62;
    final rect = Rect.fromCenter(center: o, width: w, height: h);
    final color = switch (kind) {
      TileKind.grass => ((x + y).isEven) ? const Color(0xFF67B84E) : const Color(0xFF5AAA45),
      TileKind.dirt => const Color(0xFFC6A36A),
      TileKind.cobble => const Color(0xFFB7B4AE),
      TileKind.water => Color.lerp(const Color(0xFF3C92C8), const Color(0xFF7ED0EA), (math.sin(anim * 2 + x * 0.4 + y) * 8 + 8) / 16)!,
      TileKind.bridge => const Color(0xFF8C5A32),
      TileKind.cliff => const Color(0xFF6E7A62),
      TileKind.porch => const Color(0xFFD9C4A0),
    };
    canvas.drawOval(rect, _f(color));
    if (kind == TileKind.grass && (x + y) % 3 == 0) {
      _line
        ..color = const Color(0xFF3E8A38)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final bend = math.sin(anim * 3 + x) * 3;
      canvas.drawLine(o.translate(-4, 2), o.translate(-6 + bend, -6), _line);
      canvas.drawLine(o, o.translate(bend, -8), _line);
      canvas.drawLine(o.translate(4, 2), o.translate(6 + bend, -5), _line);
    }
    if (kind == TileKind.cobble) {
      canvas.drawOval(rect.deflate(3), _s(const Color(0x44999999), 1));
    }
    if (kind == TileKind.water) {
      canvas.drawArc(rect.deflate(6), anim + x, 1.2, false, _s(const Color(0xCCFFFFFF), 1.5));
    }
    if (kind == TileKind.bridge) {
      canvas.drawLine(rect.topLeft, rect.topRight, _s(const Color(0xFF5C3A22), 2));
    }
    if (kind == TileKind.cliff) {
      canvas.drawOval(rect.shift(const Offset(0, 6)), _f(const Color(0x55000000)));
      canvas.drawOval(rect, _f(const Color(0xFF8C947C)));
    }
  }

  void _house(Canvas canvas, Offset Function(double, double, double) proj, OverworldFrame frame) {
    final base = homestead.rect;
    final a = proj(base.left, base.bottom, 0);
    final b = proj(base.right, base.bottom, 0);
    final c = proj(base.right, base.top, 0);
    final d = proj(base.left, base.top, 0);
    final wall = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy - 28)..lineTo(d.dx, d.dy - 28)..close();
    canvas.drawPath(wall.shift(const Offset(8, 10)), _f(const Color(0x44000000)));
    canvas.drawPath(wall, _f(const Color(0xFFF3E2C4)));
    canvas.drawPath(wall, _s(const Color(0xFF5C3A22), 2));
    final roof = Path()
      ..moveTo(d.dx, d.dy - 28)
      ..lineTo(c.dx, c.dy - 28)
      ..lineTo((c.dx + d.dx) / 2, d.dy - 78)
      ..close();
    canvas.drawPath(roof, _f(const Color(0xFFB94A3A)));
    final door = proj(base.center.dx, base.bottom - 10, 0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: door.translate(0, -16), width: 16, height: 26), const Radius.circular(3)), _f(const Color(0xFF6B3E22)));
    final glow = frame.phase == DayPhase.night || frame.phase == DayPhase.dusk ? const Color(0xFFFFE08A) : const Color(0xFF9EC8EA);
    canvas.drawCircle(proj(base.left + 40, base.top + 50, 36), 6, _f(glow));
    canvas.drawCircle(proj(base.right - 40, base.top + 50, 36), 6, _f(glow));
    final smoke = proj(base.right - 28, base.top + 20, 70 + math.sin(frame.anim) * 6);
    canvas.drawCircle(smoke, 7, _f(const Color(0x88FFFFFF)));
    canvas.drawCircle(smoke.translate(6, -10), 5, _f(const Color(0x66FFFFFF)));
    _label(canvas, proj(base.center.dx, base.top, 90), 'Homestead');
    if (frame.chimes) {
      final hook = proj(base.center.dx, base.top + 10, 48);
      final sway = math.sin(frame.anim * 2) * 6;
      canvas.drawLine(hook, hook.translate(sway, 16), _s(const Color(0xFFE7C07A), 2));
      canvas.drawCircle(hook.translate(sway, 18), 3, _f(const Color(0xFFFFE08A)));
    }
    if (frame.planter) {
      final box = proj(base.center.dx + 70, base.bottom + 20, 0);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: box, width: 28, height: 14), const Radius.circular(3)), _f(const Color(0xFF8C5A32)));
      canvas.drawCircle(box.translate(0, -8), 5, _f(const Color(0xFF3CAF62)));
    }
    if (frame.lure != null) {
      final glow = proj(frame.lure!.dx, frame.lure!.dy, 8);
      canvas.drawCircle(glow, 16 + math.sin(frame.anim * 3) * 3, _f(const Color(0x667A4AD0)));
    }
  }

  void _shed(Canvas canvas, Offset Function(double, double, double) proj, OverworldFrame frame) {
    final base = shed.rect;
    final a = proj(base.left, base.bottom, 0);
    final b = proj(base.right, base.bottom, 0);
    final c = proj(base.right, base.top, 0);
    final d = proj(base.left, base.top, 0);
    final wall = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy - 18)..lineTo(d.dx, d.dy - 18)..close();
    canvas.drawPath(wall.shift(const Offset(6, 8)), _f(const Color(0x44000000)));
    canvas.drawPath(wall, _f(const Color(0xFFC48A52)));
    canvas.drawPath(wall, _s(const Color(0xFF4A301C), 2));
    canvas.drawLine(d.translate(0, -18), c.translate(0, -18), _s(const Color(0xFF6E5640), 8));
    final rack = proj(base.left - 10, base.bottom - 8, 16);
    canvas.drawLine(rack, rack.translate(0, -22), _s(const Color(0xFF5C4030), 3));
    canvas.drawCircle(rack.translate(0, -24), 5, _f(const Color(0xFF3CAF62)));
    canvas.drawCircle(rack.translate(10, -18), 5, _f(const Color(0xFFFF9A3C)));
    final lantern = proj(base.right + 8, base.center.dy, 22);
    canvas.drawCircle(lantern, 5, _f(frame.phase == DayPhase.night ? const Color(0xFFFFE08A) : const Color(0xFFD9C07A)));
    _label(canvas, proj(base.center.dx, base.top, 70), 'Shed');
  }

  void _pavilion(Canvas canvas, Offset Function(double, double, double) proj, OverworldFrame frame) {
    final base = pavilion.rect;
    for (final corner in [base.topLeft, base.topRight, base.bottomLeft, base.bottomRight]) {
      final p = proj(corner.dx, corner.dy, 0);
      canvas.drawLine(p, p.translate(0, -36), _s(const Color(0xFF6B4226), 4));
    }
    final roof = Path()
      ..moveTo(proj(base.left, base.top, 36).dx, proj(base.left, base.top, 36).dy)
      ..lineTo(proj(base.right, base.top, 36).dx, proj(base.right, base.top, 36).dy)
      ..lineTo(proj(base.right, base.bottom, 36).dx, proj(base.right, base.bottom, 36).dy)
      ..lineTo(proj(base.left, base.bottom, 36).dx, proj(base.left, base.bottom, 36).dy)
      ..close();
    canvas.drawPath(roof, _f(const Color(0xCC8C5A32)));
    final bowl = proj(base.center.dx - 20, base.center.dy, 0);
    canvas.drawOval(Rect.fromCenter(center: bowl, width: 26, height: 12), _f(const Color(0xFF8C5A32)));
    final trough = proj(base.center.dx + 24, base.center.dy, 0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: trough, width: 28, height: 12), const Radius.circular(4)), _f(const Color(0xFF7FB7D6)));
    _label(canvas, proj(base.center.dx, base.top, 64), 'Care');
  }

  void _tree(Canvas canvas, Offset o, double zoom, double anim, bool fruit) {
    final sway = math.sin(anim * 1.4 + o.dx) * 3;
    canvas.drawOval(Rect.fromCenter(center: o.translate(8, 8), width: 28 * zoom, height: 10 * zoom), _f(const Color(0x33000000)));
    final trunk = _s(const Color(0xFF6A4630), 7 * zoom);
    canvas.drawLine(o, o.translate(sway, -28 * zoom), trunk);
    canvas.drawLine(o.translate(-8 * zoom, 2), o.translate(8 * zoom, 4), _s(const Color(0xFF5A4030), 3));
    final greens = [const Color(0xFF2E7D42), const Color(0xFF3E9850), const Color(0xFF57B15C), const Color(0xFF26683A), const Color(0xFF78C46E)];
    final blobs = [Offset(-16, -46), Offset(10, -52), Offset(0, -64), Offset(18, -40), Offset(-8, -36)];
    for (var i = 0; i < blobs.length; i++) {
      canvas.drawCircle(o.translate(blobs[i].dx * zoom + sway, blobs[i].dy * zoom), (16 + (i % 3) * 4) * zoom, _f(greens[i]));
    }
    if (fruit) {
      canvas.drawCircle(o.translate(-6 * zoom, -30 * zoom), 4 * zoom, _f(const Color(0xFFE85D5D)));
      canvas.drawCircle(o.translate(12 * zoom, -34 * zoom), 4 * zoom, _f(const Color(0xFF7A4AD0)));
    }
  }

  void _pickup(Canvas canvas, Offset o, String id, double zoom) {
    final color = switch (id) {
      'dewberry' => const Color(0xFF6A4AD8),
      'mushroom' => const Color(0xFFE7C07A),
      'pebble' => const Color(0xFFD7E4EA),
      'twig' => const Color(0xFF8C5A32),
      'seed' => const Color(0xFF3CAF62),
      _ => const Color(0xFFE85D5D),
    };
    canvas.drawCircle(o.translate(0, -6), 8 * zoom, _f(const Color(0x66FFFFFF)));
    canvas.drawCircle(o, 6 * zoom, _f(color));
    canvas.drawCircle(o, 6 * zoom, _s(const Color(0xFF241B33), 1.4));
  }

  void _ball(Canvas canvas, Offset o, double zoom) {
    canvas.drawCircle(o.translate(3, 8), 7 * zoom, _f(const Color(0x44000000)));
    canvas.drawCircle(o, 8 * zoom, _f(const Color(0xFFFF9A3C)));
  }

  void _actor(Canvas canvas, Offset o, ActorDraw actor, double zoom) {
    final squash = actor.z > 4 ? 0.86 : (1 + math.sin(actor.anim * 10) * 0.04 * actor.stretch);
    final s = zoom * (actor.kind == 'botanist' || actor.kind == 'trainer' ? 1.05 : 0.95) * squash;
    final bob = math.sin(actor.anim * 8) * (actor.asleep ? 0 : 2);
    final lag = math.sin(actor.anim * 6) * 4 * actor.stretch;
    canvas.drawOval(Rect.fromCenter(center: o.translate(0, 6), width: (30 - actor.z * 0.02) * s, height: 10 * s), _f(const Color(0x44000000)));
    final coat = switch (actor.kind) {
      'aqua' => const Color(0xFF4AA0E0),
      'ember' => const Color(0xFFFF7A3C),
      'sprout' => const Color(0xFFF4E7C4),
      'botanist' => const Color(0xFF3E6B4A),
      'trainer' => const Color(0xFF2458A6),
      _ => const Color(0xFFF4E7C4),
    };
    final accent = switch (actor.kind) {
      'aqua' => const Color(0xFFD7F1FF),
      'ember' => const Color(0xFFFFD15A),
      'sprout' => const Color(0xFF3CAF62),
      'botanist' => const Color(0xFFE7C07A),
      'trainer' => const Color(0xFFFFF6EA),
      _ => const Color(0xFF3CAF62),
    };
    final human = actor.kind == 'botanist' || actor.kind == 'trainer';
    final flip = actor.face == Face.left ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(o.dx, o.dy - actor.z * 0.2 - bob);
    if (actor.face == Face.left || actor.face == Face.right) canvas.scale(flip, 1);
    if (human) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -6 * s), width: 16 * s, height: 26 * s), Radius.circular(6 * s)), _f(coat));
      canvas.drawCircle(Offset(0, -24 * s), 8 * s, _f(const Color(0xFFF0C8A8)));
      canvas.drawRect(Rect.fromCenter(center: Offset(0, -30 * s), width: 16 * s, height: 6 * s), _f(accent));
    } else {
      final stride = actor.asleep ? 0.0 : math.sin(actor.anim * 9);
      canvas.drawOval(Rect.fromCenter(center: Offset(-8 * s, 8 * s + stride * 4), width: 10 * s, height: 6 * s), _f(coat));
      canvas.drawOval(Rect.fromCenter(center: Offset(8 * s, 8 * s - stride * 4), width: 10 * s, height: 6 * s), _f(coat));
      canvas.drawCircle(Offset(lag, 10 * s), 6 * s, _f(accent));
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28 * s, height: 20 * s), _f(coat));
      canvas.drawCircle(Offset(0, -16 * s), 12 * s, _f(coat));
      if (actor.kind == 'sprout') {
        canvas.drawOval(Rect.fromCenter(center: Offset(-6 * s, -30 * s), width: 6 * s, height: 16 * s), _f(accent));
        canvas.drawOval(Rect.fromCenter(center: Offset(6 * s, -30 * s), width: 6 * s, height: 16 * s), _f(accent));
      } else if (actor.kind == 'ember') {
        canvas.drawCircle(Offset(0, -28 * s), 5 * s, _f(accent));
      }
      final shut = actor.asleep || actor.face == Face.up || (actor.anim % 4) > 3.85;
      if (!shut) {
        canvas.drawCircle(Offset(-4 * s, -16 * s), 1.8 * s, _f(const Color(0xFF241B33)));
        canvas.drawCircle(Offset(4 * s, -16 * s), 1.8 * s, _f(const Color(0xFF241B33)));
      }
    }
    if (actor.crest) {
      canvas.drawCircle(Offset(0, -34 * s), 18 * s, _s(const Color(0xFFFFE08A), 2));
    }
    canvas.restore();
    if (actor.label.isNotEmpty) _label(canvas, o.translate(-18, -52 * s), actor.label);
  }

  void _bubble(Canvas canvas, Offset o, String thought) {
    final text = switch (thought) {
      'berry' => '🍓',
      'friend' => '♥',
      'ball' => '●',
      'bed' => 'z',
      '♪' => '♪',
      _ => '?',
    };
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 28, height: 22), const Radius.circular(8)), _f(Colors.white));
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(fontSize: 12, color: Color(0xFF241B33))), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, o.translate(-tp.width / 2, -tp.height / 2));
  }

  void _label(Canvas canvas, Offset o, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }
}

class _Sort {
  _Sort(this.y, this.draw);
  final double y;
  final void Function(Canvas) draw;
}

class MiniRadar extends StatelessWidget {
  const MiniRadar({
    super.key,
    required this.pet,
    required this.others,
    required this.onOpen,
  });

  final Offset pet;
  final List<Offset> others;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: 92,
        height: 72,
        margin: const EdgeInsets.only(top: 6, right: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC1C3A28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white70),
        ),
        child: CustomPaint(
          painter: _RadarPainter(pet: pet, others: others),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.pet, required this.others});
  final Offset pet;
  final List<Offset> others;

  @override
  void paint(Canvas canvas, Size size) {
    Offset map(Offset p) => Offset(p.dx / mapSize * size.width, p.dy / mapSize * size.height);
    canvas.drawCircle(map(pet), 3.5, Paint()..color = const Color(0xFFFFE08A));
    for (final o in others) {
      canvas.drawCircle(map(o), 2.2, Paint()..color = const Color(0xFF8FD4F2));
    }
    canvas.drawCircle(map(Offset(homestead.rect.center.dx, homestead.rect.center.dy)), 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
