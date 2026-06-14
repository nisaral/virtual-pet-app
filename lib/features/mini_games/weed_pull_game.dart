import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';

/// Weed Pull (Cow) - Integrated mini-game prototype.
/// Tap/drag weeds from pasture to clean (active Cleanliness, not button).
/// Awards flower gift for 3D habitat decoration.
/// Future: Unity raycast on 3D weeds in pasture prefab.
class WeedPullGame extends ConsumerStatefulWidget {
  const WeedPullGame({super.key});

  @override
  ConsumerState<WeedPullGame> createState() => _WeedPullGameState();
}

class _WeedPullGameState extends ConsumerState<WeedPullGame> {
  List<Offset> weeds = [];
  int cleaned = 0;

  @override
  void initState() {
    super.initState();
    weeds = List.generate(6, (i) => Offset(30 + (i % 3) * 70, 100 + (i ~/ 3) * 80));
  }

  void _pullWeed(int index) {
    setState(() {
      weeds.removeAt(index);
      cleaned++;
      if (weeds.isEmpty) {
        ref.read(petControllerProvider.notifier).performAction('clean');
        ref.read(petControllerProvider.notifier).awardGift('flower');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pasture clean! Cleanliness + Flower gift for habitat.')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weed Pull (Cow Pasture)'),
      content: SizedBox(
        width: 280,
        height: 300,
        child: Stack(
          children: [
            // Pasture bg (Unity prefab later)
            Container(color: Colors.green[100]),
            ...List.generate(weeds.length, (i) => Positioned(
              left: weeds[i].dx,
              top: weeds[i].dy,
              child: GestureDetector(
                onTap: () => _pullWeed(i),
                onPanEnd: (_) => _pullWeed(i), // drag to pull
                child: const Icon(Icons.grass, size: 40, color: Colors.brown),
              ),
            )),
            Positioned(top: 10, child: Text('Tap/drag weeds! Cleaned: $cleaned')),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Exit'))],
    );
  }
}