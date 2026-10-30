import 'dart:math' as math;

import 'models.dart';

/// On-device learning for one kin.
///
/// [BondMind] is tabular Q-learning over the situation the kin is in and the
/// six things it can ask for. Alpha stays modest so one ignored hour does not
/// wipe a week of care. [RoutineModel] is a 24-hour histogram of what you
/// actually do. [SequenceEar] is a first-order model of the glyph duet.
class BondMind {
  static const actions = ['meal', 'play', 'brush', 'nap', 'trick', 'wander'];
  static const alpha = 0.34;
  static const gamma = 0.82;

  static int indexOf(String action) {
    final index = actions.indexOf(action);
    return index < 0 ? 0 : index;
  }

  static int bin(double value) {
    if (value < 34) return 0;
    if (value < 67) return 1;
    return 2;
  }

  static String keyFor(Kin kin, DateTime now) {
    final phase = phaseAt(now);
    return '${phase.name}|${bin(kin.satiation)}|${bin(kin.energy)}|${bin(kin.joy)}|${bin(kin.coat)}|${bin(kin.bond)}|${kin.lastCare}';
  }

  static List<double> instinct(Kin kin, DayPhase phase, String nature) {
    final trickBias = nature == 'duskwit' && (phase == DayPhase.dusk || phase == DayPhase.night) ? 0.5 : 0.06;
    final wanderBias = nature == 'brightforage' ? 0.28 : 0.12;
    final playBias = nature == 'dawnbound' && phase == DayPhase.dawn ? 0.35 : 0.0;
    final brushBias = nature == 'hearthful' ? 0.22 : 0.0;
    return [
      (100 - kin.satiation) / 55,
      (kin.energy > 26 ? (100 - kin.joy) / 90 : 0.05) + playBias,
      (100 - kin.coat) / 60 + brushBias,
      (100 - kin.energy) / 50,
      kin.bond / 140 + trickBias,
      wanderBias,
    ];
  }

  static Map<String, List<double>> learn({
    required Map<String, List<double>> table,
    required String stateKey,
    required int action,
    required double reward,
    required String nextKey,
  }) {
    final next = Map<String, List<double>>.from(table);
    final row = List<double>.from(next[stateKey] ?? List<double>.filled(actions.length, 0));
    final future = next[nextKey] ?? List<double>.filled(actions.length, 0);
    var maxNext = future.first;
    for (final value in future) {
      if (value > maxNext) maxNext = value;
    }
    final updated = row[action] + alpha * (reward + gamma * maxNext - row[action]);
    row[action] = updated.clamp(-2.0, 3.0);
    next[stateKey] = row;
    return next;
  }

  static int greedy({
    required Map<String, List<double>> table,
    required String stateKey,
    required Kin kin,
    required int steps,
    required String? anticipatedBid,
  }) {
    final scores = _scores(
      table: table,
      stateKey: stateKey,
      kin: kin,
      steps: steps,
      anticipatedBid: anticipatedBid,
    );
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  static int choose({
    required Map<String, List<double>> table,
    required String stateKey,
    required Kin kin,
    required int steps,
    required String? anticipatedBid,
    required math.Random rng,
  }) {
    final epsilon = curiosity(steps);
    if (rng.nextDouble() < epsilon) return rng.nextInt(actions.length);
    return greedy(
      table: table,
      stateKey: stateKey,
      kin: kin,
      steps: steps,
      anticipatedBid: anticipatedBid,
    );
  }

  static double curiosity(int steps) {
    final value = 0.4 * math.pow(0.97, steps).toDouble();
    if (value < 0.07) return 0.07;
    if (value > 0.4) return 0.4;
    return value;
  }

  static List<double> learnedRow(Map<String, List<double>> table, String stateKey) {
    return List<double>.from(table[stateKey] ?? List<double>.filled(actions.length, 0));
  }

  static List<double> _scores({
    required Map<String, List<double>> table,
    required String stateKey,
    required Kin kin,
    required int steps,
    required String? anticipatedBid,
  }) {
    final learned = learnedRow(table, stateKey);
    final gut = instinct(kin, phaseAt(DateTime.now()), kin.nature);
    final fade = steps < 6 ? 0.9 : (steps < 18 ? 0.45 : 0.22);
    return List<double>.generate(actions.length, (index) {
      var score = learned[index] + gut[index] * fade;
      if (anticipatedBid != null && actions[index] == anticipatedBid) score += 0.72;
      return score;
    });
  }
}

double responseReward({
  required String bid,
  required String action,
  required double satiation,
  required double energy,
  required double coat,
}) {
  if (action == 'ignore') return -0.38;
  if (bid == 'meal' && action == 'feed') {
    if (satiation < 40) return 1.45;
    if (satiation < 75) return 0.62;
    return -0.22;
  }
  if (bid == 'play' && action == 'play') return energy > 22 ? 1.22 : 0.3;
  if (bid == 'brush' && action == 'groom') return coat < 55 ? 1.28 : 0.74;
  if (bid == 'nap' && action == 'rest') return energy < 48 ? 1.36 : 0.12;
  if (bid == 'trick' && action == 'praise') return 1.05;
  if (bid == 'wander' && action == 'outing') return 1.16;
  if (action == 'feed' && satiation > 86) return -0.45;
  return -0.28;
}

const careToBid = {
  'feed': 'meal',
  'play': 'play',
  'groom': 'brush',
  'rest': 'nap',
};

class RoutineModel {
  RoutineModel()
      : counts = List.generate(4, (_) => List<double>.filled(24, 0));

  RoutineModel.fromCounts(this.counts);

  static const labels = ['feed', 'play', 'groom', 'rest'];

  final List<List<double>> counts;

  int get total {
    var sum = 0.0;
    for (final row in counts) {
      for (final value in row) {
        sum += value;
      }
    }
    return sum.round();
  }

  RoutineModel observe(String action, int hour) {
    final index = labels.indexOf(action);
    if (index < 0) return this;
    final next = counts.map((row) => List<double>.from(row)).toList();
    final h = hour.clamp(0, 23);
    next[index][h] += 1;
    return RoutineModel.fromCounts(next);
  }

  String? anticipate(int hour) {
    if (total < 4) return null;
    final h = hour.clamp(0, 23);
    var best = 0;
    var bestCount = counts[0][h];
    var hourSum = 0.0;
    for (var i = 0; i < counts.length; i++) {
      hourSum += counts[i][h];
      if (counts[i][h] > bestCount) {
        best = i;
        bestCount = counts[i][h];
      }
    }
    if (bestCount < 2) return null;
    final smoothed = (bestCount + 0.4) / (hourSum + 1.6);
    if (smoothed < 0.4) return null;
    return labels[best];
  }

  String? phaseLean(DayPhase phase) {
    final hours = switch (phase) {
      DayPhase.dawn => [5, 6, 7],
      DayPhase.day => [9, 12, 15],
      DayPhase.dusk => [17, 18, 19],
      DayPhase.night => [21, 22, 23],
    };
    if (total < 3) return null;
    var best = 0;
    var bestSum = -1.0;
    for (var action = 0; action < labels.length; action++) {
      var sum = 0.0;
      for (final hour in hours) {
        sum += counts[action][hour];
      }
      if (sum > bestSum) {
        bestSum = sum;
        best = action;
      }
    }
    if (bestSum <= 0) return null;
    return labels[best];
  }

  Map<String, dynamic> toJson() => {
        for (var i = 0; i < labels.length; i++) labels[i]: counts[i],
      };

  factory RoutineModel.fromJson(Object? raw) {
    final model = RoutineModel();
    if (raw is! Map) return model;
    for (var i = 0; i < labels.length; i++) {
      final row = raw[labels[i]];
      if (row is List) {
        for (var h = 0; h < 24 && h < row.length; h++) {
          model.counts[i][h] = (row[h] as num).toDouble();
        }
      }
    }
    return model;
  }
}

class SequenceEar {
  SequenceEar()
      : starts = List<double>.filled(4, 0),
        transitions = List.generate(4, (_) => List<double>.filled(4, 0));

  SequenceEar.fromParts(this.starts, this.transitions);

  final List<double> starts;
  final List<List<double>> transitions;

  double get mass => starts.fold<double>(0, (sum, value) => sum + value);

  SequenceEar observe(List<int> sequence) {
    final nextStarts = List<double>.from(starts);
    final nextTransitions = transitions.map((row) => List<double>.from(row)).toList();
    if (sequence.isEmpty) return SequenceEar.fromParts(nextStarts, nextTransitions);
    final first = sequence.first.clamp(0, 3);
    nextStarts[first] += 1;
    for (var i = 0; i < sequence.length - 1; i++) {
      final from = sequence[i].clamp(0, 3);
      final to = sequence[i + 1].clamp(0, 3);
      nextTransitions[from][to] += 1;
    }
    return SequenceEar.fromParts(nextStarts, nextTransitions);
  }

  List<int> compose(int length, math.Random rng, {required bool echo}) {
    if (!echo || mass < 3) {
      return List<int>.generate(length, (_) => rng.nextInt(4));
    }
    final sequence = <int>[_sample(starts, rng)];
    for (var i = 1; i < length; i++) {
      final row = transitions[sequence.last];
      final rowMass = row.fold<double>(0, (sum, value) => sum + value);
      if (rowMass < 1 || rng.nextDouble() < 0.22) {
        sequence.add(rng.nextInt(4));
      } else {
        sequence.add(_sample(row, rng));
      }
    }
    return sequence;
  }

  int _sample(List<double> weights, math.Random rng) {
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return rng.nextInt(weights.length);
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return i;
    }
    return weights.length - 1;
  }

  Map<String, dynamic> toJson() => {
        'starts': starts,
        'transitions': transitions,
      };

  factory SequenceEar.fromJson(Object? raw) {
    final ear = SequenceEar();
    if (raw is! Map) return ear;
    final startsRaw = raw['starts'];
    if (startsRaw is List) {
      for (var i = 0; i < 4 && i < startsRaw.length; i++) {
        ear.starts[i] = (startsRaw[i] as num).toDouble();
      }
    }
    final trans = raw['transitions'];
    if (trans is List) {
      for (var r = 0; r < 4 && r < trans.length; r++) {
        final row = trans[r];
        if (row is List) {
          for (var c = 0; c < 4 && c < row.length; c++) {
            ear.transitions[r][c] = (row[c] as num).toDouble();
          }
        }
      }
    }
    return ear;
  }
}

class MoveMind {
  static const alpha = 0.3;
  static const gamma = 0.75;

  static String keyFor({
    required KinElement foe,
    required double staminaFraction,
    required String lastFoeKind,
  }) {
    final bin = staminaFraction < 0.34 ? 0 : (staminaFraction < 0.67 ? 1 : 2);
    return '${foe.name}|$bin|$lastFoeKind';
  }

  static Map<String, List<double>> learn({
    required Map<String, List<double>> table,
    required String stateKey,
    required int action,
    required double reward,
    required String nextKey,
  }) {
    final next = Map<String, List<double>>.from(table);
    final row = List<double>.from(next[stateKey] ?? List<double>.filled(3, 0));
    final future = next[nextKey] ?? List<double>.filled(3, 0);
    var maxNext = future.first;
    for (final value in future) {
      if (value > maxNext) maxNext = value;
    }
    row[action] = (row[action] + alpha * (reward + gamma * maxNext - row[action])).clamp(-2.0, 3.0);
    next[stateKey] = row;
    return next;
  }

  static int suggest(Map<String, List<double>> table, String stateKey) {
    final row = table[stateKey] ?? List<double>.filled(3, 0);
    var allZero = true;
    for (final value in row) {
      if (value.abs() > 0.001) allZero = false;
    }
    if (allZero) return 0;
    var best = 0;
    for (var i = 1; i < row.length; i++) {
      if (row[i] > row[best]) best = i;
    }
    return best;
  }
}

Map<String, List<double>> qFromJson(Object? raw) {
  if (raw is! Map) return {};
  final table = <String, List<double>>{};
  raw.forEach((key, value) {
    if (value is List) {
      table['$key'] = value.map((entry) => (entry as num).toDouble()).toList();
    }
  });
  return table;
}

Map<String, dynamic> qToJson(Map<String, List<double>> table) => table;
