import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';

/// Target Catch (Whale/Orca) - Integrated mini-game prototype (post-testing spec).
/// User drags "whale" to catch falling bubbles/stars in the habitat.
/// Directly increases Happiness + awards gift (shell for 3D decoration).
/// 
/// Current: Simple Flutter gesture game (tap/drag canvas).
/// Future (Unity pivot): Raycast in 3D pond prefab, Blend Tree "swim" anim driven by stats.
/// Launch from habitat gestures (no separate menu bloat). Updates via PetController.
class TargetCatchGame extends ConsumerStatefulWidget {
  const TargetCatchGame({super.key});

  @override
  ConsumerState<TargetCatchGame> createState() => _TargetCatchGameState();
}

class _TargetCatchGameState extends ConsumerState<TargetCatchGame> {
  double whaleX = 100;
  double whaleY = 300;
  List<Offset> targets = [];
  int score = 0;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    _spawnTargets();
  }

  void _spawnTargets() {
    targets = List.generate(5, (i) => Offset(
      50 + math.Random().nextDouble() * 200,
      50 + i * 60.0,
    ));
  }

  void _onDrag(DragUpdateDetails details) {
    setState(() {
      whaleX = (whaleX + details.delta.dx).clamp(0, 250);
      whaleY = (whaleY + details.delta.dy).clamp(0, 350);
      _checkCatch();
    });
  }

  void _checkCatch() {
    targets.removeWhere((target) {
      if ((target - Offset(whaleX, whaleY)).distance < 30) {
        score++;
        return true;
      }
      return false;
    });
    if (targets.isEmpty && !gameOver) {
      gameOver = true;
      // Update stats + gift (shell for Unity pond prefab)
      ref.read(petControllerProvider.notifier).performAction('play');
      ref.read(petControllerProvider.notifier).awardGift('shell');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Caught $score! Happiness + Gift shell for habitat.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Target Catch (Whale Habitat)'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: GestureDetector(
          onPanUpdate: _onDrag,
          child: Stack(
            children: [
              // "Water" habitat background (prototype for Unity pond prefab)
              Container(color: Colors.lightBlue[100]),
              // Falling targets (bubbles/stars - Unity particles later)
              ...targets.map((t) => Positioned(
                left: t.dx,
                top: t.dy,
                child: const Icon(Icons.bubble_chart, size: 30, color: Colors.white),
              )),
              // "Whale" draggable (Unity model with Blend Tree swim)
              Positioned(
                left: whaleX,
                top: whaleY,
                child: const Icon(Icons.pets, size: 40, color: Colors.blue),
              ),
              Positioned(
                top: 10,
                child: Text('Score: $score - Drag whale to catch!'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Exit (no reward)'),
        ),
      ],
    );
  }
}