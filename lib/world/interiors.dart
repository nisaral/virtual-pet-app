import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cozy rooms drawn in the same 2.5D ink-and-paint language as the glen.
class InteriorRoom extends StatelessWidget {
  const InteriorRoom({super.key, required this.kind, required this.anim, required this.crest, this.dreams = const []});

  final String kind;
  final double anim;
  final bool crest;
  final List<String> dreams;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomPainter(kind: kind, anim: anim, crest: crest, dreams: dreams),
      child: const SizedBox.expand(),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.kind, required this.anim, required this.crest, required this.dreams});
  final String kind;
  final double anim;
  final bool crest;
  final List<String> dreams;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Paint()..color = const Color(0xFFC4A36A);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF3A2418));
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.62), width: size.width * 0.86, height: size.height * 0.42), floor);
    if (kind == 'house') {
      _house(canvas, size);
    } else {
      _shed(canvas, size);
    }
  }

  void _house(Canvas canvas, Size size) {
    final fire = 0.5 + math.sin(anim * 8) * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.12, size.height * 0.34, 70, 54), const Radius.circular(6)),
      Paint()..color = const Color(0xFF5C3A22),
    );
    canvas.drawCircle(Offset(size.width * 0.12 + 35, size.height * 0.34 + 36), 10 + fire * 4, Paint()..color = const Color(0xFFFFB15A));
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.68, size.height * 0.58), width: 86, height: 28), Paint()..color = const Color(0xFF3E8F4E));
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.68, size.height * 0.56), width: 54, height: 16), Paint()..color = const Color(0xFFB7E39A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.62, size.height * 0.4, 64, 28), const Radius.circular(4)),
      Paint()..color = const Color(0xFF8C5A32),
    );
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.4 + 8), 6, Paint()..color = const Color(0xFFE85D5D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(36, size.height * 0.28, 48, 70), const Radius.circular(4)),
      Paint()..color = const Color(0xFF6B4226),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(44, size.height * 0.3 + i * 16, 28, 8), Paint()..color = const Color(0xFFE7C07A));
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.78), width: 54, height: 18), Paint()..color = const Color(0xFFD9C4A0));
    if (crest) {
      canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.5), 22, Paint()..color = const Color(0x55FFE08A)..style = PaintingStyle.stroke..strokeWidth = 3);
    }
    if (dreams.isNotEmpty) {
      final icon = dreams[(anim ~/ 1.2).floor() % dreams.length];
      final tp = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * 0.42, size.height * 0.22));
    }
  }

  void _shed(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.5), width: 160, height: 46), const Radius.circular(6)),
      Paint()..color = const Color(0xFF8C5A32),
    );
    canvas.drawCircle(Offset(size.width / 2 - 40, size.height * 0.46), 8, Paint()..color = const Color(0xFFD7E4EA));
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.46), width: 22, height: 6), Paint()..color = const Color(0xFF6B4226));
    canvas.drawCircle(Offset(size.width / 2 + 40, size.height * 0.46), 8, Paint()..color = const Color(0xFF3CAF62));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.32), 8, Paint()..color = const Color(0xFFFFE08A));
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.78), width: 54, height: 18), Paint()..color = const Color(0xFFD9C4A0));
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) => oldDelegate.anim != anim || oldDelegate.kind != kind;
}
