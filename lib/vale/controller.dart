import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/spatial_mind.dart';
import 'care_sim.dart';
import 'learning.dart';
import 'models.dart';
import 'save_store.dart';

class ValeState {
  const ValeState({
    required this.booted,
    required this.screen,
    required this.keeperDraft,
    required this.nameDraft,
    required this.starterIndex,
    required this.script,
    required this.scriptCursor,
    required this.pose,
    required this.poseToken,
    required this.fxToken,
    required this.evolvePhase,
    required this.evolveApplied,
    required this.sparBusy,
    this.save,
    this.aside,
    this.pattern,
    this.spar,
    this.lastNuzzle,
    this.interactMode = InteractMode.overview,
    this.clip = 'Idle',
    this.emote,
    this.lookYaw = 0,
    this.lookPitch = 0,
    this.queuedFood,
  });

  final bool booted;
  final ValeSave? save;
  final ValeScreen screen;
  final String keeperDraft;
  final String nameDraft;
  final int starterIndex;
  final List<String> script;
  final int scriptCursor;
  final String? aside;
  final KinPose pose;
  final int poseToken;
  final int fxToken;
  final String evolvePhase;
  final bool evolveApplied;
  final PatternSession? pattern;
  final SparSession? spar;
  final bool sparBusy;
  final DateTime? lastNuzzle;
  final InteractMode interactMode;
  final String clip;
  final String? emote;
  final double lookYaw;
  final double lookPitch;
  final String? queuedFood;

  factory ValeState.initial() {
    return const ValeState(
      booted: false,
      screen: ValeScreen.title,
      keeperDraft: '',
      nameDraft: '',
      starterIndex: 0,
      script: [],
      scriptCursor: 0,
      pose: KinPose.idle,
      poseToken: 0,
      fxToken: 0,
      evolvePhase: 'ready',
      evolveApplied: false,
      sparBusy: false,
      interactMode: InteractMode.overview,
      clip: 'Idle',
    );
  }

  ValeState copy({
    bool? booted,
    ValeSave? save,
    bool clearSave = false,
    ValeScreen? screen,
    String? keeperDraft,
    String? nameDraft,
    int? starterIndex,
    List<String>? script,
    int? scriptCursor,
    String? aside,
    bool clearAside = false,
    KinPose? pose,
    int? poseToken,
    int? fxToken,
    String? evolvePhase,
    bool? evolveApplied,
    PatternSession? pattern,
    bool clearPattern = false,
    SparSession? spar,
    bool clearSpar = false,
    bool? sparBusy,
    DateTime? lastNuzzle,
    InteractMode? interactMode,
    String? clip,
    String? emote,
    bool clearEmote = false,
    double? lookYaw,
    double? lookPitch,
    String? queuedFood,
    bool clearFood = false,
  }) {
    return ValeState(
      booted: booted ?? this.booted,
      save: clearSave ? null : (save ?? this.save),
      screen: screen ?? this.screen,
      keeperDraft: keeperDraft ?? this.keeperDraft,
      nameDraft: nameDraft ?? this.nameDraft,
      starterIndex: starterIndex ?? this.starterIndex,
      script: script ?? this.script,
      scriptCursor: scriptCursor ?? this.scriptCursor,
      aside: clearAside ? null : (aside ?? this.aside),
      pose: pose ?? this.pose,
      poseToken: poseToken ?? this.poseToken,
      fxToken: fxToken ?? this.fxToken,
      evolvePhase: evolvePhase ?? this.evolvePhase,
      evolveApplied: evolveApplied ?? this.evolveApplied,
      pattern: clearPattern ? null : (pattern ?? this.pattern),
      spar: clearSpar ? null : (spar ?? this.spar),
      sparBusy: sparBusy ?? this.sparBusy,
      lastNuzzle: lastNuzzle ?? this.lastNuzzle,
      interactMode: interactMode ?? this.interactMode,
      clip: clip ?? this.clip,
      emote: clearEmote ? null : (emote ?? this.emote),
      lookYaw: lookYaw ?? this.lookYaw,
      lookPitch: lookPitch ?? this.lookPitch,
      queuedFood: clearFood ? null : (queuedFood ?? this.queuedFood),
    );
  }
}

final valeProvider = StateNotifierProvider<ValeController, ValeState>((ref) {
  final controller = ValeController(SaveStore());
  ref.onDispose(controller.disposeTimer);
  return controller;
});

class ValeController extends StateNotifier<ValeState> {
  ValeController(this._store) : super(ValeState.initial()) {
    _boot();
  }

  final SaveStore _store;
  final math.Random _rng = math.Random();
  Timer? _timer;

  void disposeTimer() => _timer?.cancel();

  Future<void> _boot() async {
    final loaded = await _store.load();
    ValeSave? save = loaded;
    if (save != null) {
      final elapsed = DateTime.now().difference(save.lastSeen);
      if (elapsed.inMinutes >= 20) save = CareSim.applyOffline(save, elapsed);
    }
    if (!mounted) return;
    if (state.booted && state.screen == ValeScreen.den) return;
    state = state.copy(booted: true, save: save, screen: ValeScreen.title);
    _timer ??= Timer.periodic(const Duration(seconds: 6), (_) => _heartbeat());
  }

  void debugEnterGlen(ValeSave save) {
    state = state.copy(booted: true, save: save, screen: ValeScreen.den);
    _timer ??= Timer.periodic(const Duration(seconds: 6), (_) => _heartbeat());
  }

  Future<void> onResume() async {
    final save = state.save;
    if (save == null) return;
    final elapsed = DateTime.now().difference(save.lastSeen);
    if (elapsed.inMinutes < 20) return;
    final next = CareSim.applyOffline(save, elapsed);
    state = state.copy(save: next, aside: next.memories.isEmpty ? null : next.memories.first.text);
    await _store.write(next);
  }

  Future<void> persist() async {
    final save = state.save;
    if (save == null) return;
    try {
      await _store.write(save.copy(lastSeen: DateTime.now()));
    } catch (_) {}
  }

  void openRite() {
    state = state.copy(
      screen: ValeScreen.evolve,
      evolvePhase: 'ready',
      evolveApplied: false,
    );
  }

  void go(ValeScreen screen) {
    state = state.copy(
      screen: screen,
      pose: screen == ValeScreen.den ? KinPose.idle : state.pose,
      clip: screen == ValeScreen.den ? 'Idle' : state.clip,
      interactMode: screen == ValeScreen.den ? InteractMode.overview : state.interactMode,
      clearPattern: screen != ValeScreen.pattern,
      clearSpar: screen != ValeScreen.spar,
      lookYaw: 0,
      lookPitch: 0,
    );
  }

  void enterInteract(InteractMode mode) {
    final clip = switch (mode) {
      InteractMode.overview => 'Idle',
      InteractMode.feed => 'Idle',
      InteractMode.brush => 'Idle',
      InteractMode.play => 'Idle',
      InteractMode.rest => 'Sleep',
      InteractMode.walk => 'Walk',
    };
    state = state.copy(
      screen: ValeScreen.den,
      interactMode: mode,
      clip: clip,
      pose: mode == InteractMode.rest ? KinPose.sleep : KinPose.idle,
      poseToken: state.poseToken + 1,
      emote: switch (mode) {
        InteractMode.feed => '?',
        InteractMode.play => '♪',
        InteractMode.rest => 'z',
        InteractMode.walk => '!',
        _ => '♥',
      },
    );
  }

  void queueTreat(String foodId) {
    answerWhistle('feed');
    state = state.copy(queuedFood: foodId, interactMode: InteractMode.feed);
  }

  int _count(ValeSave save, String id) => (save.ledger.loot[id] ?? 0) + (save.bag[id] ?? 0);

  ValeSave? _spend(ValeSave save, Map<String, int> cost) {
    for (final entry in cost.entries) {
      if (_count(save, entry.key) < entry.value) return null;
    }
    final loot = Map<String, int>.from(save.ledger.loot);
    final bag = Map<String, int>.from(save.bag);
    for (final entry in cost.entries) {
      var left = entry.value;
      final fromLoot = loot[entry.key] ?? 0;
      final takeLoot = left < fromLoot ? left : fromLoot;
      if (takeLoot > 0) {
        loot[entry.key] = fromLoot - takeLoot;
        if (loot[entry.key] == 0) loot.remove(entry.key);
        left -= takeLoot;
      }
      if (left > 0) bag[entry.key] = (bag[entry.key] ?? 0) - left;
    }
    return save.copy(bag: bag, ledger: save.ledger.copy(loot: loot));
  }

  void cook(String recipe) {
    final save = state.save;
    if (save == null) return;
    final cost = switch (recipe) {
      'tart' => {'sunberry': 2},
      'puff' => {'dewberry': 1, 'mushroom': 1},
      'nectar' => {'dewberry': 1, 'seed': 1},
      _ => <String, int>{},
    };
    final spent = _spend(save, cost);
    if (spent == null) {
      state = state.copy(aside: 'The stove is short an ingredient.');
      return;
    }
    final loot = Map<String, int>.from(spent.ledger.loot);
    loot[recipe] = (loot[recipe] ?? 0) + 1;
    final kin = spent.kin.copy(xp: spent.kin.xp + 6);
    final next = spent.copy(kin: kin, ledger: spent.ledger.copy(loot: loot));
    state = state.copy(save: next, aside: 'The $recipe is in the bag. Feed it from the pack.');
    _store.write(next);
  }

  void feedTreat(String id) {
    final save = state.save;
    if (save == null) return;
    final spent = _spend(save, {id: 1});
    if (spent == null) {
      state = state.copy(aside: 'That treat is gone.');
      return;
    }
    final buff = switch (id) {
      'tart' => 'Speed',
      'puff' => 'Chain',
      'nectar' => 'Curiosity',
      _ => '',
    };
    final kin = spent.kin.copy(
      satiation: clampStat(spent.kin.satiation + 42),
      joy: clampStat(spent.kin.joy + 12),
      bond: clampStat(spent.kin.bond + 10),
      xp: spent.kin.xp + 36,
    );
    final next = spent.copy(kin: kin, ledger: spent.ledger.copy(buff: buff));
    state = state.copy(save: next, aside: '$id eaten. Buff: $buff. +36 xp.', emote: '♥', fxToken: state.fxToken + 1);
    _store.write(next);
  }

  void craft(String gear) {
    final save = state.save;
    if (save == null) return;
    final cost = switch (gear) {
      'planter' => {'twig': 2, 'seed': 1},
      'chimes' => {'pebble': 2, 'twig': 1},
      'lure' => {'pebble': 1, 'seed': 1},
      _ => <String, int>{},
    };
    final spent = _spend(save, cost);
    if (spent == null) {
      state = state.copy(aside: 'The bench needs more foraged pieces.');
      return;
    }
    final loot = Map<String, int>.from(spent.ledger.loot);
    loot[gear] = (loot[gear] ?? 0) + 1;
    final kin = spent.kin.copy(xp: spent.kin.xp + 14, joy: clampStat(spent.kin.joy + (gear == 'chimes' ? 8 : 2)));
    final next = spent.copy(kin: kin, ledger: spent.ledger.copy(loot: loot, social: gear == 'chimes' ? clampStat(spent.ledger.social + 8) : spent.ledger.social));
    state = state.copy(
      save: next,
      aside: switch (gear) {
        'planter' => 'A planter sits by the porch and will sprout each new day.',
        'chimes' => 'Wind chimes hang from the homestead roof.',
        _ => 'The lure is in the bag. Place it from the pack.',
      },
    );
    _store.write(next);
  }

  void placeLure(double x, double y) {
    final save = state.save;
    if (save == null || (save.ledger.loot['lure'] ?? 0) < 1) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    loot['lureX'] = x.round();
    loot['lureY'] = y.round();
    final next = save.copy(ledger: save.ledger.copy(loot: loot));
    state = state.copy(save: next, aside: 'The lure glows where you stand.');
    _store.write(next);
  }

  void turnInBotany() {
    final save = state.save;
    if (save == null) return;
    final spent = _spend(save, {'dewberry': 2, 'mushroom': 1});
    if (spent == null) {
      state = state.copy(aside: 'Lina still wants 2 dewberries and 1 mushroom.');
      return;
    }
    final loot = Map<String, int>.from(spent.ledger.loot);
    loot['seed'] = (loot['seed'] ?? 0) + 1;
    final kin = spent.kin.copy(xp: spent.kin.xp + 28, bond: clampStat(spent.kin.bond + 3));
    state = state.copy(save: spent.copy(kin: kin, ledger: spent.ledger.copy(loot: loot)), aside: 'Lina presses a mystic seed into your hand. +28 xp.');
  }

  void armTrial() {
    final save = state.save;
    if (save == null) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    loot['trial'] = 1;
    state = state.copy(save: save.copy(ledger: save.ledger.copy(loot: loot)), aside: 'Bram drops rings across the meadow. Thirty seconds.');
  }

  bool claimTrial() {
    final save = state.save;
    if (save == null || (save.ledger.loot['trial'] ?? 0) == 0) return false;
    final loot = Map<String, int>.from(save.ledger.loot)..remove('trial');
    state = state.copy(save: save.copy(ledger: save.ledger.copy(loot: loot)));
    return true;
  }

  void finishTrial(int score) {
    final save = state.save;
    if (save == null) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    const tricks = ['spin', 'backflip', 'sing', 'wave'];
    final known = tricks.where((t) => (loot['trick:$t'] ?? 0) > 0).length;
    if (score >= 3 && known < tricks.length) loot['trick:${tricks[known]}'] = 1;
    final kin = save.kin.copy(xp: save.kin.xp + 20 + score * 4, joy: clampStat(save.kin.joy + 6));
    state = state.copy(save: save.copy(kin: kin, ledger: save.ledger.copy(loot: loot)), aside: 'Trial score $score. A new trick sticks if you cleared three rings.');
  }

  void lightRune(int step) {
    final save = state.save;
    if (save == null) return;
    if (save.ledger.equipped != 'lantern') {
      state = state.copy(aside: 'The rune stays dark without the firefly lantern.');
      return;
    }
    final loot = Map<String, int>.from(save.ledger.loot);
    final have = loot['rune'] ?? 0;
    if (step != have) {
      state = state.copy(aside: 'That pedestal is out of order.');
      return;
    }
    loot['rune'] = have + 1;
    var kin = save.kin.copy(xp: save.kin.xp + 12);
    if (loot['rune'] == 4) {
      loot['crest'] = 1;
      kin = kin.copy(xp: kin.xp + 40, bond: clampStat(kin.bond + 8));
    }
    state = state.copy(
      save: save.copy(kin: kin, ledger: save.ledger.copy(loot: loot)),
      aside: loot['crest'] == 1 ? 'The shrine opens. A celestial crest settles on ${kin.name}.' : 'Rune ${loot['rune']} wakes.',
    );
  }

  void blowWhistle(String zone) {
    final save = state.save;
    if (save == null) return;
    state = state.copy(
      save: save.copy(ledger: save.ledger.copy(whistleZone: zone)),
      aside: '${save.kin.name} listens. The next thing you do becomes the cue for $zone.',
    );
  }

  void answerWhistle(String cue) {
    final save = state.save;
    if (save == null || save.ledger.whistleZone.isEmpty) return;
    final cues = Map<String, int>.from(save.ledger.cues);
    final key = '${save.ledger.whistleZone}|$cue';
    cues[key] = (cues[key] ?? 0) + 1;
    final action = SpatialMind.goalForCue(cue);
    final learned = SpatialMind.learn(
      table: save.ledger.spatialQ,
      stateKey: 'whistle|${save.ledger.whistleZone}',
      action: action,
      reward: 0.8,
      nextKey: 'whistle|${save.ledger.whistleZone}',
      visits: cues[key]!,
    );
    state = state.copy(
      save: save.copy(ledger: save.ledger.copy(cues: cues, whistleZone: '', spatialQ: learned)),
      aside: 'Whistle in ${save.ledger.whistleZone} now leans toward $cue.',
    );
  }

  void consolidateDreams() {
    final save = state.save;
    if (save == null || save.ledger.dreams.isEmpty) return;
    final phase = phaseAt(DateTime.now());
    if (phase != DayPhase.night && phase != DayPhase.dusk) return;
    final table = replayDreams(save.ledger.spatialQ, save.ledger.dreams);
    final note = save.ledger.dreams.take(4).map((trace) => trace.icon).join(' -> ');
    state = state.copy(
      save: save.copy(
        ledger: save.ledger.copy(
          spatialQ: table,
          dreamNote: note.isEmpty ? 'A quiet night.' : note,
          consolidated: save.ledger.consolidated + 1,
        ),
      ),
      aside: 'Memories consolidated tonight.',
    );
    final kept = state.save;
    if (kept != null) _store.write(kept);
  }

  void markPlanter(int day) {
    final save = state.save;
    if (save == null) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    if ((loot['planterDay'] ?? -1) >= day) return;
    loot['planterDay'] = day;
    final next = save.copy(ledger: save.ledger.copy(loot: loot));
    state = state.copy(save: next);
    _store.write(next);
  }

  void cyclePhase() {
    const order = [DayPhase.dawn, DayPhase.day, DayPhase.dusk, DayPhase.night];
    final current = debugPhaseOverride ?? phaseAt(DateTime.now());
    debugPhaseOverride = order[(order.indexOf(current) + 1) % order.length];
    state = state.copy(fxToken: state.fxToken + 1, aside: 'Time is ${phaseLabel(debugPhaseOverride!)}.');
  }

  void debugBoost() {
    final save = state.save;
    if (save == null) return;
    final kin = save.kin.copy(xp: save.kin.xp + xpStepForLevel(save.kin.level));
    const rack = ['ball', 'whistle', 'can', 'lantern'];
    final tools = {...save.ledger.tools};
    for (final tool in rack) {
      if (!tools.contains(tool)) {
        tools.add(tool);
        break;
      }
    }
    final next = save.copy(kin: kin, ledger: save.ledger.copy(tools: tools));
    state = state.copy(save: next, aside: '${kin.name} is level ${kin.level}.');
    _store.write(next);
  }

  void grantSupplies() {
    final save = state.save;
    if (save == null) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    for (final id in ['sunberry', 'dewberry', 'mushroom', 'pebble', 'twig', 'seed']) {
      loot[id] = (loot[id] ?? 0) + 5;
    }
    final next = save.copy(ledger: save.ledger.copy(loot: loot));
    state = state.copy(save: next, aside: 'The pack gains five of each forage.');
    _store.write(next);
  }

  Future<void> resetSave() async {
    await _store.erase();
    debugPhaseOverride = null;
    state = ValeState.initial().copy(booted: true);
  }

  void equipTool(String tool) {
    final save = state.save;
    if (save == null) return;
    if (tool != 'none' && !save.ledger.tools.contains(tool)) return;
    state = state.copy(save: save.copy(ledger: save.ledger.copy(equipped: tool)));
  }

  void unlockTool(String tool) {
    final save = state.save;
    if (save == null || save.ledger.tools.contains(tool)) return;
    final tools = {...save.ledger.tools, tool};
    state = state.copy(
      save: save.copy(ledger: save.ledger.copy(tools: tools, equipped: tool)),
      aside: '$tool is on the rack now.',
    );
  }

  void collectItem(String id) {
    final save = state.save;
    if (save == null) return;
    final loot = Map<String, int>.from(save.ledger.loot);
    loot[id] = (loot[id] ?? 0) + 1;
    final affinity = Map<String, double>.from(save.ledger.affinity);
    final key = 'food:$id';
    if (affinity.containsKey(key)) affinity[key] = clampStat((affinity[key]! + 0.08) * 100) / 100;
    state = state.copy(
      save: _withXp(save, 24).copy(ledger: save.ledger.copy(loot: loot, foraged: save.ledger.foraged + 1, affinity: affinity)),
      aside: 'Picked up $id. +24 xp.',
      emote: '!',
    );
    final kept = state.save;
    if (kept != null) _store.write(kept);
  }

  void meetFriend(String name) {
    final save = state.save;
    if (save == null) return;
    final affinity = Map<String, double>.from(save.ledger.affinity);
    final key = 'friend:$name';
    affinity[key] = clampStat(((affinity[key] ?? 0) + 0.12) * 100) / 100;
    final kin = save.kin.copy(joy: clampStat(save.kin.joy + 4), bond: clampStat(save.kin.bond + 2), xp: save.kin.xp + 22);
    state = state.copy(
      save: save.copy(
        kin: kin,
        ledger: save.ledger.copy(
          social: clampStat(save.ledger.social + 6),
          friendMeets: save.ledger.friendMeets + 1,
          affinity: affinity,
        ),
      ),
      aside: '$name leans in. Social bond rises. +22 xp.',
      emote: '♥',
      fxToken: state.fxToken + 1,
    );
  }

  void shapeSpatial(double reward) {
    final save = state.save;
    if (save == null || save.ledger.lastKey.isEmpty) return;
    final counts = Map<String, int>.from(save.ledger.saCounts);
    final countKey = '${save.ledger.lastKey}#${save.ledger.lastAction}';
    final visits = counts[countKey] ?? 0;
    var nextTable = SpatialMind.learn(
      table: save.ledger.spatialQ,
      stateKey: save.ledger.lastKey,
      action: save.ledger.lastAction,
      reward: reward,
      nextKey: save.ledger.lastKey,
      visits: visits,
    );
    var chain = save.ledger.chain;
    var chainStep = save.ledger.chainStep;
    var heldKey = save.ledger.heldKey;
    var heldAction = save.ledger.heldAction;
    var heldReward = save.ledger.heldReward;
    var heldIcon = save.ledger.heldIcon;
    final goalName = SpatialMind.goals[save.ledger.lastAction.clamp(0, SpatialMind.goals.length - 1)];
    SkillChain? link;
    for (final item in skillChains) {
      if (item.steps.contains(goalName)) link = item;
    }
    if (link != null) {
      if (chain != link.name) {
        chain = link.name;
        chainStep = 0;
        heldKey = '';
      }
      if (chainStep < link.steps.length && link.steps[chainStep] == goalName) {
        if (heldKey.isNotEmpty) {
          nextTable = SpatialMind.creditPair(
            table: nextTable,
            firstKey: heldKey,
            firstAction: heldAction,
            firstReward: heldReward,
            secondKey: save.ledger.lastKey,
            secondAction: save.ledger.lastAction,
            secondReward: reward,
            thirdKey: save.ledger.lastKey,
          );
        }
        heldKey = save.ledger.lastKey;
        heldAction = save.ledger.lastAction;
        heldReward = reward;
        heldIcon = link.icons[chainStep];
        chainStep += 1;
        if (chainStep >= link.steps.length) {
          chain = '';
          chainStep = 0;
        }
      }
    }
    if (save.ledger.buff == 'Chain') {
      nextTable = SpatialMind.learn(
        table: nextTable,
        stateKey: save.ledger.lastKey,
        action: save.ledger.lastAction,
        reward: reward,
        nextKey: save.ledger.lastKey,
        visits: visits,
      );
    }
    final dreams = rememberDream(
      save.ledger.dreams,
      DreamTrace(
        stateKey: save.ledger.lastKey,
        action: save.ledger.lastAction,
        reward: reward,
        nextKey: save.ledger.lastKey,
        icon: heldIcon.isEmpty ? goalName : heldIcon,
      ),
    );
    counts[countKey] = visits + 1;
    final affinity = Map<String, double>.from(save.ledger.affinity);
    final toolKey = 'tool:${save.ledger.equipped}';
    if (affinity.containsKey(toolKey)) {
      affinity[toolKey] = clampStat((affinity[toolKey]! + reward * 0.05) * 100) / 100;
    }
    final gained = reward > 0 ? 16 : 0;
    state = state.copy(
      save: _withXp(save, gained).copy(
        ledger: save.ledger.copy(
          spatialQ: nextTable,
          saCounts: counts,
          spatialSteps: save.ledger.spatialSteps + 1,
          affinity: affinity,
          chain: chain,
          chainStep: chainStep,
          heldKey: heldKey,
          heldAction: heldAction,
          heldReward: heldReward,
          heldIcon: heldIcon,
          dreams: dreams,
        ),
      ),
      aside: reward > 0 ? '${save.kin.name} keeps that path. +16 xp.' : '${save.kin.name} turns from that idea.',
    );
    final kept = state.save;
    if (kept != null) _store.write(kept);
  }

  void rememberGoal({
    required String key,
    required int action,
    required String goal,
    required String zone,
  }) {
    final save = state.save;
    if (save == null) return;
    final zones = Map<String, int>.from(save.ledger.zoneVisits);
    final firstLook = (zones[zone] ?? 0) == 0;
    zones[zone] = (zones[zone] ?? 0) + 1;
    final base = save.copy(
      ledger: save.ledger.copy(
        lastKey: key,
        lastAction: action,
        goal: goal,
        zoneVisits: zones,
      ),
    );
    state = state.copy(save: firstLook ? _withXp(base, 12) : base, aside: firstLook ? 'New ground. +12 xp.' : state.aside);
  }

  ValeSave _withXp(ValeSave save, int amount) {
    if (amount <= 0) return save;
    final before = save.kin.level;
    final kin = save.kin.copy(xp: save.kin.xp + amount);
    return save.copy(kin: kin);
  }

  void setLook(double yaw, double pitch) {
    state = state.copy(lookYaw: yaw.clamp(-1.2, 1.2), lookPitch: pitch.clamp(-0.6, 0.6));
  }

  void playClip(String clip, {String? emote, KinPose? pose}) {
    state = state.copy(
      clip: clip,
      emote: emote,
      pose: pose ?? state.pose,
      poseToken: state.poseToken + 1,
    );
  }

  Future<void> giveTreat(String foodId) async {
    playClip('Eat', emote: '♥', pose: KinPose.eat);
    state = state.copy(clearFood: true);
    await feed(foodId);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    state = state.copy(clip: 'Happy_Hop', pose: KinPose.cheer, emote: '♥', fxToken: state.fxToken + 1);
  }

  Future<void> finishBrush(double quality) async {
    answerWhistle('brush');
    final loved = quality >= 0.45;
    playClip(loved ? 'Pet_Enjoy' : 'Refuse', emote: loved ? '♥' : '!', pose: loved ? KinPose.groom : KinPose.sulk);
    await groom(quality);
    if (loved) {
      state = state.copy(fxToken: state.fxToken + 1);
    }
  }

  Future<void> catchPlay(double score) async {
    playClip(score > 0.55 ? 'Happy_Hop' : 'Walk', emote: score > 0.55 ? '♪' : '?', pose: KinPose.hop);
    await playResult('ribbons', score);
  }

  void setKeeperDraft(String value) => state = state.copy(keeperDraft: value);

  void setNameDraft(String value) => state = state.copy(nameDraft: value);

  void setStarter(int index) => state = state.copy(starterIndex: index);

  void beginNaming() => state = state.copy(screen: ValeScreen.naming, script: const [], scriptCursor: 0);

  void toStarter() {
    final keeper = state.keeperDraft.trim();
    state = state.copy(
      screen: ValeScreen.starter,
      keeperDraft: keeper.isEmpty ? 'Keeper' : keeper,
    );
  }

  Future<void> welcomeKin() async {
    final species = SpeciesCatalog.all[state.starterIndex.clamp(0, 2)];
    final keeper = state.keeperDraft.trim().isEmpty ? 'Keeper' : state.keeperDraft.trim();
    final named = state.nameDraft.trim().isEmpty ? species.name : state.nameDraft.trim();
    final save = ValeSave.fresh(keeper: keeper, kinName: _clip(named, 14), species: species.id);
    state = state.copy(
      save: save,
      screen: ValeScreen.den,
      script: _intro(save),
      scriptCursor: 0,
      pose: KinPose.hop,
      poseToken: state.poseToken + 1,
      fxToken: state.fxToken + 1,
      aside: '${save.kin.name} looks around the glen.',
    );
    await _store.write(save);
  }

  void continueGame() {
    final save = state.save;
    if (save == null) return;
    final showIntro = !save.seenIntro;
    final seeded = showIntro ? save : _withBid(save);
    state = state.copy(
      save: seeded,
      screen: ValeScreen.den,
      script: showIntro ? _intro(seeded) : const [],
      scriptCursor: 0,
      pose: seeded.kin.asleep ? KinPose.sleep : KinPose.idle,
      aside: showIntro ? null : _asideFor(seeded),
    );
  }

  Future<void> releaseKin() async {
    await _store.erase();
    if (!mounted) return;
    state = ValeState.initial().copy(booted: true);
  }

  void advanceScript() {
    if (state.script.isEmpty) return;
    final next = state.scriptCursor + 1;
    if (next >= state.script.length) {
      var save = state.save;
      if (save != null && !save.seenIntro) {
        save = _withBid(save.copy(seenIntro: true));
        state = state.copy(script: const [], scriptCursor: 0, save: save, aside: _asideFor(save));
        _store.write(save);
      } else {
        state = state.copy(script: const [], scriptCursor: 0);
      }
    } else {
      state = state.copy(scriptCursor: next);
    }
  }

  Future<void> feed(String foodId) => _act('feed', () {
        final save = state.save!;
        return CareSim.feed(save.kin, foodId, save.bag);
      }, replaceBag: true);

  Future<void> groom(double quality) => _act('groom', () => CareSim.groom(state.save!.kin, quality));

  Future<void> rest() async {
    enterInteract(InteractMode.rest);
    await _act('rest', () => CareSim.rest(state.save!.kin), pose: KinPose.sleep);
  }

  Future<void> playResult(String gameId, double score) => _act(
        'play',
        () => CareSim.play(state.save!.kin, gameId, score),
        gamesAdd: gameId,
        pose: score > 0.5 ? KinPose.cheer : KinPose.hop,
        then: ValeScreen.den,
      );

  Future<void> finishOuting(Map<String, int> found, int gleam, String line) => _act(
        'outing',
        () => CareSim.outing(state.save!.kin, found, gleam, line),
        mergeBag: true,
        pose: KinPose.hop,
        then: ValeScreen.den,
      );

  Future<void> praiseOrNuzzle() async {
    final save = state.save;
    if (save == null) return;
    answerWhistle(save.kin.pendingBid == 'trick' ? 'trick' : 'follow');
    if (save.kin.pendingBid == 'trick') {
      await _act('praise', () => CareSim.praise(save.kin), pose: KinPose.cheer);
      return;
    }
    final now = DateTime.now();
    if (state.lastNuzzle != null && now.difference(state.lastNuzzle!).inSeconds < 8) {
      state = state.copy(aside: '${save.kin.name} is already close.');
      return;
    }
    final outcome = CareSim.nuzzle(save.kin);
    final next = save.copy(kin: outcome.kin, lastSeen: now);
    state = state.copy(
      save: next,
      aside: outcome.reaction,
      pose: KinPose.cheer,
      poseToken: state.poseToken + 1,
      fxToken: state.fxToken + 1,
      lastNuzzle: now,
    );
    await _store.write(next);
  }

  Future<void> wake() async {
    final save = state.save;
    if (save == null || !save.kin.asleep) return;
    final kin = save.kin.copy(asleep: false);
    final next = save.copy(kin: kin, lastSeen: DateTime.now());
    state = state.copy(
      save: next,
      pose: KinPose.idle,
      poseToken: state.poseToken + 1,
      aside: '${kin.name} stretches, slow and warm.',
    );
    await _store.write(next);
  }

  Future<void> passHours(int hours) async {
    final save = state.save;
    if (save == null) return;
    final next = CareSim.passHours(save, hours);
    state = state.copy(
      save: next,
      aside: next.memories.first.text,
      pose: KinPose.idle,
      poseToken: state.poseToken + 1,
      screen: ValeScreen.den,
    );
    await _store.write(next);
    _openRiteIfReady(next, fromCare: true);
  }

  void startPattern() {
    final save = state.save;
    if (save == null) return;
    final echo = save.ear.mass >= 3 && _rng.nextDouble() < 0.75;
    final length = (3 + save.kin.stage).clamp(3, 6);
    final sequence = save.ear.compose(length, _rng, echo: echo);
    state = state.copy(
      screen: ValeScreen.pattern,
      pattern: PatternSession(
        sequence: sequence,
        phase: 'show',
        round: 1,
        echo: echo,
        input: const [],
        misses: 0,
        roundsCleared: 0,
        targetRounds: 3,
        token: 1,
      ),
    );
  }

  void patternReady() {
    final session = state.pattern;
    if (session == null || session.phase != 'show') return;
    state = state.copy(pattern: session.copy(phase: 'input'));
  }

  Future<void> patternTap(int glyph) async {
    final session = state.pattern;
    final save = state.save;
    if (session == null || save == null || session.phase != 'input') return;
    final expected = session.sequence[session.input.length];
    if (glyph != expected) {
      final misses = session.misses + 1;
      if (misses >= 3) {
        final score = (session.roundsCleared / session.targetRounds) * 0.55;
        state = state.copy(clearPattern: true);
        await playResult('pattern', score);
        return;
      }
      state = state.copy(
        pattern: session.copy(
          misses: misses,
          input: const [],
          phase: 'show',
          token: session.token + 1,
        ),
        aside: 'A miss. Watch once more.',
      );
      return;
    }
    final input = [...session.input, glyph];
    if (input.length < session.sequence.length) {
      state = state.copy(pattern: session.copy(input: input));
      return;
    }
    final ear = save.ear.observe(input);
    final cleared = session.roundsCleared + 1;
    final withEar = save.copy(ear: ear);
    if (cleared >= session.targetRounds) {
      final score = (1 - session.misses * 0.12).clamp(0.35, 1.0);
      state = state.copy(save: withEar, clearPattern: true);
      await playResult('pattern', score);
      return;
    }
    final echo = ear.mass >= 3 && _rng.nextDouble() < 0.8;
    final sequence = ear.compose((session.sequence.length + 1).clamp(3, 7), _rng, echo: echo);
    state = state.copy(
      save: withEar,
      aside: echo ? '${save.kin.name} offers a phrase learned from you.' : 'Next phrase.',
      pattern: session.copy(
        sequence: sequence,
        phase: 'show',
        round: session.round + 1,
        echo: echo,
        input: const [],
        roundsCleared: cleared,
        token: session.token + 1,
      ),
    );
  }

  void startSpar() {
    final save = state.save;
    if (save == null) return;
    final others = SpeciesId.values.where((id) => id != save.kin.species).toList();
    final rival = others[_rng.nextInt(others.length)];
    const names = ['Bram', 'Neri', 'Soot', 'Lumen', 'Pebble', 'Cinder', 'Moss', 'Dapple'];
    final foe = SpeciesCatalog.of(rival);
    final maxHp = 34 + save.kin.stage * 8 + save.kin.level * 2;
    final key = MoveMind.keyFor(foe: foe.element, staminaFraction: 1, lastFoeKind: 'none');
    state = state.copy(
      screen: ValeScreen.spar,
      sparBusy: false,
      spar: SparSession(
        rivalSpecies: rival,
        rivalName: names[_rng.nextInt(names.length)],
        foeStamina: maxHp,
        selfStamina: maxHp,
        maxStamina: maxHp,
        log: '${names.last} waits in the ring. ${save.kin.name} leans toward a move.',
        selfGuarding: false,
        foeGuarding: false,
        suggestedIndex: MoveMind.suggest(save.sparQ, key),
        lastFoeKind: 'none',
        sparKey: key,
        turn: 0,
        done: false,
        won: false,
        rewarded: false,
      ),
    );
    final spar = state.spar!;
    state = state.copy(
      spar: spar.copy(log: '${spar.rivalName} pads into the ring.'),
    );
  }

  void sparMove(int index) {
    final spar = state.spar;
    final save = state.save;
    if (spar == null || save == null || spar.done) return;
    final selfDef = save.kin.def;
    final foeDef = SpeciesCatalog.of(spar.rivalSpecies);
    final move = selfDef.moves[index.clamp(0, selfDef.moves.length - 1)];
    final foeMove = _foeMove(foeDef);
    var selfHp = spar.selfStamina;
    var foeHp = spar.foeStamina;
    final selfGuard = move.isGuard;
    var foeGuard = false;
    var dealt = 0;
    var taken = 0;
    final buffer = StringBuffer('${save.kin.name} uses ${move.name}. ');
    if (move.isGuard) {
      buffer.write(move.line);
    } else {
      dealt = _damage(move, foeDef.element, spar.foeGuarding, save.kin.patternSkill);
      if (move.isRally) selfHp = math.min(spar.maxStamina, selfHp + 7);
      foeHp -= dealt;
      final mod = typeMod(move.element, foeDef.element);
      final gloss = mod > 1.05 ? ' It lands bright.' : (mod < 0.95 ? ' It glances.' : '');
      buffer.write('$dealt hits.$gloss');
    }
    var won = foeHp <= 0;
    if (!won) {
      buffer.write(' ${spar.rivalName} uses ${foeMove.name}.');
      if (foeMove.isGuard) {
        foeGuard = true;
        buffer.write(' A brace.');
      } else {
        taken = _damage(foeMove, selfDef.element, selfGuard, 0);
        if (foeMove.isRally) foeHp = math.min(spar.maxStamina, foeHp + 6);
        selfHp -= taken;
        buffer.write(' $taken back.');
      }
    }
    final turn = spar.turn + 1;
    var done = won || selfHp <= 0 || turn >= 8;
    if (done && !won && selfHp > 0 && foeHp > 0) won = selfHp >= foeHp;
    if (done && selfHp <= 0) won = false;
    selfHp = math.max(0, selfHp);
    foeHp = math.max(0, foeHp);
    final nextKey = MoveMind.keyFor(
      foe: foeDef.element,
      staminaFraction: spar.maxStamina == 0 ? 0 : selfHp / spar.maxStamina,
      lastFoeKind: foeMove.kind,
    );
    var reward = (dealt - taken * 0.65) / 10;
    if (done && won) reward += 0.85;
    if (done && !won) reward -= 0.45;
    final sparQ = MoveMind.learn(
      table: save.sparQ,
      stateKey: spar.sparKey,
      action: index.clamp(0, 2),
      reward: reward,
      nextKey: nextKey,
    );
    state = state.copy(
      save: save.copy(sparQ: sparQ, lastSeen: DateTime.now()),
      pose: done && won ? KinPose.cheer : KinPose.hop,
      poseToken: state.poseToken + 1,
      spar: spar.copy(
        foeStamina: foeHp,
        selfStamina: selfHp,
        log: buffer.toString(),
        selfGuarding: selfGuard,
        foeGuarding: foeGuard,
        suggestedIndex: MoveMind.suggest(sparQ, nextKey),
        lastFoeKind: foeMove.kind,
        sparKey: nextKey,
        turn: turn,
        done: done,
        won: done && won,
      ),
    );
  }

  Future<void> closeSpar() async {
    final spar = state.spar;
    if (spar == null) {
      go(ValeScreen.play);
      return;
    }
    if (!spar.done || spar.rewarded) {
      state = state.copy(screen: ValeScreen.play, clearSpar: true);
      return;
    }
    state = state.copy(spar: spar.copy(rewarded: true));
    await playResult('spar', spar.won ? 0.9 : 0.4);
  }

  void beginRite() {
    if (state.evolvePhase != 'ready') return;
    state = state.copy(evolvePhase: 'flash');
  }

  Future<void> finishRite() async {
    final save = state.save;
    if (save == null || state.evolveApplied) return;
    final kin = CareSim.evolve(save.kin);
    final title = kin.def.titleFor(kin.stage);
    final next = save.copy(
      kin: kin,
      lastSeen: DateTime.now(),
      memories: CareSim.remember(save.memories, '${kin.name} becomes a $title.'),
    );
    state = state.copy(
      save: next,
      evolveApplied: true,
      evolvePhase: 'revealed',
      pose: KinPose.cheer,
      poseToken: state.poseToken + 1,
      fxToken: state.fxToken + 1,
      aside: 'The glen answers. ${kin.name} is a $title now.',
    );
    await _store.write(next);
  }

  void leaveRite() => state = state.copy(screen: ValeScreen.den, pose: KinPose.cheer);

  Future<void> _act(
    String action,
    CareOutcome Function() produce, {
    bool replaceBag = false,
    bool mergeBag = false,
    String? gamesAdd,
    KinPose pose = KinPose.hop,
    ValeScreen? then,
  }) async {
    final before = state.save;
    if (before == null) return;
    final outcome = produce();
    if (outcome.rejected) {
      state = state.copy(aside: outcome.reaction, pose: KinPose.sulk, poseToken: state.poseToken + 1);
      return;
    }
    final bid = before.kin.pendingBid;
    var table = before.qTable;
    var steps = before.mindSteps;
    if (bid != null && before.kin.bidStateKey.isNotEmpty) {
      var reward = responseReward(
        bid: bid,
        action: action,
        satiation: before.kin.satiation,
        energy: before.kin.energy,
        coat: before.kin.coat,
      );
      if (outcome.overfed) reward -= 0.32;
      table = BondMind.learn(
        table: table,
        stateKey: before.kin.bidStateKey,
        action: BondMind.indexOf(bid),
        reward: reward,
        nextKey: BondMind.keyFor(outcome.kin, DateTime.now()),
      );
      steps += 1;
    }
    var routine = before.routine;
    const watched = {'feed', 'play', 'groom', 'rest'};
    if (watched.contains(action)) {
      routine = routine.observe(action, DateTime.now().hour);
    }
    var bag = before.bag;
    if (replaceBag) bag = outcome.bag;
    if (mergeBag) {
      bag = Map<String, int>.from(before.bag);
      outcome.bag.forEach((key, value) {
        bag[key] = (bag[key] ?? 0) + value;
      });
    }
    var games = before.gamesPlayed;
    if (gamesAdd != null) games = {...games, gamesAdd};
    final kin = outcome.kin;
    final leveled = kin.level > before.kin.level;
    var memories = before.memories;
    if (outcome.memory.isNotEmpty) memories = CareSim.remember(memories, outcome.memory);
    if (leveled) {
      memories = CareSim.remember(memories, '${kin.name} reaches level ${kin.level}.');
    }
    final next = before.copy(
      kin: kin,
      bag: bag,
      gleam: before.gleam + outcome.gleamGain,
      qTable: table,
      mindSteps: steps,
      routine: routine,
      gamesPlayed: games,
      memories: memories,
      lastSeen: DateTime.now(),
    );
    final screen = then ?? state.screen;
    state = state.copy(
      save: next,
      screen: screen,
      aside: leveled ? '${kin.name} reaches level ${kin.level}.' : outcome.reaction,
      pose: kin.asleep ? KinPose.sleep : pose,
      poseToken: state.poseToken + 1,
      fxToken: state.fxToken + 1,
      clearPattern: true,
      clearSpar: then != null,
    );
    await _store.write(next);
    _openRiteIfReady(next, fromCare: true);
  }

  void _openRiteIfReady(ValeSave save, {required bool fromCare}) {
    if (!fromCare) return;
    if (!readyToEvolve(save.kin, save.gamesPlayed)) return;
    if (state.screen == ValeScreen.pattern || state.screen == ValeScreen.spar || state.screen == ValeScreen.ribbons) return;
    if (state.screen == ValeScreen.evolve && state.evolvePhase == 'flash') return;
    openRite();
  }

  ValeSave _withBid(ValeSave save) {
    if (save.kin.pendingBid != null || save.kin.asleep) return save;
    final now = DateTime.now();
    final care = save.routine.anticipate(now.hour);
    final key = BondMind.keyFor(save.kin, now);
    final index = BondMind.choose(
      table: save.qTable,
      stateKey: key,
      kin: save.kin,
      steps: save.mindSteps,
      anticipatedBid: careToBid[care],
      rng: _rng,
    );
    final kin = save.kin.copy(
      pendingBid: BondMind.actions[index],
      bidAt: now,
      bidStateKey: key,
    );
    return save.copy(kin: kin);
  }

  void _heartbeat() {
    final save = state.save;
    if (save == null || state.screen != ValeScreen.den) return;
    if (save.kin.asleep || state.script.isNotEmpty) return;
    final now = DateTime.now();
    final bid = save.kin.pendingBid;
    if (bid != null && save.kin.bidAt != null && now.difference(save.kin.bidAt!).inSeconds >= 28) {
      final table = BondMind.learn(
        table: save.qTable,
        stateKey: save.kin.bidStateKey.isEmpty ? BondMind.keyFor(save.kin, now) : save.kin.bidStateKey,
        action: BondMind.indexOf(bid),
        reward: responseReward(
          bid: bid,
          action: 'ignore',
          satiation: save.kin.satiation,
          energy: save.kin.energy,
          coat: save.kin.coat,
        ),
        nextKey: BondMind.keyFor(save.kin, now),
      );
      final kin = save.kin.copy(clearBid: true, clearBidAt: true);
      final next = save.copy(kin: kin, qTable: table, mindSteps: save.mindSteps + 1, lastSeen: now);
      state = state.copy(save: next, aside: '${kin.name} settles. The ask went unanswered.');
      _store.write(next);
      return;
    }
    if (bid != null) {
      if (state.interactMode == InteractMode.overview) {
        final clip = switch (bid) {
          'nap' => 'Sleep',
          'play' || 'trick' => 'Happy_Hop',
          'brush' => 'Idle',
          _ => 'Idle',
        };
        state = state.copy(clip: clip, emote: bid == 'meal' ? '?' : state.emote);
      }
      return;
    }
    final care = save.routine.anticipate(now.hour);
    final anticipated = careToBid[care];
    final key = BondMind.keyFor(save.kin, now);
    final index = BondMind.choose(
      table: save.qTable,
      stateKey: key,
      kin: save.kin,
      steps: save.mindSteps,
      anticipatedBid: anticipated,
      rng: _rng,
    );
    final chosen = BondMind.actions[index];
    final kin = save.kin.copy(pendingBid: chosen, bidAt: now, bidStateKey: key);
    final next = save.copy(kin: kin, lastSeen: now);
    final ambient = switch (chosen) {
      'nap' => 'Sleep',
      'play' || 'trick' => 'Happy_Hop',
      'brush' => 'Pet_Enjoy',
      'meal' => 'Idle',
      _ => _rng.nextBool() ? 'Idle' : 'Happy_Hop',
    };
    state = state.copy(
      save: next,
      aside: _asideFor(next),
      pose: chosen == 'play' || chosen == 'trick' ? KinPose.hop : KinPose.idle,
      poseToken: state.poseToken + 1,
      clip: state.interactMode == InteractMode.overview ? ambient : state.clip,
      emote: switch (chosen) {
        'meal' => '?',
        'play' => '♪',
        'brush' => '♥',
        'nap' => 'z',
        _ => '!',
      },
    );
  }

  String _asideFor(ValeSave save) {
    final kin = save.kin;
    final bid = kin.pendingBid;
    if (bid == null) return '${kin.name} is here.';
    final base = switch (bid) {
      'meal' => '${kin.name} is waiting by the bowl.',
      'play' => '${kin.name} hops a circle, ready.',
      'brush' => '${kin.name} leans toward your hand.',
      'nap' => '${kin.name} is blinking slow.',
      'trick' => '${kin.name} tries a small bow.',
      _ => '${kin.name} keeps looking at the path.',
    };
    final care = save.routine.anticipate(DateTime.now().hour);
    if (care != null && careToBid[care] == bid) {
      return '$base This is about your usual hour.';
    }
    return base;
  }

  List<String> _intro(ValeSave save) {
    return [
      'The glen is quiet, and it is yours, ${save.keeperName}.',
      '${save.kin.name} is learning you already. Answer what they ask, and keep roughly the same hours. They notice.',
      'Feed, brush, play, rest, or walk the path. Bond Mind is where the learning shows.',
    ];
  }

  MoveDef _foeMove(SpeciesDef foe) {
    final roll = _rng.nextDouble();
    if (roll < 0.62) return foe.moves[0];
    if (roll < 0.84) return foe.moves[2];
    return foe.moves[1];
  }

  int _damage(MoveDef move, KinElement defense, bool guarding, double skill) {
    if (move.isGuard) return 0;
    var amount = move.power.toDouble();
    if (move.isRally) amount *= 0.55;
    amount *= typeMod(move.element, defense);
    amount *= 1 + skill / 150;
    amount *= 0.9 + _rng.nextDouble() * 0.22;
    if (guarding) amount *= 0.42;
    return amount.round().clamp(1, 20);
  }

  String _clip(String value, int max) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= max) return clean;
    return clean.substring(0, max);
  }
}
