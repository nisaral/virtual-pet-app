import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'tone.dart';

class ValeColors {
  static const ink = Color(0xFF241B33);
  static const inkSoft = Color(0xFF5C516E);
  static const cream = Color(0xFFFFF6EA);
  static const creamDeep = Color(0xFFF4E4CC);
  static const gold = Color(0xFFE4B15A);
  static const goldDeep = Color(0xFFB97A2A);
  static const line = Color(0xFF2A2140);
  static const bloom = Color(0xFF3CAF62);
  static const tide = Color(0xFF3C92E6);
  static const ember = Color(0xFFFF6A3A);
}

Color elementColor(KinElement element) {
  return switch (element) {
    KinElement.bloom => ValeColors.bloom,
    KinElement.tide => ValeColors.tide,
    KinElement.ember => ValeColors.ember,
  };
}

class ValeText {
  static const display = TextStyle(
    fontFamily: 'Fredoka',
    fontWeight: FontWeight.w600,
    color: ValeColors.ink,
    fontSize: 42,
    height: 0.95,
  );
  static const title = TextStyle(
    fontFamily: 'Fredoka',
    fontWeight: FontWeight.w600,
    color: ValeColors.ink,
    fontSize: 24,
    height: 1.1,
  );
  static const body = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w600,
    color: ValeColors.ink,
    fontSize: 16,
    height: 1.35,
  );
  static const small = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w700,
    color: ValeColors.inkSoft,
    fontSize: 12.5,
    height: 1.25,
  );
}

enum ValeGlyph { bowl, brush, play, moon, path, mind, book, paw, back, leaf, drop, flame, star }

class ValeGlyphMark extends StatelessWidget {
  const ValeGlyphMark({super.key, required this.glyph, this.size = 26, this.color = ValeColors.ink});

  final ValeGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(glyph, color));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final ValeGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case ValeGlyph.bowl:
        canvas.drawArc(Rect.fromLTWH(w * 0.12, h * 0.28, w * 0.76, h * 0.5), 0, math.pi, false, paint);
        canvas.drawLine(Offset(w * 0.18, h * 0.55), Offset(w * 0.82, h * 0.55), paint);
      case ValeGlyph.brush:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.5, h * 0.36), width: w * 0.2, height: h * 0.4),
            const Radius.circular(4),
          ),
          fill,
        );
        canvas.drawLine(Offset(w * 0.4, h * 0.68), Offset(w * 0.4, h * 0.86), paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.68), Offset(w * 0.5, h * 0.92), paint);
        canvas.drawLine(Offset(w * 0.6, h * 0.68), Offset(w * 0.6, h * 0.86), paint);
      case ValeGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.32, h * 0.22)
            ..lineTo(w * 0.78, h * 0.5)
            ..lineTo(w * 0.32, h * 0.78)
            ..close(),
          fill,
        );
      case ValeGlyph.moon:
        canvas.drawCircle(Offset(w * 0.46, h * 0.5), w * 0.28, paint);
        canvas.drawCircle(Offset(w * 0.58, h * 0.42), w * 0.22, Paint()..color = const Color(0xFFFFF6EA));
      case ValeGlyph.path:
        canvas.drawLine(Offset(w * 0.18, h * 0.76), Offset(w * 0.4, h * 0.48), paint);
        canvas.drawLine(Offset(w * 0.4, h * 0.48), Offset(w * 0.58, h * 0.64), paint);
        canvas.drawLine(Offset(w * 0.58, h * 0.64), Offset(w * 0.82, h * 0.26), paint);
      case ValeGlyph.mind:
        canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.26, paint);
        canvas.drawCircle(Offset(w * 0.42, h * 0.44), 1.7, fill);
        canvas.drawCircle(Offset(w * 0.58, h * 0.44), 1.7, fill);
        canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.12), 0.2, 1.2, false, paint);
      case ValeGlyph.book:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.18, w * 0.56, h * 0.64), const Radius.circular(3)),
          paint,
        );
        canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.5, h * 0.8), paint);
      case ValeGlyph.paw:
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.64), width: w * 0.36, height: h * 0.28), fill);
        canvas.drawCircle(Offset(w * 0.32, h * 0.38), w * 0.09, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.09, fill);
        canvas.drawCircle(Offset(w * 0.68, h * 0.38), w * 0.09, fill);
      case ValeGlyph.back:
        canvas.drawLine(Offset(w * 0.68, h * 0.24), Offset(w * 0.32, h * 0.5), paint);
        canvas.drawLine(Offset(w * 0.32, h * 0.5), Offset(w * 0.68, h * 0.76), paint);
      case ValeGlyph.leaf:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.8)
            ..quadraticBezierTo(w * 0.12, h * 0.42, w * 0.5, h * 0.16)
            ..quadraticBezierTo(w * 0.88, h * 0.42, w * 0.5, h * 0.8),
          fill,
        );
      case ValeGlyph.drop:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.14)
            ..quadraticBezierTo(w * 0.88, h * 0.5, w * 0.5, h * 0.86)
            ..quadraticBezierTo(w * 0.12, h * 0.5, w * 0.5, h * 0.14),
          fill,
        );
      case ValeGlyph.flame:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.12)
            ..quadraticBezierTo(w * 0.9, h * 0.5, w * 0.62, h * 0.86)
            ..quadraticBezierTo(w * 0.5, h * 0.66, w * 0.38, h * 0.86)
            ..quadraticBezierTo(w * 0.1, h * 0.5, w * 0.5, h * 0.12),
          fill,
        );
      case ValeGlyph.star:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? w * 0.38 : w * 0.16;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final point = Offset(w * 0.5 + radius * math.cos(angle), h * 0.52 + radius * math.sin(angle));
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        star.close();
        canvas.drawPath(star, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class ValeButton extends StatefulWidget {
  const ValeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  State<ValeButton> createState() => _ValeButtonState();
}

class _ValeButtonState extends State<ValeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              ValeTone.play(ValeSound.tap);
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.filled ? ValeColors.ink : ValeColors.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.filled ? ValeColors.ink : ValeColors.goldDeep, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 0, offset: Offset(0, 4))],
            ),
            child: widget.expand
                ? SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: ValeText.title.copyWith(
                          fontSize: 18,
                          color: widget.filled ? ValeColors.cream : ValeColors.ink,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      widget.label,
                      style: ValeText.title.copyWith(
                        fontSize: 16,
                        color: widget.filled ? ValeColors.cream : ValeColors.ink,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class IconOrb extends StatelessWidget {
  const IconOrb({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.tint = ValeColors.gold,
  });

  final ValeGlyph glyph;
  final String label;
  final VoidCallback onPressed;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ValeTone.play(ValeSound.tap);
        onPressed();
      },
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, tint.withValues(alpha: 0.85)],
                ),
                border: Border.all(color: ValeColors.ink, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 0)],
              ),
              child: ValeGlyphMark(glyph: glyph, size: 24),
            ),
            const SizedBox(height: 4),
            Text(label, style: ValeText.small.copyWith(color: ValeColors.ink, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class GameDock extends StatelessWidget {
  const GameDock({super.key, required this.onFeed, required this.onBrush, required this.onPlay, required this.onRest, required this.onWalk});

  final VoidCallback onFeed;
  final VoidCallback onBrush;
  final VoidCallback onPlay;
  final VoidCallback onRest;
  final VoidCallback onWalk;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xCCFFF6EA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xAAFFFFFF), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x66FFFFFF), blurRadius: 0, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconOrb(glyph: ValeGlyph.bowl, label: 'Feed', onPressed: onFeed, tint: const Color(0xFFF0C48A)),
          IconOrb(glyph: ValeGlyph.brush, label: 'Brush', onPressed: onBrush, tint: const Color(0xFFD7ECC4)),
          IconOrb(glyph: ValeGlyph.play, label: 'Play', onPressed: onPlay, tint: const Color(0xFFFFC1D4)),
          IconOrb(glyph: ValeGlyph.moon, label: 'Rest', onPressed: onRest, tint: const Color(0xFFD5D0F5)),
          IconOrb(glyph: ValeGlyph.path, label: 'Walk', onPressed: onWalk, tint: const Color(0xFFBFE3FF)),
        ],
      ),
    );
  }
}

class DialogueBar extends StatefulWidget {
  const DialogueBar({
    super.key,
    required this.speaker,
    required this.text,
    required this.accent,
    required this.onAdvance,
  });

  final String speaker;
  final String text;
  final Color accent;
  final VoidCallback onAdvance;

  @override
  State<DialogueBar> createState() => _DialogueBarState();
}

class _DialogueBarState extends State<DialogueBar> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(DialogueBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _count = 0;
      _run();
    }
  }

  Future<void> _run() async {
    while (mounted && _count < widget.text.length) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() => _count += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _count.clamp(0, widget.text.length));
    return GestureDetector(
      onTap: widget.onAdvance,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        decoration: BoxDecoration(
          color: ValeColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ValeColors.ink, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 6), blurRadius: 0)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ValeColors.ink, width: 2),
                ),
                child: Text(widget.speaker, style: ValeText.small.copyWith(color: Colors.white)),
              ),
            ),
            Text(shown, style: ValeText.body),
          ],
        ),
      ),
    );
  }
}

class AsideBubble extends StatelessWidget {
  const AsideBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF5FFF6EA),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: ValeColors.ink, width: 2),
      ),
      child: Text(text, style: ValeText.body.copyWith(fontSize: 14.5)),
    );
  }
}

class HeartRow extends StatelessWidget {
  const HeartRow({super.key, required this.bond});

  final double bond;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              bond >= (i + 1) * 20
                  ? Icons.favorite
                  : (bond > i * 20 ? Icons.favorite : Icons.favorite_border),
              color: const Color(0xFFFF5D73),
              size: 18,
            ),
          ),
      ],
    );
  }
}

class StatLine extends StatelessWidget {
  const StatLine({super.key, required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: ValeText.small.copyWith(color: ValeColors.ink))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFE7D8C4)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (value / 100).clamp(0, 1),
                      child: DecoratedBox(decoration: BoxDecoration(color: color)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Text(statWord(value), style: ValeText.small, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class BackChip extends StatelessWidget {
  const BackChip({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ValeColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: ValeColors.ink, width: 2),
        ),
        child: const ValeGlyphMark(glyph: ValeGlyph.back, size: 18),
      ),
    );
  }
}

class CreamCard extends StatelessWidget {
  const CreamCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xF7FFF6EA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ValeColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 5), blurRadius: 0)],
      ),
      child: child,
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          BackChip(onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xEEFFF6EA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ValeColors.ink, width: 2),
                ),
                child: Text(title, style: ValeText.title.copyWith(fontSize: 20), overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatHearts extends StatefulWidget {
  const FloatHearts({super.key, required this.token});

  final int token;

  @override
  State<FloatHearts> createState() => _FloatHeartsState();
}

class _FloatHeartsState extends State<FloatHearts> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(FloatHearts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.value == 0) return const SizedBox.shrink();
          return Stack(
            children: [
              for (var i = 0; i < 5; i++)
                Positioned(
                  left: 40.0 + i * 48,
                  bottom: 120 + _controller.value * (80 + i * 12),
                  child: Opacity(
                    opacity: (1 - _controller.value).clamp(0, 1),
                    child: const Icon(Icons.favorite, color: Color(0xFFFF5D73), size: 18),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<bool> valeConfirm(BuildContext context, String title, String body) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: ValeColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: ValeColors.ink, width: 2.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: ValeText.title.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Text(body, style: ValeText.body),
              const SizedBox(height: 16),
              ValeButton(label: 'Yes', onPressed: () => Navigator.pop(context, true)),
              const SizedBox(height: 8),
              ValeButton(label: 'Not now', filled: false, onPressed: () => Navigator.pop(context, false)),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

ValeGlyph glyphForElement(KinElement element) {
  return switch (element) {
    KinElement.bloom => ValeGlyph.leaf,
    KinElement.tide => ValeGlyph.drop,
    KinElement.ember => ValeGlyph.flame,
  };
}

ValeGlyph glyphForIndex(int index) {
  return switch (index) {
    0 => ValeGlyph.leaf,
    1 => ValeGlyph.drop,
    2 => ValeGlyph.flame,
    _ => ValeGlyph.star,
  };
}
