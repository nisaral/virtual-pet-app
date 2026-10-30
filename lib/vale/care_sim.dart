import '../ml/spatial_mind.dart';
import 'models.dart';
import 'learning.dart';

class CareOutcome {
  const CareOutcome({
    required this.kin,
    required this.memory,
    required this.reaction,
    required this.bag,
    required this.gleamGain,
    required this.rejected,
    this.overfed = false,
  });

  final Kin kin;
  final String memory;
  final String reaction;
  final Map<String, int> bag;
  final int gleamGain;
  final bool rejected;
  final bool overfed;
}

class ValeSave {
  ValeSave({
    required this.keeperName,
    required this.createdAt,
    required this.lastSeen,
    required this.kin,
    required this.memories,
    required this.bag,
    required this.gleam,
    required this.qTable,
    required this.routine,
    required this.ear,
    required this.sparQ,
    required this.mindSteps,
    required this.gamesPlayed,
    required this.seenIntro,
    WorldLedger? ledger,
  }) : ledger = ledger ?? WorldLedger();

  final String keeperName;
  final DateTime createdAt;
  final DateTime lastSeen;
  final Kin kin;
  final List<MemoryNote> memories;
  final Map<String, int> bag;
  final int gleam;
  final Map<String, List<double>> qTable;
  final RoutineModel routine;
  final SequenceEar ear;
  final Map<String, List<double>> sparQ;
  final int mindSteps;
  final Set<String> gamesPlayed;
  final bool seenIntro;
  final WorldLedger ledger;

  ValeSave copy({
    String? keeperName,
    DateTime? createdAt,
    DateTime? lastSeen,
    Kin? kin,
    List<MemoryNote>? memories,
    Map<String, int>? bag,
    int? gleam,
    Map<String, List<double>>? qTable,
    RoutineModel? routine,
    SequenceEar? ear,
    Map<String, List<double>>? sparQ,
    int? mindSteps,
    Set<String>? gamesPlayed,
    bool? seenIntro,
    WorldLedger? ledger,
  }) {
    return ValeSave(
      keeperName: keeperName ?? this.keeperName,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      kin: kin ?? this.kin,
      memories: memories ?? this.memories,
      bag: bag ?? this.bag,
      gleam: gleam ?? this.gleam,
      qTable: qTable ?? this.qTable,
      routine: routine ?? this.routine,
      ear: ear ?? this.ear,
      sparQ: sparQ ?? this.sparQ,
      mindSteps: mindSteps ?? this.mindSteps,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      seenIntro: seenIntro ?? this.seenIntro,
      ledger: ledger ?? this.ledger,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'keeperName': keeperName,
        'createdAt': createdAt.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'kin': kin.toJson(),
        'memories': memories.map((m) => m.toJson()).toList(),
        'bag': bag,
        'gleam': gleam,
        'qTable': qToJson(qTable),
        'routine': routine.toJson(),
        'ear': ear.toJson(),
        'sparQ': qToJson(sparQ),
        'mindSteps': mindSteps,
        'gamesPlayed': gamesPlayed.toList(),
        'seenIntro': seenIntro,
        'ledger': ledger.toJson(),
      };

  factory ValeSave.fromJson(Map<String, dynamic> json) {
    final notesRaw = json['memories'];
    final notes = <MemoryNote>[];
    if (notesRaw is List) {
      for (final entry in notesRaw) {
        if (entry is Map) {
          notes.add(MemoryNote.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    final gamesRaw = json['gamesPlayed'];
    return ValeSave(
      keeperName: json['keeperName'] as String? ?? 'Keeper',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
      kin: Kin.fromJson(Map<String, dynamic>.from(json['kin'] as Map)),
      memories: notes,
      bag: _bag(json['bag']),
      gleam: (json['gleam'] as num?)?.toInt() ?? 0,
      qTable: qFromJson(json['qTable']),
      routine: RoutineModel.fromJson(json['routine']),
      ear: SequenceEar.fromJson(json['ear']),
      sparQ: qFromJson(json['sparQ']),
      mindSteps: (json['mindSteps'] as num?)?.toInt() ?? 0,
      gamesPlayed: gamesRaw is List ? gamesRaw.map((e) => '$e').toSet() : <String>{},
      seenIntro: json['seenIntro'] as bool? ?? false,
      ledger: WorldLedger.fromJson(json['ledger']),
    );
  }

  static ValeSave fresh({
    required String keeper,
    required String kinName,
    required SpeciesId species,
  }) {
    final now = DateTime.now();
    return ValeSave(
      keeperName: keeper,
      createdAt: now,
      lastSeen: now,
      kin: Kin.fresh(name: kinName, species: species),
      memories: [
        MemoryNote(at: now, text: '$kinName stepped into the glen with $keeper.'),
      ],
      bag: starterBag(species),
      gleam: 0,
      qTable: {},
      routine: RoutineModel(),
      ear: SequenceEar(),
      sparQ: {},
      mindSteps: 0,
      gamesPlayed: {},
      seenIntro: false,
    );
  }
}

Map<String, int> _bag(Object? raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) => MapEntry('$key', (value as num).toInt()));
}

Map<String, int> starterBag(SpeciesId species) {
  final favorite = SpeciesCatalog.of(species).favoriteFood;
  return {
    'sunberry': favorite == 'sunberry' ? 3 : 1,
    'kelpbit': favorite == 'kelpbit' ? 3 : 1,
    'spicecrumb': favorite == 'spicecrumb' ? 3 : 1,
    'milkdrop': 2,
  };
}

bool readyToEvolve(Kin kin, Set<String> gamesPlayed) {
  if (kin.stage <= 0) return kin.careCount >= 4 && kin.bond >= 18;
  if (kin.stage == 1) {
    return kin.careCount >= 10 && kin.bond >= 40 && kin.level >= 3 && gamesPlayed.isNotEmpty;
  }
  return false;
}

class CareSim {
  static ValeSave applyOffline(ValeSave save, Duration elapsed) {
    final hours = elapsed.inMinutes / 60.0;
    if (hours < 0.35) return save.copy(lastSeen: DateTime.now());
    final capped = hours > 16 ? 16.0 : hours;
    var kin = _decay(save.kin, capped);
    var days = kin.daysTogether;
    if (hours >= 8) {
      days += hours >= 16 ? 2 : 1;
      kin = kin.copy(
        daysTogether: days,
        energy: kin.energy < 70 ? 70 : kin.energy,
        asleep: false,
      );
    }
    final lowest = _lowestNeed(kin);
    final note = MemoryNote(
      at: DateTime.now(),
      text: 'While you were away, ${kin.name} $lowest.',
    );
    return save.copy(
      kin: kin.copy(clearBid: true, clearBidAt: true),
      lastSeen: DateTime.now(),
      memories: _remember(save.memories, note),
    );
  }

  static ValeSave passHours(ValeSave save, int hours) {
    var kin = _decay(save.kin, hours.toDouble());
    var days = kin.daysTogether;
    String line;
    if (hours >= 8) {
      days += 1;
      kin = kin.copy(
        daysTogether: days,
        energy: 86,
        asleep: false,
        joy: clampStat(kin.joy + 4),
      );
      line = 'The glen slept. ${kin.name} dreamed and woke softer.';
    } else {
      kin = kin.copy(asleep: false);
      line = 'A few quiet hours passed. ${kin.name} kept the glen.';
    }
    return save.copy(
      kin: kin.copy(clearBid: true, clearBidAt: true, lastCare: 'rest'),
      lastSeen: DateTime.now(),
      memories: _remember(save.memories, MemoryNote(at: DateTime.now(), text: line)),
    );
  }

  static CareOutcome feed(Kin kin, String foodId, Map<String, int> bag) {
    final have = bag[foodId] ?? 0;
    if (have <= 0) {
      return CareOutcome(
        kin: kin,
        memory: '',
        reaction: 'The pouch has no more of that.',
        bag: bag,
        gleamGain: 0,
        rejected: true,
      );
    }
    final nextBag = Map<String, int>.from(bag);
    nextBag[foodId] = have - 1;
    final before = kin.satiation;
    final love = Map<String, double>.from(kin.foodLove);
    final bias = love[foodId] ?? 0.3;
    final loved = bias >= 0.55;
    final overfed = before > 84;
    var satiation = kin.satiation + (loved ? 24 : 16);
    var joy = kin.joy + (loved ? 8 : 3);
    var bond = kin.bond + (loved ? 2.4 : 1.1);
    if (overfed) {
      joy -= 7;
      bond -= 0.4;
    }
    final bump = (before < 55 ? 0.1 : 0.02) + (loved ? 0.04 : 0) + (overfed ? -0.12 : 0);
    love[foodId] = (bias + bump).clamp(0.05, 1.35);
    final food = SpeciesCatalog.food(foodId);
    final kinNext = _cared(
      kin,
      satiation: satiation,
      joy: joy,
      bond: bond,
      xp: 10,
      foodLove: love,
      lastCare: 'feed',
    );
    final reaction = overfed
        ? '${kin.name} noses the ${food.name.toLowerCase()} away. The bowl was already enough.'
        : loved
            ? '${kin.name} lights up for ${food.name.toLowerCase()}.'
            : '${kin.name} eats the ${food.name.toLowerCase()} politely.';
    return CareOutcome(
      kin: kinNext,
      memory: reaction,
      reaction: reaction,
      bag: nextBag,
      gleamGain: 0,
      rejected: false,
      overfed: overfed,
    );
  }

  static CareOutcome groom(Kin kin, double quality) {
    final q = quality.clamp(0.0, 1.0);
    final kinNext = _cared(
      kin,
      coat: kin.coat + 12 + 18 * q,
      joy: kin.joy + 4 + 8 * q,
      bond: kin.bond + 1.3 + 2.2 * q,
      xp: 8 + (q * 8).round(),
      lastCare: 'groom',
    );
    final reaction = q > 0.72
        ? '${kin.name} goes loose under the brush. That was the right rhythm.'
        : '${kin.name} accepts the brushing, eyes half shut.';
    return CareOutcome(
      kin: kinNext,
      memory: reaction,
      reaction: reaction,
      bag: const {},
      gleamGain: 0,
      rejected: false,
    );
  }

  static CareOutcome rest(Kin kin) {
    final tired = kin.energy < 50;
    final kinNext = _cared(
      kin,
      energy: kin.energy + (tired ? 30 : 14),
      joy: kin.joy + (tired ? 6 : 1),
      bond: kin.bond + (tired ? 1.4 : 0.4),
      xp: 6,
      lastCare: 'rest',
    ).copy(asleep: true);
    final reaction = tired
        ? '${kin.name} folds down and is asleep between breaths.'
        : '${kin.name} rests because you asked, not because sleep was due.';
    return CareOutcome(
      kin: kinNext,
      memory: reaction,
      reaction: reaction,
      bag: const {},
      gleamGain: 0,
      rejected: false,
    );
  }

  static CareOutcome praise(Kin kin) {
    final kinNext = _cared(
      kin,
      joy: kin.joy + 5,
      bond: kin.bond + 1.6,
      xp: 4,
      lastCare: 'praise',
    );
    final reaction = '${kin.name} does the trick again, smaller, just for you.';
    return CareOutcome(
      kin: kinNext,
      memory: reaction,
      reaction: reaction,
      bag: const {},
      gleamGain: 1,
      rejected: false,
    );
  }

  static CareOutcome nuzzle(Kin kin) {
    final kinNext = kin.copy(
      joy: clampStat(kin.joy + 2.2),
      bond: clampStat(kin.bond + 0.8),
    );
    return CareOutcome(
      kin: kinNext,
      memory: '',
      reaction: '${kin.name} presses in, then looks up.',
      bag: const {},
      gleamGain: 0,
      rejected: false,
    );
  }

  static CareOutcome play(Kin kin, String gameId, double score) {
    final s = score.clamp(0.0, 1.0);
    final love = Map<String, double>.from(kin.gameLove);
    final prev = love[gameId] ?? 0.3;
    love[gameId] = (prev * 0.82 + s * 0.35).clamp(0.05, 1.4);
    var skill = kin.patternSkill;
    if (gameId == 'pattern') skill = (skill + s * 6).clamp(0, 40);
    final kinNext = _cared(
      kin,
      joy: kin.joy + 6 + 14 * s,
      energy: kin.energy - (8 + 6 * s),
      bond: kin.bond + 1.4 + 3.2 * s,
      xp: 12 + (s * 16).round(),
      gameLove: love,
      patternSkill: skill,
      lastCare: 'play',
    );
    final name = switch (gameId) {
      'pattern' => 'the glyph duet',
      'spar' => 'the spar',
      _ => 'ribbon fall',
    };
    final reaction = s > 0.66
        ? '${kin.name} is still buzzing from $name.'
        : '${kin.name} finishes $name, a little winded and glad.';
    return CareOutcome(
      kin: kinNext,
      memory: reaction,
      reaction: reaction,
      bag: const {},
      gleamGain: 4 + (s * 8).round(),
      rejected: false,
    );
  }

  static CareOutcome outing(Kin kin, Map<String, int> found, int gleam, String line) {
    final kinNext = _cared(
      kin,
      joy: kin.joy + 6,
      energy: kin.energy - 10,
      bond: kin.bond + 1.5,
      xp: 14,
      lastCare: 'outing',
    );
    return CareOutcome(
      kin: kinNext,
      memory: line,
      reaction: line,
      bag: found,
      gleamGain: gleam,
      rejected: false,
    );
  }

  static Kin evolve(Kin kin) {
    if (kin.stage >= 2) return kin;
    return kin.copy(
      stage: kin.stage + 1,
      bond: clampStat(kin.bond + 6),
      joy: clampStat(kin.joy + 10),
      xp: kin.xp + 20,
    );
  }

  static Kin _decay(Kin kin, double hours) {
    return kin.copy(
      satiation: softFloor(kin.satiation - 4.4 * hours),
      energy: softFloor(kin.energy - 2.6 * hours),
      coat: softFloor(kin.coat - 1.7 * hours),
      joy: softFloor(kin.joy - 1.4 * hours),
    );
  }

  static Kin _cared(
    Kin kin, {
    double? satiation,
    double? energy,
    double? coat,
    double? joy,
    double? bond,
    int xp = 0,
    Map<String, double>? foodLove,
    Map<String, double>? gameLove,
    double? patternSkill,
    String? lastCare,
  }) {
    return kin.copy(
      satiation: clampStat(satiation ?? kin.satiation),
      energy: softFloor(energy ?? kin.energy),
      coat: clampStat(coat ?? kin.coat),
      joy: clampStat(joy ?? kin.joy),
      bond: clampStat(bond ?? kin.bond),
      xp: kin.xp + xp,
      careCount: kin.careCount + 1,
      foodLove: foodLove,
      gameLove: gameLove,
      patternSkill: patternSkill,
      lastCare: lastCare,
      asleep: false,
      clearBid: true,
      clearBidAt: true,
    );
  }

  static String _lowestNeed(Kin kin) {
    final needs = {
      'waited by an empty bowl': 100 - kin.satiation,
      'napped more than usual': 100 - kin.energy,
      'got a little dusty': 100 - kin.coat,
      'kept looking at the path': 100 - kin.joy,
    };
    var best = 'kept the glen';
    var score = 20.0;
    needs.forEach((line, value) {
      if (value > score) {
        score = value;
        best = line;
      }
    });
    return best;
  }

  static List<MemoryNote> remember(List<MemoryNote> existing, String text) {
    if (text.isEmpty) return existing;
    return _remember(existing, MemoryNote(at: DateTime.now(), text: text));
  }

  static List<MemoryNote> _remember(List<MemoryNote> existing, MemoryNote note) {
    final next = [note, ...existing];
    if (next.length > 36) return next.sublist(0, 36);
    return next;
  }
}
