import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vale/chrome.dart';
import '../vale/controller.dart';

Future<void> showStove(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ValeColors.cream,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final save = ref.watch(valeProvider).save;
          if (save == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Berry stove', style: ValeText.title),
                const SizedBox(height: 8),
                ValeButton(label: 'Sun-Glazed Tart  ·  2 sunberries', onPressed: () => ref.read(valeProvider.notifier).cook('tart')),
                const SizedBox(height: 8),
                ValeButton(label: 'Dew-Shroom Puff  ·  dewberry + mushroom', filled: false, onPressed: () => ref.read(valeProvider.notifier).cook('puff')),
                const SizedBox(height: 8),
                ValeButton(label: 'Starlight Nectar  ·  dewberry + seed', filled: false, onPressed: () => ref.read(valeProvider.notifier).cook('nectar')),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showBench(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ValeColors.cream,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gear bench', style: ValeText.title),
            const SizedBox(height: 8),
            ValeButton(label: 'Garden planter  ·  2 twigs + seed', onPressed: () => ref.read(valeProvider.notifier).craft('planter')),
            const SizedBox(height: 8),
            ValeButton(label: 'Wind chimes  ·  2 pebbles + twig', filled: false, onPressed: () => ref.read(valeProvider.notifier).craft('chimes')),
            const SizedBox(height: 8),
            ValeButton(label: 'Glowing lure  ·  pebble + seed', filled: false, onPressed: () => ref.read(valeProvider.notifier).craft('lure')),
          ],
        ),
      );
    },
  );
}

Future<void> showPortraitTalk(BuildContext context, WidgetRef ref, {required String who}) {
  final lina = who == 'lina';
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: ValeColors.cream,
        title: Text(lina ? 'Lina' : 'Bram', style: ValeText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lina ? const Color(0xFF3E6B4A) : const Color(0xFF2458A6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lina
                  ? 'The orchard is thirsty. Bring 2 dewberries and 1 mushroom, or water the woods.'
                  : 'The meadow is open. Thirty seconds, rings in the grass. Whistle or ball, your call.',
              style: ValeText.body,
            ),
          ],
        ),
        actions: [
          if (lina)
            TextButton(
              onPressed: () {
                ref.read(valeProvider.notifier).turnInBotany();
                Navigator.pop(context);
              },
              child: const Text('Hand over the basket'),
            ),
          if (!lina)
            TextButton(
              onPressed: () {
                ref.read(valeProvider.notifier).armTrial();
                Navigator.pop(context);
              },
              child: const Text('Start the trial'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        ],
      );
    },
  );
}
