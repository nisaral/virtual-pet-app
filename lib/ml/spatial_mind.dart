import 'dart:math' as math;

import '../vale/models.dart';

/// Spatial policy for one kin on the glen map.
///
/// The state is the hour, need bins, the zone underfoot, the tool in hand,
/// and whoever is nearest. Goals are places and social acts, not only the
/// old six care asks. An unvisited state-action pair pays an extra
/// curiosity bonus that fades as the count grows.
class SpatialMind {
  static const goals = [
    'GoTo_FoodBowl',
    'Forage_BerryBush',
    'Visit_AnimalFriend',
    'Follow_HumanNPC',
    'Play_At_Shed',
    'Rest_At_House',
    'Explore_New_Tile',
    'Perform_Trick',
  ];

  static const alpha = 0.28;
  static const gamma = 0.8;
  static const curiosityScale = 0.55;

  static int indexOf(String goal) {
    final i = goals.indexOf(goal);
    return i < 0 ? 0 : i;
  }

  static int bin(double value) {
    if (value < 34) return 0;
    if (value < 67) return 1;
    return 2;
  }

  static String keyFor({
    required DayPhase phase,
    required double hunger,
    required double energy,
    required double social,
    required String zone,
    required String tool,
    required String nearby,
  }) {
    return '${phase.name}|${bin(hunger)}|${bin(energy)}|${bin(social)}|$zone|$tool|$nearby';
  }

  static double intrinsic(int count) {
    return curiosityScale / math.sqrt(count + 1);
  }

  static Map<String, List<double>> learn({
    required Map<String, List<double>> table,
    required String stateKey,
    required int action,
    required double reward,
    required String nextKey,
    required int visits,
  }) {
    final bonus = intrinsic(visits);
    final next = Map<String, List<double>>.from(table);
    final row = List<double>.from(next[stateKey] ?? List<double>.filled(goals.length, 0));
    final future = next[nextKey] ?? List<double>.filled(goals.length, 0);
    var maxNext = future.first;
    for (final value in future) {
      if (value > maxNext) maxNext = value;
    }
    final target = reward + bonus + gamma * maxNext;
    final updated = row[action] + alpha * (target - row[action]);
    row[action] = updated.clamp(-2.0, 3.0).toDouble();
    next[stateKey] = row;
    return next;
  }

  static int choose({
    required Map<String, List<double>> table,
    required String stateKey,
    required Map<String, int> counts,
    required double hunger,
    required double energy,
    required double social,
    required math.Random rng,
    required int steps,
  }) {
    final epsilon = (0.35 * math.pow(0.985, steps)).clamp(0.08, 0.35).toDouble();
    if (rng.nextDouble() < epsilon) return rng.nextInt(goals.length);
    final scores = List<double>.generate(goals.length, (i) {
      final learned = (table[stateKey] ?? List<double>.filled(goals.length, 0))[i];
      final count = counts['$stateKey#$i'] ?? 0;
      var drive = learned + intrinsic(count);
      if (goals[i] == 'GoTo_FoodBowl') drive += (100 - hunger) / 80;
      if (goals[i] == 'Rest_At_House') drive += (100 - energy) / 90;
      if (goals[i] == 'Visit_AnimalFriend') drive += (100 - social) / 120;
      return drive;
    });
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  static double entropy(List<double> row) {
    if (row.isEmpty) return 0;
    final shifted = row.map((v) => math.exp(v.clamp(-2.0, 3.0))).toList();
    final sum = shifted.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return 0;
    var h = 0.0;
    for (final v in shifted) {
      final p = v / sum;
      if (p > 0) h -= p * math.log(p);
    }
    return h / math.log(row.length);
  }

  /// Two-step return: the earlier action is updated with
  /// r0 + γ r1 + γ² max Q(s2), after the later action takes its own TD step.
  static Map<String, List<double>> creditPair({
    required Map<String, List<double>> table,
    required String firstKey,
    required int firstAction,
    required double firstReward,
    required String secondKey,
    required int secondAction,
    required double secondReward,
    required String thirdKey,
  }) {
    final stepped = learn(
      table: table,
      stateKey: secondKey,
      action: secondAction,
      reward: secondReward,
      nextKey: thirdKey,
      visits: 0,
    );
    final future = stepped[thirdKey] ?? List<double>.filled(goals.length, 0);
    var maxNext = future.first;
    for (final value in future) {
      if (value > maxNext) maxNext = value;
    }
    final next = Map<String, List<double>>.from(stepped);
    final row = List<double>.from(next[firstKey] ?? List<double>.filled(goals.length, 0));
    final target = firstReward + gamma * secondReward + gamma * gamma * maxNext;
    row[firstAction] = (row[firstAction] + alpha * (target - row[firstAction])).clamp(-2.0, 3.0).toDouble();
    next[firstKey] = row;
    return next;
  }

  static String? favoredCue(Map<String, int> cues, String zone) {
    var best = '';
    var count = 0;
    cues.forEach((key, value) {
      if (key.startsWith('$zone|') && value > count) {
        count = value;
        best = key.split('|').last;
      }
    });
    return count == 0 ? null : best;
  }

  static int goalForCue(String cue) {
    return switch (cue) {
      'feed' => indexOf('GoTo_FoodBowl'),
      'brush' => indexOf('Perform_Trick'),
      'trick' => indexOf('Perform_Trick'),
      'follow' => indexOf('Follow_HumanNPC'),
      _ => indexOf('Explore_New_Tile'),
    };
  }

  static String thoughtFor(String goal) {
    return switch (goal) {
      'GoTo_FoodBowl' => 'berry',
      'Forage_BerryBush' => 'berry',
      'Visit_AnimalFriend' => 'friend',
      'Follow_HumanNPC' => 'friend',
      'Play_At_Shed' => 'ball',
      'Rest_At_House' => 'bed',
      'Explore_New_Tile' => '?',
      'Perform_Trick' => '♪',
      _ => '?',
    };
  }
}

class SkillChain {
  const SkillChain(this.name, this.steps, this.icons);
  final String name;
  final List<String> steps;
  final List<String> icons;
}

const skillChains = [
  SkillChain('Forage & Share', ['Forage_BerryBush', 'Forage_BerryBush', 'GoTo_FoodBowl'], ['Berry', 'Pick', 'Bowl']),
  SkillChain('Social Play', ['Play_At_Shed', 'Visit_AnimalFriend', 'Visit_AnimalFriend'], ['Ball', 'Friend', 'Play']),
  SkillChain('Gardening', ['Forage_BerryBush', 'Follow_HumanNPC', 'Perform_Trick'], ['Bush', 'Can', 'Heart']),
];

class DreamTrace {
  const DreamTrace({
    required this.stateKey,
    required this.action,
    required this.reward,
    required this.nextKey,
    required this.icon,
  });

  final String stateKey;
  final int action;
  final double reward;
  final String nextKey;
  final String icon;

  Map<String, dynamic> toJson() => {
        'stateKey': stateKey,
        'action': action,
        'reward': reward,
        'nextKey': nextKey,
        'icon': icon,
      };

  factory DreamTrace.fromJson(Map<String, dynamic> json) {
    return DreamTrace(
      stateKey: json['stateKey'] as String? ?? '',
      action: (json['action'] as num?)?.toInt() ?? 0,
      reward: (json['reward'] as num?)?.toDouble() ?? 0,
      nextKey: json['nextKey'] as String? ?? '',
      icon: json['icon'] as String? ?? '?',
    );
  }
}

List<DreamTrace> rememberDream(List<DreamTrace> buffer, DreamTrace trace) {
  final next = [...buffer, trace]..sort((a, b) => b.reward.compareTo(a.reward));
  if (next.length > 16) return next.sublist(0, 16);
  return next;
}

Map<String, List<double>> replayDreams(Map<String, List<double>> table, List<DreamTrace> traces) {
  var next = table;
  for (final trace in traces) {
    next = SpatialMind.learn(
      table: next,
      stateKey: trace.stateKey,
      action: trace.action,
      reward: trace.reward,
      nextKey: trace.nextKey,
      visits: 0,
    );
  }
  return next;
}

class WorldLedger {
  WorldLedger({
    this.social = 24,
    Map<String, int>? loot,
    Set<String>? tools,
    this.equipped = 'none',
    Map<String, int>? zoneVisits,
    Map<String, int>? saCounts,
    Map<String, double>? affinity,
    this.friendMeets = 0,
    this.foraged = 0,
    Map<String, List<double>>? spatialQ,
    this.spatialSteps = 0,
    this.goal = 'Explore_New_Tile',
    this.lastKey = '',
    this.lastAction = 0,
    this.chain = '',
    this.chainStep = 0,
    this.heldKey = '',
    this.heldAction = 0,
    this.heldReward = 0,
    this.heldIcon = '',
    this.whistleZone = '',
    Map<String, int>? cues,
    List<DreamTrace>? dreams,
    this.dreamNote = '',
    this.consolidated = 0,
    this.buff = '',
  })  : loot = loot ?? {},
        cues = cues ?? {},
        dreams = dreams ?? [],
        tools = tools ?? {'brush'},
        zoneVisits = zoneVisits ?? {},
        saCounts = saCounts ?? {},
        affinity = affinity ??
            {
              'food:sunberry': 0.2,
              'food:dewberry': 0.1,
              'food:mushroom': 0.1,
              'tool:ball': 0.1,
              'tool:brush': 0.2,
              'tool:whistle': 0.05,
              'friend:sprout': 0.1,
              'friend:aqua': 0.1,
            },
        spatialQ = spatialQ ?? {};

  final double social;
  final Map<String, int> loot;
  final Set<String> tools;
  final String equipped;
  final Map<String, int> zoneVisits;
  final Map<String, int> saCounts;
  final Map<String, double> affinity;
  final int friendMeets;
  final int foraged;
  final Map<String, List<double>> spatialQ;
  final int spatialSteps;
  final String goal;
  final String lastKey;
  final int lastAction;
  final String chain;
  final int chainStep;
  final String heldKey;
  final int heldAction;
  final double heldReward;
  final String heldIcon;
  final String whistleZone;
  final Map<String, int> cues;
  final List<DreamTrace> dreams;
  final String dreamNote;
  final int consolidated;
  final String buff;

  WorldLedger copy({
    double? social,
    Map<String, int>? loot,
    Set<String>? tools,
    String? equipped,
    Map<String, int>? zoneVisits,
    Map<String, int>? saCounts,
    Map<String, double>? affinity,
    int? friendMeets,
    int? foraged,
    Map<String, List<double>>? spatialQ,
    int? spatialSteps,
    String? goal,
    String? lastKey,
    int? lastAction,
    String? chain,
    int? chainStep,
    String? heldKey,
    int? heldAction,
    double? heldReward,
    String? heldIcon,
    String? whistleZone,
    Map<String, int>? cues,
    List<DreamTrace>? dreams,
    String? dreamNote,
    int? consolidated,
    String? buff,
  }) {
    return WorldLedger(
      social: social ?? this.social,
      loot: loot ?? this.loot,
      tools: tools ?? this.tools,
      equipped: equipped ?? this.equipped,
      zoneVisits: zoneVisits ?? this.zoneVisits,
      saCounts: saCounts ?? this.saCounts,
      affinity: affinity ?? this.affinity,
      friendMeets: friendMeets ?? this.friendMeets,
      foraged: foraged ?? this.foraged,
      spatialQ: spatialQ ?? this.spatialQ,
      spatialSteps: spatialSteps ?? this.spatialSteps,
      goal: goal ?? this.goal,
      lastKey: lastKey ?? this.lastKey,
      lastAction: lastAction ?? this.lastAction,
      chain: chain ?? this.chain,
      chainStep: chainStep ?? this.chainStep,
      heldKey: heldKey ?? this.heldKey,
      heldAction: heldAction ?? this.heldAction,
      heldReward: heldReward ?? this.heldReward,
      heldIcon: heldIcon ?? this.heldIcon,
      whistleZone: whistleZone ?? this.whistleZone,
      cues: cues ?? this.cues,
      dreams: dreams ?? this.dreams,
      dreamNote: dreamNote ?? this.dreamNote,
      consolidated: consolidated ?? this.consolidated,
      buff: buff ?? this.buff,
    );
  }

  Map<String, dynamic> toJson() => {
        'social': social,
        'loot': loot,
        'tools': tools.toList(),
        'equipped': equipped,
        'zoneVisits': zoneVisits,
        'saCounts': saCounts,
        'affinity': affinity,
        'friendMeets': friendMeets,
        'foraged': foraged,
        'spatialQ': spatialQ,
        'spatialSteps': spatialSteps,
        'goal': goal,
        'lastKey': lastKey,
        'lastAction': lastAction,
        'chain': chain,
        'chainStep': chainStep,
        'heldKey': heldKey,
        'heldAction': heldAction,
        'heldReward': heldReward,
        'heldIcon': heldIcon,
        'whistleZone': whistleZone,
        'cues': cues,
        'dreams': dreams.map((trace) => trace.toJson()).toList(),
        'dreamNote': dreamNote,
        'consolidated': consolidated,
        'buff': buff,
      };

  factory WorldLedger.fromJson(Object? raw) {
    if (raw is! Map) return WorldLedger();
    Map<String, int> ints(Object? value) {
      if (value is! Map) return {};
      return value.map((k, v) => MapEntry('$k', (v as num).toInt()));
    }

    Map<String, double> dbls(Object? value) {
      if (value is! Map) return {};
      return value.map((k, v) => MapEntry('$k', (v as num).toDouble()));
    }

    final qRaw = raw['spatialQ'];
    final q = <String, List<double>>{};
    if (qRaw is Map) {
      for (final entry in qRaw.entries) {
        final list = entry.value;
        if (list is List) q['${entry.key}'] = list.map((e) => (e as num).toDouble()).toList();
      }
    }
    final toolsRaw = raw['tools'];
    return WorldLedger(
      social: (raw['social'] as num?)?.toDouble() ?? 24,
      loot: ints(raw['loot']),
      tools: toolsRaw is List ? toolsRaw.map((e) => '$e').toSet() : {'brush'},
      equipped: raw['equipped'] as String? ?? 'none',
      zoneVisits: ints(raw['zoneVisits']),
      saCounts: ints(raw['saCounts']),
      affinity: dbls(raw['affinity']),
      friendMeets: (raw['friendMeets'] as num?)?.toInt() ?? 0,
      foraged: (raw['foraged'] as num?)?.toInt() ?? 0,
      spatialQ: q,
      spatialSteps: (raw['spatialSteps'] as num?)?.toInt() ?? 0,
      goal: raw['goal'] as String? ?? 'Explore_New_Tile',
      lastKey: raw['lastKey'] as String? ?? '',
      lastAction: (raw['lastAction'] as num?)?.toInt() ?? 0,
      chain: raw['chain'] as String? ?? '',
      chainStep: (raw['chainStep'] as num?)?.toInt() ?? 0,
      heldKey: raw['heldKey'] as String? ?? '',
      heldAction: (raw['heldAction'] as num?)?.toInt() ?? 0,
      heldReward: (raw['heldReward'] as num?)?.toDouble() ?? 0,
      heldIcon: raw['heldIcon'] as String? ?? '',
      whistleZone: raw['whistleZone'] as String? ?? '',
      cues: ints(raw['cues']),
      dreams: raw['dreams'] is List
          ? (raw['dreams'] as List).whereType<Map>().map((e) => DreamTrace.fromJson(Map<String, dynamic>.from(e))).toList()
          : <DreamTrace>[],
      dreamNote: raw['dreamNote'] as String? ?? '',
      consolidated: (raw['consolidated'] as num?)?.toInt() ?? 0,
      buff: raw['buff'] as String? ?? '',
    );
  }
}

class GlenRegion {
  const GlenRegion({
    required this.id,
    required this.name,
    required this.blurb,
    required this.berries,
    required this.residents,
    required this.gate,
  });

  final String id;
  final String name;
  final String blurb;
  final String berries;
  final String residents;
  final OffsetName gate;
}

class OffsetName {
  const OffsetName(this.x, this.y);
  final double x;
  final double y;
}

const glenRegions = [
  GlenRegion(
    id: 'glen',
    name: 'Starter Homestead & Glen',
    blurb: 'The house, the shed, and the first path.',
    berries: 'Sunberry',
    residents: 'Your kin',
    gate: OffsetName(700, 1500),
  ),
  GlenRegion(
    id: 'woods',
    name: 'Whispering Berry Woods',
    blurb: 'Orchard rows and the botanist.',
    berries: 'Dewberry',
    residents: 'Sprout',
    gate: OffsetName(700, 520),
  ),
  GlenRegion(
    id: 'brook',
    name: 'Crystal Brook & Dock',
    blurb: 'The stream, the plank bridge, and Aqua.',
    berries: 'Dewberry',
    residents: 'Aqua',
    gate: OffsetName(2100, 1400),
  ),
  GlenRegion(
    id: 'meadow',
    name: 'Sunlit Training Meadow',
    blurb: 'Open grass for the ball and the whistle.',
    berries: 'Honey mushroom',
    residents: 'The trainer',
    gate: OffsetName(1400, 2400),
  ),
  GlenRegion(
    id: 'ruins',
    name: 'Starlight Ancient Ruins',
    blurb: 'Night stones. The lantern helps.',
    berries: 'Mystic seed',
    residents: 'None. The stones keep watch.',
    gate: OffsetName(2300, 420),
  ),
];

bool regionUnlocked(String id, {required int level, required WorldLedger ledger}) {
  return switch (id) {
    'glen' => true,
    'woods' => level >= 2 && ledger.foraged >= 5,
    'brook' => level >= 3 && ledger.friendMeets >= 2,
    'meadow' => level >= 4,
    'ruins' => level >= 5,
    _ => false,
  };
}

String regionLockText(String id) {
  return switch (id) {
    'woods' => 'Needs level 2 and 5 foraged items.',
    'brook' => 'Needs level 3 and two meetings with animal friends.',
    'meadow' => 'Needs level 4.',
    'ruins' => 'Needs level 5.',
    _ => 'Open.',
  };
}
