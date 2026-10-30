import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/spatial_mind.dart';
import '../vale/chrome.dart';
import '../vale/controller.dart';
import '../vale/models.dart';
Future<void> showBag(BuildContext context, WidgetRef ref, {void Function()? placeLureHere}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ValeColors.cream,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final save = ref.watch(valeProvider).save;
          if (save == null) return const SizedBox.shrink();
          final ledger = save.ledger;
          return DefaultTabController(
            length: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pack', style: ValeText.title),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Berries'),
                      Tab(text: 'Tools'),
                      Tab(text: 'Loot'),
                    ],
                  ),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      children: [
                        _list(save.bag.entries.map((e) => '${e.key} ×${e.value}').toList()),
                        ListView(
                          children: [
                            for (final tool in ['none', 'brush', 'ball', 'whistle', 'can', 'lantern'])
                              ListTile(
                                title: Text(tool == ledger.equipped ? '$tool  ·  held' : tool, style: ValeText.body),
                                enabled: tool == 'none' || ledger.tools.contains(tool),
                                onTap: () => ref.read(valeProvider.notifier).equipTool(tool),
                              ),
                          ],
                        ),
                        ListView(
                          children: [
                            for (final entry in ledger.loot.entries)
                              if (!_hiddenLoot(entry.key))
                                ListTile(
                                  title: Text('${_lootName(entry.key)} ×${entry.value}', style: ValeText.body),
                                  trailing: _lootAction(ref, entry.key, placeLureHere),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

bool _hiddenLoot(String id) => id == 'lureX' || id == 'lureY' || id == 'planterDay' || id == 'rune' || id == 'crest' || id == 'trial' || id.startsWith('trick:');

String _lootName(String id) {
  return switch (id) {
    'tart' => 'Sun-Glazed Tart',
    'puff' => 'Dew-Shroom Puff',
    'nectar' => 'Starlight Nectar',
    'planter' => 'Garden Planter',
    'chimes' => 'Wind Chimes',
    'lure' => 'Glowing Lure',
    _ => id,
  };
}

Widget? _lootAction(WidgetRef ref, String id, void Function()? placeLureHere) {
  if (id == 'tart' || id == 'puff' || id == 'nectar') {
    return TextButton(onPressed: () => ref.read(valeProvider.notifier).feedTreat(id), child: const Text('Feed Treat'));
  }
  if (id == 'lure') {
    return TextButton(onPressed: placeLureHere, child: const Text('Place'));
  }
  return null;
}

Widget _list(List<String> lines) {
  if (lines.isEmpty) return const Center(child: Text('Empty.', style: ValeText.body));
  return ListView(children: [for (final line in lines) ListTile(title: Text(line, style: ValeText.body))]);
}

Future<void> showAtlas(BuildContext context, WidgetRef ref, void Function(double x, double y) travel) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'map',
    pageBuilder: (context, _, __) {
      final save = ref.read(valeProvider).save;
      final level = save?.kin.level ?? 1;
      final ledger = save?.ledger ?? WorldLedger();
      return SafeArea(
        child: Material(
          color: const Color(0xFF163024),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                  const Text('Vale map', style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Fredoka')),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 2.8,
                  child: SizedBox(
                    width: 900,
                    height: 640,
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _RegionPainter())),
                        for (var i = 0; i < glenRegions.length; i++)
                          Positioned(
                            left: 40 + (i % 3) * 280,
                            top: 40 + (i ~/ 3) * 260,
                            child: _RegionCard(
                              region: glenRegions[i],
                              open: regionUnlocked(glenRegions[i].id, level: level, ledger: ledger),
                              onTravel: () {
                                Navigator.pop(context);
                                travel(glenRegions[i].gate.x, glenRegions[i].gate.y);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region, required this.open, required this.onTravel});
  final GlenRegion region;
  final bool open;
  final VoidCallback onTravel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xEEFFF6EA), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(region.name, style: ValeText.body),
          Text(region.blurb, style: ValeText.small),
          Text('Berries: ${region.berries}', style: ValeText.small),
          Text('Here: ${region.residents}', style: ValeText.small),
          const SizedBox(height: 8),
          if (open)
            ValeButton(label: 'Walk here', expand: false, onPressed: onTravel)
          else
            Text(regionLockText(region.id), style: ValeText.small),
        ],
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2F6B45)..strokeWidth = 8..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(160, 180), const Offset(440, 180), paint);
    canvas.drawLine(const Offset(440, 180), const Offset(720, 420), paint);
    canvas.drawLine(const Offset(160, 180), const Offset(160, 440), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
