import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' show Random;
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';
import 'package:virtual_pet_app/features/pet/application/llm_chat_service.dart';
import 'package:virtual_pet_app/features/pet/presentation/widgets/pet_visual.dart';
import 'package:virtual_pet_app/features/pet/presentation/widgets/pet_3d_view.dart';
import 'package:virtual_pet_app/features/pet/presentation/widgets/stat_bars.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/mini_games/target_catch_game.dart';
import 'package:virtual_pet_app/features/mini_games/weed_pull_game.dart';
import 'package:virtual_pet_app/features/mini_games/maze_chase_game.dart';
import 'package:audioplayers/audioplayers.dart';

// Note: For Unity pivot, these games become Unity scenes launched via the embedded view (raycast etc.).
// Current prototypes use Flutter gestures for immediate testing on phone (stats + gifts update via controller).
// Launch from taps on the habitat pet visual for "active" care (no bloat).

// ADHD-friendly animal mini-games (calming, focus, low-stimulation):
// - Whale "Bubble Focus": Slow, rhythmic following for concentration (ADHD friendly).
// - Cow "Calm Graze": Mindful, deliberate slow actions.
// - Snake "Steady Coil": Precise, unhurried path tracing.
// Add sounds in assets/sounds/ like focus_bubble.mp3, calm_graze.mp3, steady_slink.mp3 for calming effect.

class PetHomePage extends ConsumerWidget {
  const PetHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Simulate time away (dev)',
            onPressed: () async {
              final controller = ref.read(petControllerProvider.notifier);
              await controller.simulateTimeAway(const Duration(hours: 18));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulated 18 hours away')),
                );
              }
            },
          ),
          PopupMenuButton<PetType>(
            icon: const Icon(Icons.pets),
            tooltip: 'Switch / Adopt new pet (demo)',
            onSelected: (type) {
              ref.read(petControllerProvider.notifier).switchPet(type);
            },
            itemBuilder: (context) => PetType.values
                .map((t) => PopupMenuItem(value: t, child: Text('Adopt a ${t.displayName}')))
                .toList(),
          ),
        ],
      ),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (pet) {
          final mood = pet.moodDescription;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${pet.name}  •  ${pet.petType.displayName} (Lv ${pet.level} • ${pet.evolutionStage})',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text('Mood: ${mood.toUpperCase()}   •   Age: ${pet.ageDays} days',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                const SizedBox(height: 20),

                // 3D model view (your whale.glb with idle/run/dying + blinking blendshape,
                // cow_small.glb / cow_big.glb based on growthStage/progress).
                // Real rigged animated models from you - animation chosen by state (not hardcoded).
                // Gesture for groom (top = head). Sounds, haptics, gifts for 3D decorations.
                // Future: full Unity for Blend Trees on your animations, raycast mini-games in prefabs.
                GestureDetector(
                  onTapDown: (details) {
                    final zone = details.localPosition.dy < 150 ? 'head' : 'body';
                    HapticFeedback.mediumImpact();
                    if (pet.stats.happiness > 70) HapticFeedback.lightImpact();
                    AudioPlayer().play(AssetSource('sounds/groom.mp3')); // your calming ADHD sound
                    ref.read(petControllerProvider.notifier).performAction('groom', extra: {'zone': zone});
                    if (Random().nextBool()) {
                      ref.read(petControllerProvider.notifier).awardGift('shell');
                    }
                  },
                  child: Pet3DView(pet: pet),
                ),

                const SizedBox(height: 16),

                // Floating Thought Clouds (RAG immediate visual overlay - not separate page)
                // Future: Unity world-space bubble over the 3D pet.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Card(
                        color: Colors.white.withOpacity(0.92),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  LLMChatService.generateCurrentThought(pet),
                                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Mini-Games integrated in habitat (animal terms, ADHD-friendly calming/focus versions).
                // No bloat - launch from habitat, update stats + gifts (for your 3D decorations).
                // Prototypes (Flutter gestures). In full 3D: use your animations in Unity scenes.
                Text('Play in the Habitat (active care - updates stats + gifts)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(petControllerProvider.notifier).performAction('play');
                        ref.read(petControllerProvider.notifier).awardGift('shell');
                        showDialog(context: context, builder: (_) => const TargetCatchGame());
                      },
                      icon: const Icon(Icons.bubble_chart),
                      label: const Text('Target Catch (Whale - Bubble Focus calm)'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(petControllerProvider.notifier).performAction('clean');
                        ref.read(petControllerProvider.notifier).awardGift('flower');
                        showDialog(context: context, builder: (_) => const WeedPullGame());
                      },
                      icon: const Icon(Icons.grass),
                      label: const Text('Weed Pull (Cow - Calm Graze mindful)'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(petControllerProvider.notifier).performAction('play');
                        ref.read(petControllerProvider.notifier).awardGift('treat');
                        showDialog(context: context, builder: (_) => const MazeChaseGame());
                      },
                      icon: const Icon(Icons.route),
                      label: const Text('Maze Chase (Snake - Steady Coil precision)'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                StatBars(stats: pet.stats),

                const SizedBox(height: 22),
                Text('Take care of ${pet.name}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),

                // Care actions + new Groom (interactive brushing in visual also works)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionButton(
                      icon: Icons.restaurant,
                      label: 'Feed',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('feed', extra: {'item': 'tasty kelp'}),
                    ),
                    _ActionButton(
                      icon: Icons.sports_esports,
                      label: 'Play',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('play'),
                    ),
                    _ActionButton(
                      icon: Icons.brush,
                      label: 'Groom',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('groom'),
                    ),
                    _ActionButton(
                      icon: Icons.cleaning_services,
                      label: 'Clean',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('clean'),
                    ),
                    _ActionButton(
                      icon: Icons.favorite,
                      label: 'Pet',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('pet'),
                    ),
                    _ActionButton(
                      icon: Icons.chat,
                      label: 'Talk',
                      onPressed: () => ref.read(petControllerProvider.notifier).performAction('talk'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Tip: Tap the pet\'s head or body to brush (grooming scene)',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),

                const SizedBox(height: 32),
                if (pet.memories.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recent memory', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            pet.memories.last.text,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                Text(
                  'Growth: ${(pet.growthProgress * 100).toStringAsFixed(0)}%  •  Interactions: ${pet.interactionCount}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
