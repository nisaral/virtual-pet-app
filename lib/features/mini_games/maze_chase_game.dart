import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';

/// Maze Chase (Snake) - Draw path for snake to treat (Energy boost + gift).
/// Simple drawing + auto-follow prototype.
/// Future: Unity navmesh + path drawing in cave prefab, Blend Tree "slither".
class MazeChaseGame extends ConsumerStatefulWidget {
  const MazeChaseGame({super.key});

  @override
  ConsumerState<MazeChaseGame> createState() => _MazeChaseGameState();
}

class _MazeChaseGameState extends ConsumerState<MazeChaseGame> {
  List<Offset> path = [];
  bool completed = false;

  void _addPoint(Offset p) {
    setState(() => path.add(p));
  }

  void _complete() {
    if (completed) return;
    setState(() => completed = true);
    ref.read(petControllerProvider.notifier).performAction('play');
    ref.read(petControllerProvider.notifier).awardGift('treat');
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treat reached! Energy + Treat gift for habitat.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Maze Chase (Snake Cave)'),
      content: SizedBox(
        width: 280,
        height: 300,
        child: GestureDetector(
          onPanUpdate: (d) => _addPoint(d.localPosition),
          onPanEnd: (_) => _complete(),
          child: CustomPaint(
            painter: _PathPainter(path),
            child: Container(color: Colors.brown[100]), // Cave bg (Unity prefab)
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Exit'))],
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> path;
  _PathPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final paint = Paint()..color = Colors.green..strokeWidth = 4..style = PaintingStyle.stroke;
    final p = Path()..moveTo(path.first.dx, path.first.dy);
    for (var pt in path.skip(1)) p.lineTo(pt.dx, pt.dy);
    canvas.drawPath(p, paint);
    // "Snake" head + "treat"
    if (path.isNotEmpty) {
      canvas.drawCircle(path.last, 10, Paint()..color = Colors.green[800]!);
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 8, Paint()..color = Colors.orange);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.path != path;
}