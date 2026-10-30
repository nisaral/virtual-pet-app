import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/spatial_mind.dart';
import '../world/interiors.dart';
import '../world/overworld_renderer.dart';
import '../world/play_panels.dart';
import 'care_sim.dart';
import 'chrome.dart';
import 'controller.dart';
import 'models.dart';
import 'tone.dart';

const double kWorld = mapSize;
Offset get kBowl => pavilion.rect.center;
Offset get kBed => Offset(homestead.rect.center.dx, homestead.rect.bottom + 24);
Offset get kArena => shed.rect.center;

class GlenStage extends ConsumerStatefulWidget {
  const GlenStage({
    super.key,
    required this.species,
    this.interactive = true,
    this.showStage = true,
  });

  final SpeciesId species;
  final bool interactive;
  final bool showStage;

  @override
  ConsumerState<GlenStage> createState() => GlenStageState();
}

class GlenStageState extends ConsumerState<GlenStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final math.Random _rng = math.Random(4);

  double px = 620;
  double py = 1680;
  double pz = 0;
  double vz = 0;
  double vx = 0;
  double vy = 0;
  Facing face = Facing.down;
  Act act = Act.idle;
  double anim = 0;
  double blink = 0;
  bool eyesShut = false;

  double camX = 620;
  double camY = 1680;
  double zoom = 1;

  Offset stick = Offset.zero;
  bool rubbing = false;
  int rubs = 0;

  double ballX = 900;
  double ballY = 1100;
  double ballZ = 0;
  double ballVx = 0;
  double ballVy = 0;
  double ballVz = 0;
  bool ballLive = false;

  Offset? goal;
  String? goalKind;
  bool eating = false;
  double eatT = 0;
  bool sleeping = false;
  final List<_Pop> pops = [];
  final List<_Dust> dust = [];
  final List<Offset> berries = [];
  int stroll = 0;
  List<Offset> get folkSpots => [for (final folk in folks) Offset(folk.x, folk.y)];

  final List<_Npc> folks = [
    _Npc('Sprout', 'sprout', 520, 480),
    _Npc('Aqua', 'aqua', 2100, 1500),
    _Npc('Lina', 'botanist', 640, 420),
    _Npc('Bram', 'trainer', 1500, 2300),
  ];
  final List<_Loot> loot = [
    _Loot('sunberry', 480, 560),
    _Loot('dewberry', 900, 380),
    _Loot('mushroom', 1600, 2200),
    _Loot('pebble', 2200, 1500),
    _Loot('twig', 400, 1900),
    _Loot('seed', 2400, 500),
  ];
  String thought = '';
  double thinkT = 0;
  String nearby = 'none';
  String room = 'out';
  double ix = 180;
  double iy = 220;
  double trialLeft = 0;
  int trialScore = 0;
  final List<Offset> rings = [];
  static const runes = <Offset>[
    Offset(2200, 360),
    Offset(2360, 480),
    Offset(2480, 320),
    Offset(2300, 560),
  ];

  static const trees = <Offset>[
    Offset(280, 360),
    Offset(460, 280),
    Offset(1320, 300),
    Offset(1480, 520),
    Offset(240, 1100),
    Offset(360, 1380),
    Offset(1280, 1240),
    Offset(1500, 980),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_step)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _step(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    anim += dt;
    blink += dt;
    if (blink > 3.2) {
      eyesShut = blink < 3.38;
      if (blink > 3.45) blink = 0;
    }
    if (room != 'out') {
      if (stick.distance > 0.18) {
        ix = (ix + stick.dx * 90 * dt).clamp(40, 340);
        iy = (iy + stick.dy * 90 * dt).clamp(40, 340);
      }
      if (mounted) setState(() {});
      return;
    }
    if (trialLeft > 0) {
      trialLeft -= dt;
      if (trialLeft <= 0) {
        ref.read(valeProvider.notifier).finishTrial(trialScore);
        rings.clear();
        trialScore = 0;
      } else {
        for (final ring in List<Offset>.from(rings)) {
          if ((Offset(px, py) - ring).distance < 36) {
            rings.remove(ring);
            trialScore += 1;
            pops.add(_Pop('♪', ring));
            HapticFeedback.mediumImpact();
          }
        }
      }
    } else {
      final pending = ref.read(valeProvider).save?.ledger.loot['trial'] ?? 0;
      if (pending > 0 && ref.read(valeProvider.notifier).claimTrial()) {
        trialLeft = 30;
        trialScore = 0;
        rings
          ..clear()
          ..addAll([const Offset(1500, 2300), const Offset(1680, 2200), const Offset(1400, 2460), const Offset(1760, 2400)]);
      }
    }
    if (!widget.interactive) {
      vx = math.sin(anim * 0.7) * 18;
      vy = math.cos(anim * 0.45) * 12;
      px = 800 + math.sin(anim * 0.6) * 40;
      py = 820 + math.cos(anim * 0.4) * 24;
      face = vx >= 0 ? Facing.right : Facing.left;
      act = Act.walk;
      camX = px;
      camY = py;
      if (mounted) setState(() {});
      return;
    }
    final mode = ref.read(valeProvider).interactMode;
    final save = ref.read(valeProvider).save;
    _orders(mode, save);
    if (stick.distance > 0.18) {
      goal = null;
      goalKind = null;
      final sp = stick.distance > 0.72 ? 168.0 : 108.0;
      final pace = save?.ledger.buff == 'Speed' ? 1.25 : 1.0;
      vx = stick.dx * sp * pace;
      vy = stick.dy * sp * pace;
      act = sleeping ? Act.idle : (sp > 140 ? Act.run : Act.walk);
      sleeping = false;
    } else if (goal != null && !eating && !sleeping) {
      final d = goal! - Offset(px, py);
      if (d.distance < 28) {
        vx = 0;
        vy = 0;
        _arrive();
      } else {
        final pace = save?.ledger.buff == 'Speed' ? 1.25 : 1.0;
        vx = d.dx / d.distance * 120 * pace;
        vy = d.dy / d.distance * 120 * pace;
        act = Act.walk;
      }
    } else if (!eating && !sleeping && mode == InteractMode.overview) {
      _autonomous(save);
    } else if (!eating) {
      vx *= 0.8;
      vy *= 0.8;
      if (vx.abs() + vy.abs() < 8) {
        vx = 0;
        vy = 0;
        if (!sleeping && act != Act.eat && act != Act.kick) act = Act.idle;
      }
    }
    if (eating) {
      eatT += dt;
      act = Act.eat;
      vx = 0;
      vy = 0;
      face = Facing.down;
      if (eatT > 1.15) {
        eating = false;
        eatT = 0;
        final food = ref.read(valeProvider).queuedFood;
        if (food != null) {
          ref.read(valeProvider.notifier).giveTreat(food);
          pops.add(_Pop('+', Offset(px, py - 20)));
        }
        act = Act.hop;
        vz = 220;
      }
    }
    if (vz != 0 || pz > 0) {
      vz -= 620 * dt;
      pz += vz * dt;
      if (pz <= 0) {
        pz = 0;
        vz = 0;
        if (act == Act.hop || act == Act.jump) act = Act.idle;
      } else {
        act = Act.jump;
      }
    }
    final nextX = (px + vx * dt).clamp(40.0, kWorld - 40);
    final nextY = (py + vy * dt).clamp(40.0, kWorld - 40);
    if (!solidAt(nextX, py)) px = nextX;
    if (!solidAt(px, nextY)) py = nextY;
    _folks(dt);
    _mind(dt);
    if (vx.abs() > 12 || vy.abs() > 12) {
      face = _facing(vx, vy);
      if (_rng.nextDouble() < dt * 8) {
        dust.add(_Dust(Offset(px, py + 8)));
      }
      if (_rng.nextDouble() < dt * 3) HapticFeedback.selectionClick();
    }
    _yard(save);
    _ball(dt);
    _pops(dt);
    final follow = 1 - math.pow(0.001, dt).toDouble();
    camX += (px - camX) * follow;
    camY += (py - camY) * follow;
    final wantZoom = mode == InteractMode.brush ? 1.35 : 1.0;
    zoom += (wantZoom - zoom) * (1 - math.pow(0.01, dt).toDouble());
    if (mounted) setState(() {});
  }

  void _orders(InteractMode mode, ValeSave? save) {
    final food = ref.read(valeProvider).queuedFood;
    if (mode == InteractMode.feed && food != null && goalKind != 'bowl' && !eating) {
      goal = kBowl;
      goalKind = 'bowl';
    }
    if (mode == InteractMode.rest && goalKind != 'bed' && !sleeping) {
      goal = kBed;
      goalKind = 'bed';
    }
    if (mode == InteractMode.play && !ballLive) {
      ballLive = true;
      ballX = kArena.dx;
      ballY = kArena.dy;
      ballZ = 40;
      ballVz = 180;
    }
    if (mode == InteractMode.walk && goalKind != 'stroll') {
      stroll = 0;
      goalKind = 'stroll';
      goal = const Offset(240, 240);
      if (berries.isEmpty) {
        berries.addAll([const Offset(300, 700), const Offset(1400, 800), const Offset(700, 200)]);
      }
    }
    if (mode == InteractMode.overview && goalKind == 'stroll') {
      goalKind = null;
      goal = null;
    }
    if (save != null && save.kin.asleep) {
      sleeping = true;
    } else if (sleeping && goalKind != 'bed') {
      sleeping = false;
      if (act == Act.sleep) act = Act.idle;
    }
  }

  void _arrive() {
    final kind = goalKind;
    goal = null;
    if (kind == 'bowl') {
      eating = true;
      eatT = 0;
      goalKind = null;
      ValeTone.play(ValeSound.good);
    } else if (kind == 'bed') {
      sleeping = true;
      act = Act.sleep;
      face = Facing.down;
      goalKind = null;
      ref.read(valeProvider.notifier).rest();
    } else if (kind == 'stroll') {
      stroll = (stroll + 1) % 4;
      goal = switch (stroll) {
        0 => const Offset(240, 240),
        1 => const Offset(1360, 240),
        2 => const Offset(1360, 1360),
        _ => const Offset(240, 1360),
      };
      goalKind = 'stroll';
    } else if (kind == 'ball') {
      _kick(fromPet: true);
      goalKind = null;
    } else if (kind == 'tree') {
      goalKind = null;
      act = Act.hop;
      vz = 200;
      pops.add(_Pop('berry', Offset(px, py - 30)));
      HapticFeedback.lightImpact();
    } else {
      goalKind = null;
    }
  }

  void _autonomous(ValeSave? save) {
    if (goal != null) return;
    if (anim.floor() % 5 != 0) return;
    if ((anim * 10).floor().isOdd) return;
    final bid = save?.kin.pendingBid;
    if (bid == 'meal') {
      goal = kBowl;
      goalKind = 'sniff';
    } else if (bid == 'nap' && save!.kin.energy < 40) {
      goal = kBed;
      goalKind = 'sniff';
    } else if (bid == 'play' && ballLive) {
      goal = Offset(ballX, ballY);
      goalKind = 'ball';
    } else if (_rng.nextDouble() < 0.35) {
      goal = Offset(200 + _rng.nextDouble() * 1200, 200 + _rng.nextDouble() * 1200);
      goalKind = 'wander';
    }
  }

  void _ball(double dt) {
    if (!ballLive) return;
    ballVz -= 640 * dt;
    ballX += ballVx * dt;
    ballY += ballVy * dt;
    ballZ += ballVz * dt;
    ballVx *= 0.985;
    ballVy *= 0.985;
    if (ballZ <= 0) {
      ballZ = 0;
      if (ballVz < -40) {
        ballVz = -ballVz * 0.55;
      } else {
        ballVz = 0;
        ballVx *= 0.9;
        ballVy *= 0.9;
      }
    }
    ballX = ballX.clamp(30, kWorld - 30);
    ballY = ballY.clamp(30, kWorld - 30);
    if ((Offset(px, py) - Offset(ballX, ballY)).distance < 36 && (ballVx.abs() + ballVy.abs()) < 40 && act != Act.eat) {
      if (ref.read(valeProvider).interactMode == InteractMode.play) {
        _kick(fromPet: true);
      }
    }
  }

  void _kick({required bool fromPet}) {
    final ang = fromPet ? math.atan2(kArena.dy - py, kArena.dx - px) + 0.4 : _rng.nextDouble() * math.pi * 2;
    ballVx = math.cos(ang) * 260;
    ballVy = math.sin(ang) * 260;
    ballVz = 240;
    act = Act.kick;
    face = _facing(ballVx, ballVy);
    HapticFeedback.mediumImpact();
  }

  void _pops(double dt) {
    for (final p in pops) {
      p.life += dt;
      p.at = p.at.translate(0, -18 * dt);
    }
    pops.removeWhere((p) => p.life > 1.1);
    for (final d in dust) {
      d.life += dt;
    }
    dust.removeWhere((d) => d.life > 0.45);
    for (final b in List<Offset>.from(berries)) {
      if ((Offset(px, py) - b).distance < 36) {
        berries.remove(b);
        pops.add(_Pop('item', b));
        ValeTone.play(ValeSound.good);
        ref.read(valeProvider.notifier).playClip('Happy_Hop', emote: '!', pose: KinPose.hop);
      }
    }
  }

  void _yard(ValeSave? save) {
    if (save == null) return;
    final bag = save.ledger.loot;
    if ((bag['chimes'] ?? 0) > 0 && anim.floor() % 7 == 0) {
      for (final folk in folks) {
        if (folk.kind != 'sprout' && folk.kind != 'aqua') continue;
        folk.x += (homestead.rect.center.dx - folk.x) * 0.04;
        folk.y += (homestead.rect.bottom + 36 - folk.y) * 0.04;
      }
    }
    if ((bag['planter'] ?? 0) > 0 && (bag['planterDay'] ?? -1) < save.kin.daysTogether) {
      ref.read(valeProvider.notifier).markPlanter(save.kin.daysTogether);
      loot.add(_Loot('sunberry', homestead.rect.center.dx, homestead.rect.bottom + 28));
    }
    final lx = bag['lureX'];
    final ly = bag['lureY'];
    if (lx != null && ly != null && phaseAt(DateTime.now()) == DayPhase.night && _rng.nextDouble() < 0.004) {
      loot.add(_Loot(_rng.nextBool() ? 'mushroom' : 'seed', lx.toDouble() + 18, ly.toDouble()));
    }
  }

  void _folks(double dt) {
    nearby = 'none';
    for (final folk in folks) {
      folk.anim += dt;
      if (folk.wait > 0) {
        folk.wait -= dt;
        folk.vx = 0;
        folk.vy = 0;
      } else if (_rng.nextDouble() < dt * 0.4) {
        final ang = _rng.nextDouble() * math.pi * 2;
        folk.vx = math.cos(ang) * 36;
        folk.vy = math.sin(ang) * 36;
        folk.wait = 1.5 + _rng.nextDouble() * 2;
      }
      final nx = (folk.x + folk.vx * dt).clamp(80.0, kWorld - 80);
      final ny = (folk.y + folk.vy * dt).clamp(80.0, kWorld - 80);
      if (!solidAt(nx, folk.y)) folk.x = nx;
      if (!solidAt(folk.x, ny)) folk.y = ny;
      if ((Offset(px, py) - Offset(folk.x, folk.y)).distance < 90) {
        nearby = folk.kind;
        folk.emote = 'â™¥';
      } else {
        folk.emote = '';
      }
    }
  }

  void _mind(double dt) {
    thinkT += dt;
    if (thinkT < 4 || stick.distance > 0.18 || !widget.interactive) return;
    thinkT = 0;
    final save = ref.read(valeProvider).save;
    if (save == null) return;
    final zone = zoneAt(px, py);
    final key = SpatialMind.keyFor(
      phase: phaseAt(DateTime.now()),
      hunger: save.kin.satiation,
      energy: save.kin.energy,
      social: save.ledger.social,
      zone: zone,
      tool: save.ledger.equipped,
      nearby: nearby,
    );
    final action = SpatialMind.choose(
      table: save.ledger.spatialQ,
      stateKey: key,
      counts: save.ledger.saCounts,
      hunger: save.kin.satiation,
      energy: save.kin.energy,
      social: save.ledger.social,
      rng: _rng,
      steps: save.ledger.spatialSteps,
    );
    final goal = SpatialMind.goals[action];
    thought = SpatialMind.thoughtFor(goal);
    ref.read(valeProvider.notifier).rememberGoal(key: key, action: action, goal: goal, zone: zone);
    goalKind = 'mind';
    this.goal = switch (goal) {
      'GoTo_FoodBowl' => kBowl,
      'Forage_BerryBush' => const Offset(8 * 48, 6 * 48),
      'Visit_AnimalFriend' => Offset(folks[0].x, folks[0].y),
      'Follow_HumanNPC' => Offset(folks[2].x, folks[2].y),
      'Play_At_Shed' => kArena,
      'Rest_At_House' => kBed,
      'Perform_Trick' => Offset(px + 40, py),
      _ => Offset(200 + _rng.nextDouble() * 2000, 200 + _rng.nextDouble() * 2000),
    };
  }

  void interact() {
    if (room != 'out') {
      _indoor();
      return;
    }
    final tool = ref.read(valeProvider).save?.ledger.equipped ?? 'none';
    for (final item in loot) {
      if (!item.taken && (Offset(px, py) - Offset(item.x, item.y)).distance < 46) {
        item.taken = true;
        act = Act.hop;
        vz = 160;
        HapticFeedback.mediumImpact();
        ref.read(valeProvider.notifier).collectItem(item.id);
        ValeTone.play(ValeSound.good);
        return;
      }
    }
    for (final folk in folks) {
      if ((Offset(px, py) - Offset(folk.x, folk.y)).distance < 70) {
        folk.emote = '♪';
        act = Act.hop;
        vz = 160;
        if (folk.kind == 'botanist') {
          showPortraitTalk(context, ref, who: 'lina');
        } else if (folk.kind == 'trainer') {
          showPortraitTalk(context, ref, who: 'bram');
        } else {
          ref.read(valeProvider.notifier).meetFriend(folk.name.toLowerCase());
        }
        ValeTone.play(ValeSound.good);
        return;
      }
    }
    if ((Offset(px, py) - kBed).distance < 70) {
      setState(() => room = 'house');
      ValeTone.play(ValeSound.tap);
      return;
    }
    for (var i = 0; i < runes.length; i++) {
      if ((Offset(px, py) - runes[i]).distance < 50) {
        ref.read(valeProvider.notifier).lightRune(i);
        final crest = (ref.read(valeProvider).save?.ledger.loot['crest'] ?? 0) > 0;
        HapticFeedback.mediumImpact();
        if (crest) HapticFeedback.heavyImpact();
        return;
      }
    }
    if ((Offset(px, py) - kArena).distance < 80) {
      const tools = ['ball', 'whistle', 'can', 'lantern'];
      final missing = tools.where((t) => !(ref.read(valeProvider).save?.ledger.tools.contains(t) ?? false)).toList();
      if (missing.isNotEmpty) ref.read(valeProvider.notifier).unlockTool(missing.first);
      return;
    }
    if (tool == 'ball') {
      ballLive = true;
      ballX = px + 30;
      ballY = py + 20;
      ballZ = 20;
      _kick(fromPet: false);
      return;
    }
    if (tool == 'whistle') {
      goal = null;
      thought = '♪';
      ref.read(valeProvider.notifier).blowWhistle(zoneAt(px, py));
      for (final folk in folks) {
        folk.x += (px - folk.x) * 0.35;
        folk.y += (py - folk.y) * 0.35;
      }
      HapticFeedback.mediumImpact();
      return;
    }
    if (tool == 'can') {
      pops.add(_Pop('berry', Offset(px, py)));
      ref.read(valeProvider.notifier).collectItem('dewberry');
      return;
    }
    if ((Offset(px, py) - kBowl).distance < 70 && ref.read(valeProvider).queuedFood != null) {
      goal = kBowl;
      goalKind = 'bowl';
      return;
    }
    if (ballLive && (Offset(px, py) - Offset(ballX, ballY)).distance < 80) {
      _kick(fromPet: true);
      ref.read(valeProvider.notifier).catchPlay(0.7);
      return;
    }
    Offset? nearTree;
    for (final t in trees) {
      if ((Offset(px, py) - t).distance < 70) nearTree = t;
    }
    if (nearTree != null) {
      goal = nearTree;
      goalKind = 'tree';
      return;
    }
    act = Act.hop;
    vz = 180;
    pops.add(_Pop('heart', Offset(px, py)));
    ref.read(valeProvider.notifier).praiseOrNuzzle();
    HapticFeedback.lightImpact();
  }

  void _indoor() {
    final spots = room == 'house'
        ? {
            'bed': const Offset(240, 180),
            'stove': const Offset(120, 160),
            'shelf': const Offset(70, 90),
            'mat': const Offset(180, 250),
          }
        : {
            'bench': const Offset(180, 160),
            'mat': const Offset(180, 250),
          };
    String best = 'mat';
    var bestD = double.infinity;
    for (final entry in spots.entries) {
      final d = (entry.value - Offset(ix, iy)).distance;
      if (d < bestD) {
        bestD = d;
        best = entry.key;
      }
    }
    if (bestD > 80) return;
    if (best == 'mat') {
      setState(() => room = 'out');
      return;
    }
    if (best == 'bed') {
      ref.read(valeProvider.notifier).enterInteract(InteractMode.rest);
      ref.read(valeProvider.notifier).rest();
      ref.read(valeProvider.notifier).consolidateDreams();
      return;
    }
    if (best == 'stove') {
      showStove(context, ref);
      return;
    }
    if (best == 'bench') showBench(context, ref);
  }

  void travel(double x, double y) {
    px = x;
    py = y;
    camX = x;
    camY = y;
    goal = null;
    goalKind = null;
    room = 'out';
  }

  void hop() {
    if (pz > 1) return;
    vz = 280;
    act = Act.jump;
    HapticFeedback.lightImpact();
    ValeTone.play(ValeSound.tap);
  }

  Offset? _lure(ValeSave? save) {
    final x = save?.ledger.loot['lureX'];
    final y = save?.ledger.loot['lureY'];
    if (x == null || y == null) return null;
    return Offset(x.toDouble(), y.toDouble());
  }

  SkyMood? forcedSky;

  void cycleWeather() {
    const order = [SkyMood.sun, SkyMood.petals, SkyMood.rain, SkyMood.fireflies];
    final current = forcedSky ?? _skyMood();
    final index = order.indexOf(current);
    setState(() => forcedSky = order[(index + 1) % order.length]);
  }

  void forceChain() {
    thinkT = 8;
  }

  SkyMood _skyMood() {
    final forced = forcedSky;
    if (forced != null) return forced;
    final slice = anim % 90;
    if (slice < 28) return SkyMood.sun;
    if (slice < 50) return SkyMood.petals;
    if (slice < 72) return SkyMood.rain;
    return SkyMood.fireflies;
  }

  Facing _facing(double dx, double dy) {
    if (dx.abs() > dy.abs()) return dx >= 0 ? Facing.right : Facing.left;
    return dy >= 0 ? Facing.down : Facing.up;
  }

  @override
  Widget build(BuildContext context) {
    final phase = phaseAt(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: widget.interactive && ref.watch(valeProvider.select((s) => s.interactMode)) == InteractMode.brush
              ? (d) {
                  rubbing = true;
                  rubs++;
                  if (rubs % 5 == 0) {
                    pops.add(_Pop('heart', Offset(px + _rng.nextDouble() * 20, py)));
                    HapticFeedback.lightImpact();
                    ref.read(valeProvider.notifier).playClip('Pet_Enjoy', emote: 'â™¥', pose: KinPose.groom);
                  }
                }
              : null,
          onPanEnd: widget.interactive && ref.read(valeProvider).interactMode == InteractMode.brush
              ? (_) {
                  final q = (rubs / 18).clamp(0.2, 1.0);
                  ref.read(valeProvider.notifier).finishBrush(q);
                  rubs = 0;
                  rubbing = false;
                }
              : null,
          child: room == 'out'
              ? RepaintBoundary(
            child: CustomPaint(
            painter: _GlenPainter(
              frame: OverworldFrame(
                phase: phase,
                anim: anim,
                camX: camX,
                camY: camY,
                zoom: widget.showStage ? zoom : 1.2,
                pet: ActorDraw(
                  x: px,
                  y: py,
                  z: pz,
                  face: _toFace(face),
                  kind: switch (widget.species) {
                    SpeciesId.pipkin => 'sprout',
                    SpeciesId.marrow => 'aqua',
                    SpeciesId.solbit => 'ember',
                  },
                  anim: anim,
                  asleep: sleeping || eyesShut,
                  label: '',
                  stretch: (vx.abs() + vy.abs()) > 20 ? 1 : 0.2,
                  crest: (ref.read(valeProvider).save?.ledger.loot['crest'] ?? 0) > 0,
                ),
                actors: [
                  for (final folk in folks)
                    ActorDraw(
                      x: folk.x,
                      y: folk.y,
                      z: 0,
                      face: Face.down,
                      kind: folk.kind,
                      anim: folk.anim,
                      asleep: false,
                      label: folk.emote.isEmpty ? folk.name : '${folk.name} ${folk.emote}',
                    ),
                ],
                pickups: [for (final item in loot) PickupDraw(item.id, item.x, item.y, item.taken)],
                thought: thought,
                lantern: ref.read(valeProvider).save?.ledger.equipped == 'lantern',
                ball: ballLive ? Offset(ballX, ballY) : null,
                ballZ: ballZ,
                berriesLeft: {0, 1, 2, 3, 4, 5},
                weather: _skyMood(),
                planter: (ref.read(valeProvider).save?.ledger.loot['planter'] ?? 0) > 0,
                chimes: (ref.read(valeProvider).save?.ledger.loot['chimes'] ?? 0) > 0,
                lure: _lure(ref.read(valeProvider).save),
                buff: ref.read(valeProvider).save?.ledger.buff ?? '',
              ),
            ),
            child: const SizedBox.expand(),
          ),
          )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    InteriorRoom(
                      kind: room,
                      anim: anim,
                      crest: (ref.watch(valeProvider).save?.ledger.loot['crest'] ?? 0) > 0,
                      dreams: ref.watch(valeProvider).save?.ledger.dreams.map((trace) => trace.icon).toList() ?? const [],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Text(room == 'house' ? 'Leave' : 'Leave', style: ValeText.title.copyWith(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

enum Facing { down, up, left, right }

enum Act { idle, walk, run, jump, hop, eat, kick, sleep }

class _Pop {
  _Pop(this.kind, this.at);
  final String kind;
  Offset at;
  double life = 0;
}

class _Dust {
  _Dust(this.at);
  final Offset at;
  double life = 0;
}

class _Npc {
  _Npc(this.name, this.kind, this.x, this.y);
  final String name;
  final String kind;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double anim = 0;
  double wait = 0;
  String emote = '';
}

class _Loot {
  _Loot(this.id, this.x, this.y);
  final String id;
  final double x;
  final double y;
  bool taken = false;
}

Face _toFace(Facing facing) {
  return switch (facing) {
    Facing.down => Face.down,
    Facing.up => Face.up,
    Facing.left => Face.left,
    Facing.right => Face.right,
  };
}

class _GlenPainter extends CustomPainter {
  _GlenPainter({required this.frame});
  final OverworldFrame frame;
  final OverworldRenderer _renderer = OverworldRenderer();

  @override
  void paint(Canvas canvas, Size size) => _renderer.paint(canvas, size, frame);

  @override
  bool shouldRepaint(covariant _GlenPainter oldDelegate) => true;
}

class HandheldPad extends StatelessWidget {
  const HandheldPad({super.key, required this.onStick, required this.onInteract, required this.onHop});

  final ValueChanged<Offset> onStick;
  final VoidCallback onInteract;
  final VoidCallback onHop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          _Stick(onChanged: onStick),
          const Spacer(),
          _RoundButton(key: const Key('btn-b'), label: 'B', color: const Color(0xFFFF7A3C), onTap: onHop),
          const SizedBox(width: 10),
          _RoundButton(key: const Key('btn-a'), label: 'A', color: const Color(0xFF3CAF62), onTap: onInteract),
        ],
      ),
    );
  }
}

class _Stick extends StatefulWidget {
  const _Stick({required this.onChanged});
  final ValueChanged<Offset> onChanged;

  @override
  State<_Stick> createState() => _StickState();
}

class _StickState extends State<_Stick> {
  Offset knob = Offset.zero;

  void _drag(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    const radius = 28.0;
    final local = box.globalToLocal(global);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    var delta = local - center;
    if (delta.distance > radius) {
      delta = Offset(delta.dx / delta.distance * radius, delta.dy / delta.distance * radius);
    }
    setState(() => knob = delta);
    widget.onChanged(Offset(delta.dx / radius, delta.dy / radius));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _drag(d.globalPosition),
      onPanUpdate: (d) => _drag(d.globalPosition),
      onPanEnd: (_) {
        setState(() => knob = Offset.zero);
        widget.onChanged(Offset.zero);
      },
      onPanCancel: () {
        setState(() => knob = Offset.zero);
        widget.onChanged(Offset.zero);
      },
      child: SizedBox(
        width: 84,
        height: 84,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x66241B33),
            border: Border.all(color: Colors.white70),
          ),
          child: Center(
            child: Transform.translate(
              offset: knob,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEEFFF6EA)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 3))],
        ),
        child: Text(label, style: ValeText.title.copyWith(color: Colors.white)),
      ),
    );
  }
}

class GlassHud extends StatelessWidget {
  const GlassHud({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB3FFF6EA),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xCCFFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}
