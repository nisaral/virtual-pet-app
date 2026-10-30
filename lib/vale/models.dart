enum KinElement { bloom, tide, ember }

enum SpeciesId { pipkin, marrow, solbit }

enum DayPhase { dawn, day, dusk, night }

enum Mood { radiant, glad, calm, weary, sulking, asleep }

enum KinPose { idle, hop, eat, groom, sleep, cheer, sulk }

enum InteractMode { overview, feed, brush, play, rest, walk }

enum CameraPreset { overview, closeUp, playWide, walkFollow }

String kinGlb(SpeciesId id) {
  return switch (id) {
    SpeciesId.pipkin => 'assets/models/sproutkit.glb',
    SpeciesId.marrow => 'assets/models/aquapup.glb',
    SpeciesId.solbit => 'assets/models/embercub.glb',
  };
}

String clipForPose(KinPose pose) {
  return switch (pose) {
    KinPose.idle => 'Idle',
    KinPose.hop => 'Happy_Hop',
    KinPose.eat => 'Eat',
    KinPose.groom => 'Pet_Enjoy',
    KinPose.sleep => 'Sleep',
    KinPose.cheer => 'Happy_Hop',
    KinPose.sulk => 'Refuse',
  };
}

enum ValeScreen {
  title,
  naming,
  starter,
  den,
  summary,
  feed,
  groom,
  play,
  pattern,
  ribbons,
  spar,
  outing,
  mind,
  journal,
  evolve,
}

class MoveDef {
  const MoveDef({
    required this.id,
    required this.name,
    required this.line,
    required this.element,
    required this.kind,
    required this.power,
  });

  final String id;
  final String name;
  final String line;
  final KinElement element;
  final String kind;
  final int power;

  bool get isGuard => kind == 'guard';
  bool get isRally => kind == 'rally';
}

class FoodDef {
  const FoodDef({
    required this.id,
    required this.name,
    required this.taste,
    required this.blurb,
  });

  final String id;
  final String name;
  final KinElement? taste;
  final String blurb;
}

class SpeciesDef {
  const SpeciesDef({
    required this.id,
    required this.name,
    required this.element,
    required this.nature,
    required this.favoriteFood,
    required this.stageTitles,
    required this.blurb,
    required this.moves,
  });

  final SpeciesId id;
  final String name;
  final KinElement element;
  final String nature;
  final String favoriteFood;
  final List<String> stageTitles;
  final String blurb;
  final List<MoveDef> moves;

  String titleFor(int stage) => stageTitles[stage.clamp(0, stageTitles.length - 1)];
}

class SpeciesCatalog {
  static const foods = <FoodDef>[
    FoodDef(
      id: 'sunberry',
      name: 'Sunberry',
      taste: KinElement.bloom,
      blurb: 'Tart, warm, and a little leafy.',
    ),
    FoodDef(
      id: 'kelpbit',
      name: 'Kelp bit',
      taste: KinElement.tide,
      blurb: 'Soft and salty, like a tide pool.',
    ),
    FoodDef(
      id: 'spicecrumb',
      name: 'Spice crumb',
      taste: KinElement.ember,
      blurb: 'A small kick of hearth spice.',
    ),
    FoodDef(
      id: 'milkdrop',
      name: 'Milk drop',
      taste: null,
      blurb: 'Gentle. Almost everyone leans in.',
    ),
  ];

  static const all = <SpeciesDef>[
    SpeciesDef(
      id: SpeciesId.pipkin,
      name: 'Pipkin',
      element: KinElement.bloom,
      nature: 'hearthful',
      favoriteFood: 'sunberry',
      stageTitles: ['Sproutkit', 'Meadowkin', 'Groveheart'],
      blurb: 'A bloom kin. Quiet, leafy, and quick to learn the hour you come home.',
      moves: [
        MoveDef(
          id: 'leaf_puff',
          name: 'Leaf Puff',
          line: 'A soft burst of leaves.',
          element: KinElement.bloom,
          kind: 'strike',
          power: 8,
        ),
        MoveDef(
          id: 'root_guard',
          name: 'Root Guard',
          line: 'Roots knit into a little shield.',
          element: KinElement.bloom,
          kind: 'guard',
          power: 0,
        ),
        MoveDef(
          id: 'pollen_cheer',
          name: 'Pollen Cheer',
          line: 'Warm pollen, and a second wind.',
          element: KinElement.bloom,
          kind: 'rally',
          power: 5,
        ),
      ],
    ),
    SpeciesDef(
      id: SpeciesId.marrow,
      name: 'Marrow',
      element: KinElement.tide,
      nature: 'dawnbound',
      favoriteFood: 'kelpbit',
      stageTitles: ['Shellkit', 'Tidekin', 'Pearlwake'],
      blurb: 'A tide kin. Round, playful, and happiest when a game has a rhythm.',
      moves: [
        MoveDef(
          id: 'bubble_tap',
          name: 'Bubble Tap',
          line: 'A bubble pops right on the nose.',
          element: KinElement.tide,
          kind: 'strike',
          power: 8,
        ),
        MoveDef(
          id: 'shell_brace',
          name: 'Shell Brace',
          line: 'The shell turns outward.',
          element: KinElement.tide,
          kind: 'guard',
          power: 0,
        ),
        MoveDef(
          id: 'tide_song',
          name: 'Tide Song',
          line: 'A small wave, then a deep breath.',
          element: KinElement.tide,
          kind: 'rally',
          power: 5,
        ),
      ],
    ),
    SpeciesDef(
      id: SpeciesId.solbit,
      name: 'Solbit',
      element: KinElement.ember,
      nature: 'duskwit',
      favoriteFood: 'spicecrumb',
      stageTitles: ['Sparkkit', 'Flamekin', 'Solheart'],
      blurb: 'An ember kin. Bright, nosy, and fond of showing off one good trick.',
      moves: [
        MoveDef(
          id: 'spark_hop',
          name: 'Spark Hop',
          line: 'A hop that leaves a spark.',
          element: KinElement.ember,
          kind: 'strike',
          power: 8,
        ),
        MoveDef(
          id: 'warm_guard',
          name: 'Warm Guard',
          line: 'Heat shimmers into a guard.',
          element: KinElement.ember,
          kind: 'guard',
          power: 0,
        ),
        MoveDef(
          id: 'sun_burst',
          name: 'Sun Burst',
          line: 'A flare, and the chest lifts.',
          element: KinElement.ember,
          kind: 'rally',
          power: 6,
        ),
      ],
    ),
  ];

  static SpeciesDef of(SpeciesId id) => all.firstWhere((s) => s.id == id);

  static FoodDef food(String id) => foods.firstWhere((f) => f.id == id);

  static SpeciesId speciesFrom(String raw) {
    return SpeciesId.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => SpeciesId.pipkin,
    );
  }
}

DayPhase? debugPhaseOverride;

DayPhase phaseAt(DateTime time) {
  final forced = debugPhaseOverride;
  if (forced != null) return forced;
  final hour = time.hour;
  if (hour >= 5 && hour < 8) return DayPhase.dawn;
  if (hour >= 8 && hour < 17) return DayPhase.day;
  if (hour >= 17 && hour < 20) return DayPhase.dusk;
  return DayPhase.night;
}

String phaseLabel(DayPhase phase) {
  return switch (phase) {
    DayPhase.dawn => 'Dawn',
    DayPhase.day => 'Day',
    DayPhase.dusk => 'Dusk',
    DayPhase.night => 'Night',
  };
}

String elementLabel(KinElement element) {
  return switch (element) {
    KinElement.bloom => 'Bloom',
    KinElement.tide => 'Tide',
    KinElement.ember => 'Ember',
  };
}

String natureLabel(String nature) {
  return switch (nature) {
    'hearthful' => 'Hearthful',
    'dawnbound' => 'Dawnbound',
    'duskwit' => 'Duskwit',
    _ => 'Brightforage',
  };
}

String natureBlurb(String nature) {
  return switch (nature) {
    'hearthful' => 'Leans toward brushing, naps, and the same chair every day.',
    'dawnbound' => 'Wakes ready to play, especially in the early light.',
    'duskwit' => 'Saves tricks for dusk, and watches how you answer them.',
    _ => 'Likes the path, the bowl, and anything found outside.',
  };
}

double typeMod(KinElement attack, KinElement defense) {
  if (attack == KinElement.ember && defense == KinElement.bloom) return 1.45;
  if (attack == KinElement.bloom && defense == KinElement.tide) return 1.45;
  if (attack == KinElement.tide && defense == KinElement.ember) return 1.45;
  if (attack == KinElement.bloom && defense == KinElement.ember) return 0.7;
  if (attack == KinElement.tide && defense == KinElement.bloom) return 0.7;
  if (attack == KinElement.ember && defense == KinElement.tide) return 0.7;
  return 1;
}

int levelForXp(int xp) {
  var level = 1;
  var left = xp;
  var step = 40;
  while (left >= step && level < 40) {
    left -= step;
    level += 1;
    step = (step * 1.18).round();
  }
  return level;
}

int xpStepForLevel(int level) {
  var step = 40;
  for (var i = 1; i < level; i++) {
    step = (step * 1.18).round();
  }
  return step;
}

int xpIntoLevel(int xp) {
  var left = xp;
  var step = 40;
  var level = 1;
  while (left >= step && level < 40) {
    left -= step;
    level += 1;
    step = (step * 1.18).round();
  }
  return left;
}

String statWord(double value) {
  if (value < 25) return 'Low';
  if (value < 50) return 'Fair';
  if (value < 75) return 'Good';
  return 'Full';
}

class Kin {
  const Kin({
    required this.name,
    required this.species,
    required this.nature,
    required this.stage,
    required this.bond,
    required this.satiation,
    required this.energy,
    required this.coat,
    required this.joy,
    required this.xp,
    required this.careCount,
    required this.daysTogether,
    required this.born,
    required this.foodLove,
    required this.gameLove,
    required this.asleep,
    required this.lastCare,
    required this.pendingBid,
    required this.bidAt,
    required this.bidStateKey,
    required this.patternSkill,
  });

  final String name;
  final SpeciesId species;
  final String nature;
  final int stage;
  final double bond;
  final double satiation;
  final double energy;
  final double coat;
  final double joy;
  final int xp;
  final int careCount;
  final int daysTogether;
  final DateTime born;
  final Map<String, double> foodLove;
  final Map<String, double> gameLove;
  final bool asleep;
  final String lastCare;
  final String? pendingBid;
  final DateTime? bidAt;
  final String bidStateKey;
  final double patternSkill;

  int get level => levelForXp(xp);

  SpeciesDef get def => SpeciesCatalog.of(species);

  Mood moodAt(DateTime now) {
    if (asleep) return Mood.asleep;
    if (satiation < 28 || coat < 24) return Mood.sulking;
    if (energy < 24) return Mood.weary;
    final ease = (joy + satiation + energy + coat) / 4;
    if (ease > 76 && bond > 28) return Mood.radiant;
    if (ease > 55) return Mood.glad;
    return Mood.calm;
  }

  Kin copy({
    String? name,
    SpeciesId? species,
    String? nature,
    int? stage,
    double? bond,
    double? satiation,
    double? energy,
    double? coat,
    double? joy,
    int? xp,
    int? careCount,
    int? daysTogether,
    DateTime? born,
    Map<String, double>? foodLove,
    Map<String, double>? gameLove,
    bool? asleep,
    String? lastCare,
    String? pendingBid,
    bool clearBid = false,
    DateTime? bidAt,
    bool clearBidAt = false,
    String? bidStateKey,
    double? patternSkill,
  }) {
    return Kin(
      name: name ?? this.name,
      species: species ?? this.species,
      nature: nature ?? this.nature,
      stage: stage ?? this.stage,
      bond: bond ?? this.bond,
      satiation: satiation ?? this.satiation,
      energy: energy ?? this.energy,
      coat: coat ?? this.coat,
      joy: joy ?? this.joy,
      xp: xp ?? this.xp,
      careCount: careCount ?? this.careCount,
      daysTogether: daysTogether ?? this.daysTogether,
      born: born ?? this.born,
      foodLove: foodLove ?? this.foodLove,
      gameLove: gameLove ?? this.gameLove,
      asleep: asleep ?? this.asleep,
      lastCare: lastCare ?? this.lastCare,
      pendingBid: clearBid ? null : (pendingBid ?? this.pendingBid),
      bidAt: clearBidAt ? null : (bidAt ?? this.bidAt),
      bidStateKey: bidStateKey ?? this.bidStateKey,
      patternSkill: patternSkill ?? this.patternSkill,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'species': species.name,
        'nature': nature,
        'stage': stage,
        'bond': bond,
        'satiation': satiation,
        'energy': energy,
        'coat': coat,
        'joy': joy,
        'xp': xp,
        'careCount': careCount,
        'daysTogether': daysTogether,
        'born': born.toIso8601String(),
        'foodLove': foodLove,
        'gameLove': gameLove,
        'asleep': asleep,
        'lastCare': lastCare,
        'pendingBid': pendingBid,
        'bidAt': bidAt?.toIso8601String(),
        'bidStateKey': bidStateKey,
        'patternSkill': patternSkill,
      };

  factory Kin.fromJson(Map<String, dynamic> json) {
    return Kin(
      name: json['name'] as String? ?? 'Pipkin',
      species: SpeciesCatalog.speciesFrom(json['species'] as String? ?? 'pipkin'),
      nature: json['nature'] as String? ?? 'hearthful',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      bond: (json['bond'] as num?)?.toDouble() ?? 12,
      satiation: (json['satiation'] as num?)?.toDouble() ?? 70,
      energy: (json['energy'] as num?)?.toDouble() ?? 80,
      coat: (json['coat'] as num?)?.toDouble() ?? 76,
      joy: (json['joy'] as num?)?.toDouble() ?? 70,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      careCount: (json['careCount'] as num?)?.toInt() ?? 0,
      daysTogether: (json['daysTogether'] as num?)?.toInt() ?? 0,
      born: DateTime.tryParse(json['born'] as String? ?? '') ?? DateTime.now(),
      foodLove: _dblMap(json['foodLove']),
      gameLove: _dblMap(json['gameLove']),
      asleep: json['asleep'] as bool? ?? false,
      lastCare: json['lastCare'] as String? ?? 'none',
      pendingBid: json['pendingBid'] as String?,
      bidAt: DateTime.tryParse(json['bidAt'] as String? ?? ''),
      bidStateKey: json['bidStateKey'] as String? ?? '',
      patternSkill: (json['patternSkill'] as num?)?.toDouble() ?? 0,
    );
  }

  static Kin fresh({required String name, required SpeciesId species}) {
    final def = SpeciesCatalog.of(species);
    final love = <String, double>{};
    for (final food in SpeciesCatalog.foods) {
      if (food.id == def.favoriteFood) {
        love[food.id] = 0.82;
      } else if (food.taste == null) {
        love[food.id] = 0.58;
      } else {
        love[food.id] = 0.28;
      }
    }
    return Kin(
      name: name,
      species: species,
      nature: def.nature,
      stage: 0,
      bond: 14,
      satiation: 74,
      energy: 82,
      coat: 78,
      joy: 72,
      xp: 0,
      careCount: 0,
      daysTogether: 0,
      born: DateTime.now(),
      foodLove: love,
      gameLove: {'pattern': 0.34, 'ribbons': 0.34, 'spar': 0.34},
      asleep: false,
      lastCare: 'none',
      pendingBid: null,
      bidAt: null,
      bidStateKey: '',
      patternSkill: 0,
    );
  }
}

class MemoryNote {
  const MemoryNote({required this.at, required this.text});

  final DateTime at;
  final String text;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'text': text};

  factory MemoryNote.fromJson(Map<String, dynamic> json) {
    return MemoryNote(
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      text: json['text'] as String? ?? '',
    );
  }
}

Map<String, double> _dblMap(Object? raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) => MapEntry('$key', (value as num).toDouble()));
}

Map<String, int> _intMap(Object? raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) => MapEntry('$key', (value as num).toInt()));
}

String favoriteKey(Map<String, double> scores, String fallback) {
  var best = fallback;
  var top = -1.0;
  scores.forEach((key, value) {
    if (value > top) {
      top = value;
      best = key;
    }
  });
  return best;
}

double clampStat(double value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

double softFloor(double value) => clampStat(value < 8 ? 8 : value);

class PatternSession {
  const PatternSession({
    required this.sequence,
    required this.phase,
    required this.round,
    required this.echo,
    required this.input,
    required this.misses,
    required this.roundsCleared,
    required this.targetRounds,
    required this.token,
  });

  final List<int> sequence;
  final String phase;
  final int round;
  final bool echo;
  final List<int> input;
  final int misses;
  final int roundsCleared;
  final int targetRounds;
  final int token;

  PatternSession copy({
    List<int>? sequence,
    String? phase,
    int? round,
    bool? echo,
    List<int>? input,
    int? misses,
    int? roundsCleared,
    int? targetRounds,
    int? token,
  }) {
    return PatternSession(
      sequence: sequence ?? this.sequence,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      echo: echo ?? this.echo,
      input: input ?? this.input,
      misses: misses ?? this.misses,
      roundsCleared: roundsCleared ?? this.roundsCleared,
      targetRounds: targetRounds ?? this.targetRounds,
      token: token ?? this.token,
    );
  }
}

class SparSession {
  const SparSession({
    required this.rivalSpecies,
    required this.rivalName,
    required this.foeStamina,
    required this.selfStamina,
    required this.maxStamina,
    required this.log,
    required this.selfGuarding,
    required this.foeGuarding,
    required this.suggestedIndex,
    required this.lastFoeKind,
    required this.sparKey,
    required this.turn,
    required this.done,
    required this.won,
    required this.rewarded,
  });

  final SpeciesId rivalSpecies;
  final String rivalName;
  final int foeStamina;
  final int selfStamina;
  final int maxStamina;
  final String log;
  final bool selfGuarding;
  final bool foeGuarding;
  final int suggestedIndex;
  final String lastFoeKind;
  final String sparKey;
  final int turn;
  final bool done;
  final bool won;
  final bool rewarded;

  SparSession copy({
    int? foeStamina,
    int? selfStamina,
    String? log,
    bool? selfGuarding,
    bool? foeGuarding,
    int? suggestedIndex,
    String? lastFoeKind,
    String? sparKey,
    int? turn,
    bool? done,
    bool? won,
    bool? rewarded,
  }) {
    return SparSession(
      rivalSpecies: rivalSpecies,
      rivalName: rivalName,
      foeStamina: foeStamina ?? this.foeStamina,
      selfStamina: selfStamina ?? this.selfStamina,
      maxStamina: maxStamina,
      log: log ?? this.log,
      selfGuarding: selfGuarding ?? this.selfGuarding,
      foeGuarding: foeGuarding ?? this.foeGuarding,
      suggestedIndex: suggestedIndex ?? this.suggestedIndex,
      lastFoeKind: lastFoeKind ?? this.lastFoeKind,
      sparKey: sparKey ?? this.sparKey,
      turn: turn ?? this.turn,
      done: done ?? this.done,
      won: won ?? this.won,
      rewarded: rewarded ?? this.rewarded,
    );
  }
}
