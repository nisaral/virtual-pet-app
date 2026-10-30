import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'care_sim.dart';
import 'chrome.dart';
import 'controller.dart';
import 'learning.dart';
import 'models.dart';
import '../ml/spatial_mind.dart';
import '../world/overworld_renderer.dart';
import '../world/world_ui.dart';
import 'stage3d.dart';
import 'tone.dart';

class TitleScreen extends ConsumerWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(valeProvider);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GlenStage(species: SpeciesId.pipkin, interactive: false),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LUMINA\nVALE', style: ValeText.display.copyWith(fontSize: 58, color: Colors.white, shadows: const [Shadow(color: Color(0x88241B33), offset: Offset(0, 4), blurRadius: 0)])),
                  const SizedBox(height: 8),
                  Text(
                    'Raise a kin. They learn the shape of your days.',
                    style: ValeText.body.copyWith(color: Colors.white, shadows: const [Shadow(color: Color(0xAA241B33), blurRadius: 8)]),
                  ),
                  const Spacer(),
                  if (state.save != null) ...[
                    ValeButton(label: 'Continue with ${state.save!.kin.name}', onPressed: () => ref.read(valeProvider.notifier).continueGame()),
                    const SizedBox(height: 10),
                  ],
                  ValeButton(
                    label: state.save == null ? 'Begin' : 'Start a new glen',
                    filled: state.save == null,
                    onPressed: () async {
                      if (state.save != null) {
                        final ok = await valeConfirm(
                          context,
                          'Start again?',
                          '${state.save!.kin.name} stays only in this glen. A new beginning lets them go.',
                        );
                        if (!ok) return;
                        await ref.read(valeProvider.notifier).releaseKin();
                      }
                      ref.read(valeProvider.notifier).beginNaming();
                    },
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

class NamingScreen extends ConsumerStatefulWidget {
  const NamingScreen({super.key});

  @override
  ConsumerState<NamingScreen> createState() => _NamingScreenState();
}

class _NamingScreenState extends ConsumerState<NamingScreen> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: ref.read(valeProvider).keeperDraft);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ValeColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The glen asks', style: ValeText.small),
              const SizedBox(height: 6),
              const Text('What should we call you?', style: ValeText.title),
              const SizedBox(height: 8),
              const Text('Your kin will use this when they talk about the hours you keep.', style: ValeText.body),
              const SizedBox(height: 18),
              TextField(
                controller: _field,
                textCapitalization: TextCapitalization.words,
                maxLength: 16,
                style: ValeText.title.copyWith(fontSize: 22),
                decoration: _fieldDecoration('Keeper name'),
                onChanged: (value) => ref.read(valeProvider.notifier).setKeeperDraft(value),
              ),
              const Spacer(),
              ValeButton(
                label: 'Choose a kin',
                onPressed: () {
                  ref.read(valeProvider.notifier).setKeeperDraft(_field.text);
                  ref.read(valeProvider.notifier).toStarter();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarterScreen extends ConsumerStatefulWidget {
  const StarterScreen({super.key});

  @override
  ConsumerState<StarterScreen> createState() => _StarterScreenState();
}

class _StarterScreenState extends ConsumerState<StarterScreen> {
  late final PageController _page = PageController(viewportFraction: 0.86);
  late final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(valeProvider.select((s) => s.starterIndex));
    final species = SpeciesCatalog.all[index];
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Who comes home?', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.naming)),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: SpeciesCatalog.all.length,
                onPageChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref.read(valeProvider.notifier).setStarter(value);
                },
                itemBuilder: (context, i) {
                  final spec = SpeciesCatalog.all[i];
                  final selected = i == index;
                  return AnimatedScale(
                    scale: selected ? 1 : 0.92,
                    duration: const Duration(milliseconds: 180),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: CreamCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: GlenStage(species: spec.id, interactive: false),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(spec.name, style: ValeText.title),
                            Text(spec.stageTitles.first, style: ValeText.small.copyWith(color: elementColor(spec.element))),
                            const SizedBox(height: 4),
                            Text(spec.blurb, style: ValeText.body.copyWith(fontSize: 14), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 14,
                    textCapitalization: TextCapitalization.words,
                    style: ValeText.body,
                    decoration: _fieldDecoration('Name your ${species.name}'),
                    onChanged: (value) => ref.read(valeProvider.notifier).setNameDraft(value),
                  ),
                  ValeButton(
                    label: 'Welcome them',
                    onPressed: () {
                      ref.read(valeProvider.notifier).setNameDraft(_name.text);
                      ref.read(valeProvider.notifier).welcomeKin();
                      ValeTone.play(ValeSound.good);
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

class DenScreen extends ConsumerWidget {
  const DenScreen({super.key});

  static final glenKey = GlobalKey<GlenStageState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(valeProvider);
    final save = state.save;
    if (save == null) return const SizedBox.shrink();
    final kin = save.kin;
    final now = DateTime.now();
    final phase = phaseAt(now);
    final script = state.script.isNotEmpty && state.scriptCursor < state.script.length;
    final ready = readyToEvolve(kin, save.gamesPlayed);
    final mode = state.interactMode;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlenStage(key: DenScreen.glenKey, species: kin.species),
          SafeArea(
            child: Column(
              children: [
                _Hud(save: save, phase: phase),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValeButton(
                        key: const Key('bag'),
                        label: 'Bag',
                        expand: false,
                        filled: false,
                        onPressed: () => showBag(
                          context,
                          ref,
                          placeLureHere: () {
                            final glen = DenScreen.glenKey.currentState;
                            if (glen == null) return;
                            ref.read(valeProvider.notifier).placeLure(glen.px, glen.py);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValeButton(
                        key: const Key('tool-chip'),
                        label: save.ledger.equipped,
                        expand: false,
                        filled: false,
                        onPressed: () => showBag(context, ref),
                      ),
                      const Spacer(),
                      MiniRadar(
                        key: const Key('radar'),
                        pet: DenScreen.glenKey.currentState == null
                            ? const Offset(620, 1680)
                            : Offset(DenScreen.glenKey.currentState!.px, DenScreen.glenKey.currentState!.py),
                        others: DenScreen.glenKey.currentState?.folkSpots ?? const [],
                        onOpen: () => showAtlas(context, ref, (x, y) => DenScreen.glenKey.currentState?.travel(x, y)),
                      ),
                    ],
                  ),
                ),
                if (mode != InteractMode.overview)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: ValeButton(
                        label: 'Back',
                        expand: false,
                        filled: false,
                        onPressed: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.overview),
                      ),
                    ),
                  ),
                if (ready)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ValeButton(
                      label: 'The rite is ready',
                      onPressed: () => ref.read(valeProvider.notifier).openRite(),
                    ),
                  ),
                const Spacer(),
                if (mode == InteractMode.feed && !script)
                  SizedBox(
                    height: 78,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final food in SpeciesCatalog.foods)
                          if ((save.bag[food.id] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ValeButton(
                                label: '${food.name} ×${save.bag[food.id]}',
                                expand: false,
                                filled: state.queuedFood == food.id,
                                onPressed: () => ref.read(valeProvider.notifier).queueTreat(food.id),
                              ),
                            ),
                      ],
                    ),
                  ),
                if (kin.asleep && !script)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ValeButton(label: 'Wake ${kin.name}', onPressed: () => ref.read(valeProvider.notifier).wake()),
                  ),
                if (script)
                  DialogueBar(
                    speaker: kin.name,
                    text: state.script[state.scriptCursor],
                    accent: elementColor(kin.def.element),
                    onAdvance: () => ref.read(valeProvider.notifier).advanceScript(),
                  )
                else ...[
                  if (state.aside != null && state.aside!.isNotEmpty) AsideBubble(text: state.aside!),
                  if (!script && mode == InteractMode.overview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValeButton(
                            key: const Key('praise'),
                            label: 'Praise',
                            expand: false,
                            onPressed: () => ref.read(valeProvider.notifier).shapeSpatial(1.1),
                          ),
                          const SizedBox(width: 8),
                          ValeButton(
                            key: const Key('redirect'),
                            label: 'Redirect',
                            expand: false,
                            filled: false,
                            onPressed: () => ref.read(valeProvider.notifier).shapeSpatial(-0.6),
                          ),
                        ],
                      ),
                    ),
                  if (!script)
                    HandheldPad(
                      key: const Key('pad'),
                      onStick: (o) => DenScreen.glenKey.currentState?.stick = o,
                      onInteract: () => DenScreen.glenKey.currentState?.interact(),
                      onHop: () => DenScreen.glenKey.currentState?.hop(),
                    ),
                  GameDock(
                    key: const Key('dock'),
                    onFeed: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.feed),
                    onBrush: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.brush),
                    onPlay: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.play),
                    onRest: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.rest),
                    onWalk: () => ref.read(valeProvider.notifier).enterInteract(InteractMode.walk),
                  ),
                ],
              ],
            ),
          ),
          FloatHearts(token: state.fxToken),
        ],
      ),
    );
  }

}

class _Hud extends ConsumerWidget {
  const _Hud({required this.save, required this.phase});

  final ValeSave save;
  final DayPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kin = save.kin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GlassHud(
        key: const Key('status-card'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
        children: [
          Row(
            children: [
              _Mini(glyph: ValeGlyph.paw, onPressed: () => ref.read(valeProvider.notifier).go(ValeScreen.summary)),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onLongPress: () => _keeperSheet(context, ref),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kin.name, style: ValeText.title),
                    Text(
                      '${kin.def.titleFor(kin.stage)}  ·  Lv ${kin.level}',
                      style: ValeText.small,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: xpStepForLevel(kin.level) == 0 ? 0 : xpIntoLevel(kin.xp) / xpStepForLevel(kin.level),
                        backgroundColor: const Color(0xFFE7D7C4),
                        color: elementColor(kin.def.element),
                      ),
                    ),
                    Text('${xpIntoLevel(kin.xp)} / ${xpStepForLevel(kin.level)} xp', style: ValeText.small),
                    if (save.ledger.buff.isNotEmpty)
                      Text(save.ledger.buff, style: ValeText.small.copyWith(color: ValeColors.goldDeep)),
                  ],
                ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  HeartRow(bond: kin.bond),
                  GestureDetector(
                    onTap: () => _hours(context, ref),
                    onLongPress: () => _keeperSheet(context, ref),
                    child: Text(
                      '${phaseLabel(phase)}  ·  day ${kin.daysTogether + 1}',
                      style: ValeText.small,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Link(label: 'Summary', onPressed: () => ref.read(valeProvider.notifier).go(ValeScreen.summary)),
              _Link(label: 'Mind', onPressed: () => ref.read(valeProvider.notifier).go(ValeScreen.mind)),
              _Link(label: 'Journal', onPressed: () => ref.read(valeProvider.notifier).go(ValeScreen.journal)),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }

  Future<void> _hours(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ValeColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: ValeColors.ink, width: 2),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Let the glen rest', style: ValeText.title),
              const SizedBox(height: 6),
              const Text('Time moves, needs settle, and a night counts as another day together.', style: ValeText.body),
              const SizedBox(height: 12),
              ValeButton(
                label: 'A quiet afternoon',
                filled: false,
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(valeProvider.notifier).passHours(3);
                },
              ),
              const SizedBox(height: 8),
              ValeButton(
                label: 'Through the night',
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(valeProvider.notifier).passHours(8);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _keeperSheet(BuildContext context, WidgetRef ref) {
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
            const Text('Keeper sandbox', style: ValeText.title),
            const SizedBox(height: 8),
            ValeButton(label: 'Cycle time of day', onPressed: () => ref.read(valeProvider.notifier).cyclePhase()),
            const SizedBox(height: 8),
            ValeButton(
              label: 'Cycle weather',
              filled: false,
              onPressed: () => DenScreen.glenKey.currentState?.cycleWeather(),
            ),
            const SizedBox(height: 8),
            ValeButton(label: '+1 level and next tool', filled: false, onPressed: () => ref.read(valeProvider.notifier).debugBoost()),
            const SizedBox(height: 8),
            ValeButton(label: '+5 of every forage', filled: false, onPressed: () => ref.read(valeProvider.notifier).grantSupplies()),
            const SizedBox(height: 8),
            ValeButton(
              label: 'Trigger RL chain',
              filled: false,
              onPressed: () => DenScreen.glenKey.currentState?.forceChain(),
            ),
            const SizedBox(height: 8),
            ValeButton(label: 'Reset save', filled: false, onPressed: () => ref.read(valeProvider.notifier).resetSave()),
          ],
        ),
      );
    },
  );
}

class _Mini extends StatelessWidget {
  const _Mini({required this.glyph, required this.onPressed});
  final ValeGlyph glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ValeColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: ValeColors.ink, width: 2),
        ),
        child: ValeGlyphMark(glyph: glyph, size: 18),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCCFFF6EA),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: ValeColors.ink, width: 1.5),
          ),
          child: Text(label, style: ValeText.small.copyWith(color: ValeColors.ink)),
        ),
      ),
    );
  }
}

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(valeProvider).save;
    if (save == null) return const SizedBox.shrink();
    final kin = save.kin;
    final foodId = favoriteKey(kin.foodLove, kin.def.favoriteFood);
    final gameId = favoriteKey(kin.gameLove, 'pattern');
    final gameName = switch (gameId) {
      'spar' => 'Glen Spar',
      'ribbons' => 'Ribbon Fall',
      _ => 'Pattern Duet',
    };
    final step = xpStepForLevel(kin.level);
    final into = xpIntoLevel(kin.xp);
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ScreenHeader(title: kin.name, onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GlenStage(species: kin.species, interactive: false),
              ),
            ),
            const SizedBox(height: 12),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ValeGlyphMark(glyph: glyphForElement(kin.def.element), size: 18, color: elementColor(kin.def.element)),
                      const SizedBox(width: 6),
                      Text('${elementLabel(kin.def.element)}  ·  ${kin.def.titleFor(kin.stage)}', style: ValeText.body),
                      const Spacer(),
                      HeartRow(bond: kin.bond),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatLine(label: 'Sated', value: kin.satiation, color: const Color(0xFFE2A15A)),
                  StatLine(label: 'Energy', value: kin.energy, color: const Color(0xFF6AA6E8)),
                  StatLine(label: 'Coat', value: kin.coat, color: const Color(0xFF67C36A)),
                  StatLine(label: 'Joy', value: kin.joy, color: const Color(0xFFFF7A9A)),
                  const SizedBox(height: 6),
                  Text('Level ${kin.level}  ·  $into / $step xp  ·  ${save.gleam} gleam', style: ValeText.small),
                  const SizedBox(height: 8),
                  Text('${natureLabel(kin.nature)}. ${natureBlurb(kin.nature)}', style: ValeText.body),
                  const SizedBox(height: 6),
                  Text('Favorite bite: ${SpeciesCatalog.food(foodId).name}. Favorite game: $gameName.', style: ValeText.body),
                  const SizedBox(height: 8),
                  Text('Showcase moves', style: ValeText.small),
                  for (final move in kin.def.moves)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${move.name} — ${move.line}', style: ValeText.body.copyWith(fontSize: 14.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ValeButton(
              label: 'Let ${kin.name} go',
              filled: false,
              onPressed: () async {
                final ok = await valeConfirm(context, 'Let ${kin.name} go?', 'The glen forgets this kin. This cannot be undone.');
                if (ok) await ref.read(valeProvider.notifier).releaseKin();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MindScreen extends ConsumerWidget {
  const MindScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(valeProvider).save;
    if (save == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final kin = save.kin;
    final key = kin.bidStateKey.isNotEmpty ? kin.bidStateKey : BondMind.keyFor(kin, now);
    final learned = BondMind.learnedRow(save.qTable, key);
    final greedy = BondMind.greedy(
      table: save.qTable,
      stateKey: key,
      kin: kin,
      steps: save.mindSteps,
      anticipatedBid: careToBid[save.routine.anticipate(now.hour)],
    );
    final curiosity = (BondMind.curiosity(save.mindSteps) * 100).round();
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ScreenHeader(title: 'Bond Mind', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${kin.name} keeps a small table of what worked.', style: ValeText.body),
                  const SizedBox(height: 6),
                  Text(
                    'Each situation stores six scores: meal, play, brush, nap, trick, wander. When you answer, that score moves. Curiosity is still ${curiosity}%, so they sometimes try something new.',
                    style: ValeText.body.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visited ${save.qTable.length} situations over ${save.mindSteps} answers. Right now the sure pick is ${BondMind.actions[greedy]}.',
                    style: ValeText.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Where they walk', style: ValeText.title),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _pill('Day'),
                      _pill('Zone ${save.ledger.goal}'),
                      _pill('Tool ${save.ledger.equipped}'),
                      _pill('Social ${save.ledger.social.round()}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Curiosity bonus fades as a state-action is repeated. Entropy of this row is ${(SpatialMind.entropy(SpatialMind.goals.map((g) => save.ledger.spatialQ[save.ledger.lastKey]?[SpatialMind.indexOf(g)] ?? 0).toList()) * 100).round()}%.',
                    style: ValeText.small,
                  ),
                  const SizedBox(height: 8),
                  _Heat(visits: save.ledger.zoneVisits),
                  const SizedBox(height: 8),
                  Text(
                    save.ledger.dreamNote.isEmpty
                        ? 'No dream replay yet. Rest in the homestead at dusk or night.'
                        : 'Memories consolidated tonight: ${save.ledger.dreamNote}',
                    style: ValeText.body,
                  ),
                  Text('${save.ledger.consolidated} nights replayed  ·  ${save.ledger.dreams.length} traces kept', style: ValeText.small),
                  if (save.ledger.chain.isNotEmpty)
                    Text('Chain ${save.ledger.chain} step ${save.ledger.chainStep}', style: ValeText.small),
                  Text('Foods, tools, friends', style: ValeText.small),
                  for (final entry in save.ledger.affinity.entries)
                    StatLine(label: entry.key, value: entry.value * 100, color: const Color(0xFFE2A15A)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This moment', style: ValeText.title),
                  const SizedBox(height: 8),
                  for (var i = 0; i < BondMind.actions.length; i++)
                    StatLine(
                      label: BondMind.actions[i],
                      value: ((learned[i] + 2) / 5 * 100).clamp(0, 100),
                      color: i == greedy ? elementColor(kin.def.element) : const Color(0xFFC8B49A),
                    ),
                  const SizedBox(height: 4),
                  Text('Bars are the stored scores for this exact moment, shifted so a fresh kin sits in the middle.', style: ValeText.small),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The hours you keep', style: ValeText.title),
                  const SizedBox(height: 6),
                  Text(
                    save.routine.total < 4
                        ? 'Keep a few of the same hours and ${kin.name} will start waiting for them.'
                        : _hourLine(save, now),
                    style: ValeText.body,
                  ),
                  const SizedBox(height: 8),
                  for (final phase in DayPhase.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${phaseLabel(phase)}: ${save.routine.phaseLean(phase) ?? 'still learning'}',
                        style: ValeText.body,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CreamCard(
              child: Text(
                save.ear.mass < 3
                    ? 'Pattern Duet has not echoed you yet. Win a round and the next phrase can borrow your transitions.'
                    : '${kin.name} has heard ${save.ear.mass.round()} of your opening glyphs. Later duets borrow those jumps.',
                style: ValeText.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hourLine(ValeSave save, DateTime now) {
    final care = save.routine.anticipate(now.hour);
    if (care == null) return 'Nothing strong at this hour yet. ${save.kin.name} is still collecting your pattern.';
    return 'Around ${now.hour}:00 they expect you to $care. That expectation pulls the ask, on top of the learned scores.';
  }
}

class _Heat extends StatelessWidget {
  const _Heat({required this.visits});
  final Map<String, int> visits;

  @override
  Widget build(BuildContext context) {
    const zones = ['glen', 'house', 'shed', 'pavilion', 'woods', 'brook', 'meadow', 'ruins'];
    final maxV = zones.map((z) => visits[z] ?? 0).fold<int>(1, (a, b) => a > b ? a : b);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final zone in zones)
          Container(
            width: 64,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFFE7F6D8), const Color(0xFF2E7D42), (visits[zone] ?? 0) / maxV),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(zone, style: ValeText.small.copyWith(fontSize: 10)),
          ),
      ],
    );
  }
}

Widget _pill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFFFF6EA), borderRadius: BorderRadius.circular(12), border: Border.all(color: ValeColors.gold)),
    child: Text(text, style: ValeText.small),
  );
}

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(valeProvider).save;
    if (save == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: ValeColors.creamDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ScreenHeader(title: 'Journal', onBack: () => ref.read(valeProvider.notifier).go(ValeScreen.den)),
            if (save.memories.isEmpty) const Text('The glen is still new.', style: ValeText.body),
            for (final note in save.memories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CreamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_when(note.at), style: ValeText.small),
                      const SizedBox(height: 4),
                      Text(note.text, style: ValeText.body),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _when(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes} min ago';
    if (delta.inHours < 36) return '${delta.inHours} h ago';
    return '${delta.inDays} d ago';
  }
}

class EvolveScreen extends ConsumerStatefulWidget {
  const EvolveScreen({super.key});

  @override
  ConsumerState<EvolveScreen> createState() => _EvolveScreenState();
}

class _EvolveScreenState extends ConsumerState<EvolveScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(valeProvider);
    final save = state.save;
    if (save == null) return const SizedBox.shrink();
    final kin = save.kin;
    ref.listen<ValeState>(valeProvider, (previous, next) {
      if (previous?.evolvePhase != 'flash' && next.evolvePhase == 'flash') {
        _flash.forward(from: 0).whenComplete(() {
          if (mounted) ref.read(valeProvider.notifier).finishRite();
        });
        ValeTone.play(ValeSound.rite);
      }
    });
    final nextTitle = kin.stage >= 2 ? kin.def.titleFor(2) : kin.def.titleFor(kin.stage + (state.evolveApplied ? 0 : 1));
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          GlenStage(species: kin.species, interactive: false),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),
                  CreamCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          state.evolvePhase == 'revealed' ? '${kin.name} is a $nextTitle' : 'The glen holds its breath',
                          style: ValeText.title,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.evolvePhase == 'revealed'
                              ? 'Care changed the shape of them. The hours you kept are still in the Bond Mind.'
                              : '${kin.name} has been cared for enough to take the next form. This is the rite.',
                          style: ValeText.body,
                        ),
                        const SizedBox(height: 12),
                        if (state.evolvePhase == 'ready')
                          ValeButton(label: 'Begin the rite', onPressed: () => ref.read(valeProvider.notifier).beginRite()),
                        if (state.evolvePhase == 'revealed')
                          ValeButton(label: 'Back to the glen', onPressed: () => ref.read(valeProvider.notifier).leaveRite()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.evolvePhase == 'flash')
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(_flash),
              child: const ColoredBox(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: ValeText.small,
    filled: true,
    fillColor: Colors.white,
    counterStyle: ValeText.small,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ValeColors.ink, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ValeColors.goldDeep, width: 2)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ValeColors.ink, width: 2.4)),
  );
}
