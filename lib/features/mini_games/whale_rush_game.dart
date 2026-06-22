import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';
import 'package:audioplayers/audioplayers.dart';

/// Whale Rush - Mario-like side scroller in water for the whale.
/// Auto forward, tap to boost up, collect fish (happiness), avoid rocks (damage).
/// Amazing, intuitive, bug free: simple controls, smooth, score, end screen with stat update.
/// ADHD friendly: no time pressure, focus on timing jumps.
/// Launch from habitat, full page.

class WhaleRushGame extends ConsumerStatefulWidget {
  const WhaleRushGame({super.key});

  @override
  ConsumerState<WhaleRushGame> createState() => _WhaleRushGameState();
}

class _WhaleRushGameState extends ConsumerState<WhaleRushGame> with TickerProviderStateMixin {
  double whaleY = 200;
  double velocity = 0;
  List<Offset> fish = [];
  List<Offset> rocks = [];
  int score = 0;
  int lives = 3;
  bool gameOver = false;
  bool started = false;
  late Ticker ticker;
  double scroll = 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(_update)..start();
    _spawnInitial();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void _spawnInitial() {
    fish.clear();
    rocks.clear();
    for (int i = 0; i < 5; i++) {
      fish.add(Offset(300 + i * 150, 100 + (i % 3) * 80));
    }
    for (int i = 0; i < 3; i++) {
      rocks.add(Offset(400 + i * 200, 150 + (i % 2) * 100));
    }
  }

  void _update(Duration elapsed) {
    if (!started || gameOver) return;
    setState(() {
      scroll += 2; // auto scroll
      velocity += 0.3; // gravity
      whaleY += velocity;
      whaleY = whaleY.clamp(50, 350);

      // Move fish and rocks left
      for (int i = fish.length - 1; i >= 0; i--) {
        fish[i] = Offset(fish[i].dx - 3, fish[i].dy);
        if (fish[i].dx < 0) {
          fish.removeAt(i);
          fish.add(Offset(400 + (i * 50), 100 + (i % 3) * 80));
        }
        // Collect fish
        if ((fish[i] - Offset(50, whaleY)).distance < 30) {
          fish.removeAt(i);
          score += 10;
          AudioPlayer().play(AssetSource('sounds/happy_chime.mp3'));
        }
      }

      for (int i = rocks.length - 1; i >= 0; i--) {
        rocks[i] = Offset(rocks[i].dx - 3, rocks[i].dy);
        if (rocks[i].dx < 0) {
          rocks.removeAt(i);
          rocks.add(Offset(400 + (i * 80), 150 + (i % 2) * 100));
        }
        // Hit rock
        if ((rocks[i] - Offset(50, whaleY)).distance < 25) {
          lives--;
          rocks.removeAt(i);
          AudioPlayer().play(AssetSource('sounds/steady_coil.mp3'));
          if (lives <= 0) {
            gameOver = true;
            _endGame();
          }
        }
      }

      // Spawn more
      if (fish.length < 3) fish.add(Offset(400, 100 + (score % 3) * 80));
      if (rocks.length < 2) rocks.add(Offset(400, 150 + (score % 2) * 100));
    });
  }

  void _onTap() {
    if (!started) {
      started = true;
      return;
    }
    velocity = -8; // boost up
    AudioPlayer().play(AssetSource('sounds/focus_bubble.mp3'));
  }

  void _endGame() {
    // Update stats
    final controller = ref.read(petControllerProvider.notifier);
    controller.performAction('play');
    if (score > 50) controller.awardGift('shell');
    // Happiness from score
    // For demo, just show
  }

  void _restart() {
    setState(() {
      whaleY = 200;
      velocity = 0;
      fish.clear();
      rocks.clear();
      score = 0;
      lives = 3;
      gameOver = false;
      started = false;
      scroll = 0;
      _spawnInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Whale Rush - Water Mario!')),
      body: GestureDetector(
        onTap: _onTap,
        child: Container(
          color: Colors.blue[900], // Water
          child: Stack(
            children: [
              // Background waves
              Positioned.fill(
                child: CustomPaint(painter: _WaterPainter(scroll)),
              ),
              // Whale
              Positioned(
                left: 50,
                top: whaleY,
                child: const Icon(Icons.pets, size: 50, color: Colors.lightBlue),
              ),
              // Fish
              ...fish.map((f) => Positioned(
                left: f.dx,
                top: f.dy,
                child: const Icon(Icons.set_meal, size: 20, color: Colors.yellow),
              )),
              // Rocks
              ...rocks.map((r) => Positioned(
                left: r.dx,
                top: r.dy,
                child: const Icon(Icons.terrain, size: 30, color: Colors.grey),
              )),
              // UI
              Positioned(
                top: 20,
                left: 20,
                child: Text('Score: $score  Lives: $lives', style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
              if (!started)
                const Center(child: Text('Tap to start swimming!', style: TextStyle(color: Colors.white, fontSize: 24))),
              if (gameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Game Over!', style: TextStyle(color: Colors.white, fontSize: 32)),
                      Text('Score: $score', style: const TextStyle(color: Colors.white, fontSize: 24)),
                      ElevatedButton(onPressed: _restart, child: const Text('Play Again')),
                      ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Habitat')),
                    ],
                  ),
                ),
              Positioned(
                bottom: 20,
                left: 20,
                child: const Text('Tap to boost up!', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterPainter extends CustomPainter {
  final double scroll;
  _WaterPainter(this.scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue[700]!.withOpacity(0.5);
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset((scroll * 2 + i * 100) % (size.width + 100) - 50, 100 + i * 50), 20, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPainter old) => old.scroll != scroll;
}