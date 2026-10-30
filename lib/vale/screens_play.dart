import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chrome.dart';
import 'controller.dart';
import 'models.dart';
import 'stage3d.dart';
import 'tone.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(valeProvider);
    final save = state.save;
    if (save == null) return const SizedBox.shrink();
    final kin = save.kin;
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'The bowl', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            SizedBox(
              height: 220,
              child: GlenStage(species: kin.species, interactive: false, showStage: false),
            ),
            if (state.aside != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(state.aside!, style: ValeText.body, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final food in SpeciesCatalog.foods)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FoodTile(
                        food: food,
                        count: save.bag[food.id] ?? 0,
                        loved: (kin.foodLove[food.id] ?? 0) >= 0.55,
                        onPressed: (save.bag[food.id] ?? 0) > 0 ? () => ref.read(valeProvider.notifier).feed(food.id) : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.count, required this.loved, required this.onPressed});

  final FoodDef food;
  final int count;
  final bool loved;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CreamCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ValeGlyphMark(
            glyph: food.taste == null ? ValeGlyph.star : glyphForElement(food.taste!),
            color: food.taste == null ? ValeColors.goldDeep : elementColor(food.taste!),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${food.name}  ·  $count', style: ValeText.body),
                Text(loved ? '${food.blurb} A favorite.' : food.blurb, style: ValeText.small),
              ],
            ),
          ),
          ValeButton(label: 'Give', expand: false, onPressed: onPressed),
        ],
      ),
    );
  }
}

class GroomScreen extends ConsumerStatefulWidget {
  const GroomScreen({super.key});

  @override
  ConsumerState<GroomScreen> createState() => _GroomScreenState();
}

class _GroomScreenState extends ConsumerState<GroomScreen> {
  int _strokes = 0;
  final List<double> _speeds = [];
  DateTime? _last;
  Offset? _spark;

  double get _quality {
    if (_strokes == 0) return 0;
    final countScore = (_strokes >= 5 && _strokes <= 16) ? 1.0 : 0.45;
    if (_speeds.isEmpty) return countScore * 0.5;
    final mean = _speeds.reduce((a, b) => a + b) / _speeds.length;
    final speedScore = (mean > 40 && mean < 900) ? 1.0 : 0.4;
    return (countScore * 0.6 + speedScore * 0.4).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(valeProvider);
    final kin = state.save?.kin;
    if (kin == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Brush', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Draw slow strokes across ${kin.name}. A steady hand fills the coat.', style: ValeText.body, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GestureDetector(
                onPanStart: (details) {
                  _last = DateTime.now();
                  setState(() => _spark = details.localPosition);
                },
                onPanUpdate: (details) {
                  final now = DateTime.now();
                  final dt = _last == null ? 16 : now.difference(_last!).inMilliseconds;
                  _last = now;
                  final speed = dt <= 0 ? 0.0 : details.delta.distance / dt * 1000;
                  _speeds.add(speed.clamp(0, 2000));
                  setState(() => _spark = details.localPosition);
                },
                onPanEnd: (_) {
                  setState(() {
                    _strokes += 1;
                    _spark = null;
                  });
                  HapticFeedback.selectionClick();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GlenStage(species: kin.species, interactive: false),
                    if (_spark != null)
                      Positioned(
                        left: _spark!.dx - 14,
                        top: _spark!.dy - 14,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.8),
                            border: Border.all(color: ValeColors.goldDeep, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatLine(label: 'Rhythm', value: _quality * 100, color: ValeColors.bloom),
                  const SizedBox(height: 8),
                  ValeButton(
                    label: _strokes == 0 ? 'Stroke first' : 'That will do',
                    onPressed: _strokes == 0
                        ? null
                        : () {
                            ref.read(valeProvider.notifier).groom(_quality);
                            ValeTone.play(_quality > 0.7 ? ValeSound.good : ValeSound.tap);
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayHub extends ConsumerWidget {
  const PlayHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kin = ref.watch(valeProvider).save?.kin;
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ScreenHeader(title: 'Play', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            Text(kin == null ? '' : '${kin.name} learns the games you repeat.', style: ValeText.body),
            const SizedBox(height: 12),
            _GameCard(
              title: 'Pattern Duet',
              body: 'Watch the glyphs, then repeat them. Later rounds start to echo the jumps you make.',
              glyph: ValeGlyph.star,
              onPressed: () => ref.read(valeProvider.notifier).startPattern(),
            ),
            _GameCard(
              title: 'Ribbon Fall',
              body: 'Catch the falling ribbons before they reach the grass. Ten is a perfect pass.',
              glyph: ValeGlyph.play,
              onPressed: () => ref.read(valeProvider.notifier).go(ValeScreen.ribbons),
            ),
            _GameCard(
              title: 'Glen Spar',
              body: 'A friendly showcase. The glowing move is the one their spar-memory currently trusts.',
              glyph: ValeGlyph.flame,
              onPressed: () => ref.read(valeProvider.notifier).startSpar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.title, required this.body, required this.glyph, required this.onPressed});

  final String title;
  final String body;
  final ValeGlyph glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ValeGlyphMark(glyph: glyph, size: 22, color: ValeColors.goldDeep),
                const SizedBox(width: 8),
                Text(title, style: ValeText.title.copyWith(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 6),
            Text(body, style: ValeText.body),
            const SizedBox(height: 10),
            ValeButton(label: 'Play', onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}

class PatternScreen extends ConsumerStatefulWidget {
  const PatternScreen({super.key});

  @override
  ConsumerState<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends ConsumerState<PatternScreen> {
  int _lit = -1;
  int _played = -1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(valeProvider);
    final session = state.pattern;
    final kin = state.save?.kin;
    if (session == null || kin == null) return const SizedBox.shrink();
    if (session.phase == 'show' && _played != session.token) {
      _played = session.token;
      WidgetsBinding.instance.addPostFrameCallback((_) => _play(session.sequence));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF241B33),
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Pattern Duet',
              onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.play),
            ),
            Text(
              session.echo ? '${kin.name} shaped this phrase from you.' : 'Round ${session.round}. Watch, then repeat.',
              style: ValeText.body.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text('Misses ${session.misses} / 3', style: ValeText.small.copyWith(color: ValeColors.gold)),
            const Spacer(),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (var i = 0; i < 4; i++)
                  _Pad(
                    glyph: glyphForIndex(i),
                    lit: _lit == i,
                    enabled: session.phase == 'input',
                    onTap: () {
                      ValeTone.play(ValeSound.tap);
                      ref.read(valeProvider.notifier).patternTap(i);
                    },
                  ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Future<void> _play(List<int> sequence) async {
    if (!mounted) return;
    setState(() => _lit = -1);
    await Future<void>.delayed(const Duration(milliseconds: 360));
    for (final glyph in sequence) {
      if (!mounted) return;
      setState(() => _lit = glyph);
      ValeTone.play(ValeSound.tap);
      await Future<void>.delayed(const Duration(milliseconds: 460));
      if (!mounted) return;
      setState(() => _lit = -1);
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    if (mounted) ref.read(valeProvider.notifier).patternReady();
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.glyph, required this.lit, required this.enabled, required this.onTap});

  final ValeGlyph glyph;
  final bool lit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: lit ? ValeColors.gold : const Color(0xFF3A3154),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: lit ? Colors.white : ValeColors.gold, width: 3),
        ),
        child: Center(child: ValeGlyphMark(glyph: glyph, size: 42, color: lit ? ValeColors.ink : Colors.white)),
      ),
    );
  }
}

class RibbonScreen extends StatefulWidget {
  const RibbonScreen({super.key});

  @override
  State<RibbonScreen> createState() => _RibbonScreenState();
}

class _RibbonScreenState extends State<RibbonScreen> {
  final math.Random _rng = math.Random();
  final List<_Ribbon> _ribbons = [];
  Timer? _timer;
  int _leftMs = 16000;
  int _catches = 0;
  int _spawned = 0;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer timer) {
    if (_over) return;
    _leftMs -= 50;
    if (_leftMs % 700 == 0 && _leftMs > 800) {
      _ribbons.add(_Ribbon(x: 0.12 + _rng.nextDouble() * 0.76, y: -0.05, glyph: _rng.nextInt(4)));
      _spawned += 1;
    }
    for (final ribbon in _ribbons) {
      if (!ribbon.caught) ribbon.y += 0.018;
    }
    _ribbons.removeWhere((ribbon) => ribbon.y > 1.05);
    if (_leftMs <= 0) {
      _over = true;
      timer.cancel();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EC8F5),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Consumer(
                  builder: (context, ref, _) => ScreenHeader(
                    title: 'Ribbon Fall',
                    onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.play),
                  ),
                ),
                Text('$_catches caught  ·  ${(_leftMs / 1000).ceil()}s', style: ValeText.title.copyWith(color: Colors.white)),
                const Spacer(),
                if (_over)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Consumer(
                      builder: (context, ref, _) => ValeButton(
                        label: 'Bring it back',
                        onPressed: () {
                          final score = (_catches / 10).clamp(0.0, 1.0);
                          ref.read(valeProvider.notifier).playResult('ribbons', score);
                          ValeTone.play(score > 0.5 ? ValeSound.good : ValeSound.tap);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            ..._ribbons.map((ribbon) {
              return Positioned(
                left: ribbon.x * MediaQuery.sizeOf(context).width - 24,
                top: ribbon.y * MediaQuery.sizeOf(context).height,
                child: GestureDetector(
                  onTap: ribbon.caught
                      ? null
                      : () {
                          setState(() {
                            ribbon.caught = true;
                            _catches += 1;
                          });
                          HapticFeedback.lightImpact();
                        },
                  child: Opacity(
                    opacity: ribbon.caught ? 0 : 1,
                    child: ValeGlyphMark(glyph: glyphForIndex(ribbon.glyph), size: 36, color: Colors.white),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Ribbon {
  _Ribbon({required this.x, required this.y, required this.glyph});
  double x;
  double y;
  int glyph;
  bool caught = false;
}

class SparScreen extends ConsumerWidget {
  const SparScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(valeProvider);
    final spar = state.spar;
    final kin = state.save?.kin;
    if (spar == null || kin == null) return const SizedBox.shrink();
    final moves = kin.def.moves;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlenStage(species: kin.species, interactive: false),
          SafeArea(
            child: Column(
              children: [
                ScreenHeader(title: 'Glen Spar', onBack: () => ref.read(valeProvider.notifier).closeSpar()),
                _FighterRow(
                  name: spar.rivalName,
                  species: spar.rivalSpecies,
                  stage: kin.stage.clamp(0, 1),
                  stamina: spar.foeStamina,
                  max: spar.maxStamina,
                  flip: true,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AsideBubble(text: spar.log),
                ),
                _FighterRow(
                  name: kin.name,
                  species: kin.species,
                  stage: kin.stage,
                  stamina: spar.selfStamina,
                  max: spar.maxStamina,
                ),
                if (!spar.done)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < moves.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _MoveButton(
                                move: moves[i],
                                suggested: i == spar.suggestedIndex,
                                onPressed: () => ref.read(valeProvider.notifier).sparMove(i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: ValeButton(
                      label: spar.won ? 'They shone' : 'Back to the glen',
                      onPressed: () => ref.read(valeProvider.notifier).closeSpar(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FighterRow extends StatelessWidget {
  const _FighterRow({
    required this.name,
    required this.species,
    required this.stage,
    required this.stamina,
    required this.max,
    this.flip = false,
  });

  final String name;
  final SpeciesId species;
  final int stage;
  final int stamina;
  final int max;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: GlenStage(species: species, interactive: false, showStage: false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: ValeText.body.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0xFF3A3154)),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: max == 0 ? 0 : (stamina / max).clamp(0, 1),
                            child: const ColoredBox(color: Color(0xFF7DDE86)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.move, required this.suggested, required this.onPressed});

  final MoveDef move;
  final bool suggested;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ValeTone.play(ValeSound.tap);
        onPressed();
      },
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: suggested ? ValeColors.gold : ValeColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ValeColors.ink, width: suggested ? 3 : 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(move.name, style: ValeText.small.copyWith(color: ValeColors.ink), textAlign: TextAlign.center),
            if (suggested) Text('leans', style: ValeText.small.copyWith(fontSize: 10, color: ValeColors.ink)),
          ],
        ),
      ),
    );
  }
}

class OutingScreen extends ConsumerStatefulWidget {
  const OutingScreen({super.key});

  @override
  ConsumerState<OutingScreen> createState() => _OutingScreenState();
}

class _OutingScreenState extends ConsumerState<OutingScreen> {
  late final List<_Stop> _stops = _build();
  int _index = -1;
  final Map<String, int> _found = {};
  int _gleam = 0;

  List<_Stop> _build() {
    final rng = math.Random(DateTime.now().day * 17 + DateTime.now().hour);
    final bag = <_Stop>[
      const _Stop('A sunberry bush, heavy and low.', 'sunberry', 0),
      const _Stop('Kelp caught on a warm stone.', 'kelpbit', 0),
      const _Stop('Spice crumbs in a picnic fold.', 'spicecrumb', 0),
      const _Stop('A milk drop left on a flat rock.', 'milkdrop', 0),
      const _Stop('Gleam in the gravel. It ticks like a beetle.', null, 3),
      const _Stop('A wild kin watches from the hill, then waves.', null, 1),
      const _Stop('The path opens. The air smells like rain on leaves.', null, 0),
    ];
    bag.shuffle(rng);
    return bag;
  }

  @override
  Widget build(BuildContext context) {
    final kin = ref.watch(valeProvider).save?.kin;
    final done = _index >= _stops.length - 1 && _index >= 0;
    final stop = _index >= 0 && _index < _stops.length ? _stops[_index] : null;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlenStage(species: kin?.species ?? SpeciesId.pipkin, interactive: false),
          SafeArea(
            child: Column(
              children: [
                ScreenHeader(title: 'The path', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CreamCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(stop?.line ?? '${kin?.name ?? 'Your kin'} waits at the gate. Seven steps out, then home.', style: ValeText.body),
                        const SizedBox(height: 8),
                        Text('Step ${_index < 0 ? 0 : _index + 1} of ${_stops.length}', style: ValeText.small),
                        const SizedBox(height: 10),
                        ValeButton(
                          label: done ? 'Come home' : 'Step out',
                          onPressed: () {
                            if (!done && _index < _stops.length - 1) {
                              setState(() {
                                _index += 1;
                                final next = _stops[_index];
                                if (next.item != null) _found[next.item!] = (_found[next.item!] ?? 0) + 1;
                                _gleam += next.gleam;
                              });
                              HapticFeedback.selectionClick();
                              return;
                            }
                            final name = kin?.name ?? 'Your kin';
                            final bits = _found.entries.map((e) => '${e.value} ${SpeciesCatalog.food(e.key).name}').join(', ');
                            final line = bits.isEmpty
                                ? '$name walked the path and came back lighter.'
                                : '$name came home with $bits.';
                            ref.read(valeProvider.notifier).finishOuting(_found, _gleam, line);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stop {
  const _Stop(this.line, this.item, this.gleam);
  final String line;
  final String? item;
  final int gleam;
}
