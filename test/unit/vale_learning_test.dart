import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/vale/care_sim.dart';
import 'package:virtual_pet_app/vale/learning.dart';
import 'package:virtual_pet_app/vale/models.dart';

void main() {
  Kin sample({double satiation = 70, double energy = 80, double coat = 80, double joy = 70, double bond = 20}) {
    return Kin.fresh(name: 'Miso', species: SpeciesId.pipkin).copy(
      satiation: satiation,
      energy: energy,
      coat: coat,
      joy: joy,
      bond: bond,
    );
  }

  test('a hungry kin asks for a meal before it has learned anything', () {
    final kin = sample(satiation: 10);
    final key = BondMind.keyFor(kin, DateTime(2026, 6, 14, 12));
    final action = BondMind.greedy(
      table: const {},
      stateKey: key,
      kin: kin,
      steps: 0,
      anticipatedBid: null,
    );
    expect(BondMind.actions[action], 'meal');
  });

  test('Q-learning raises the score of the answer that keeps paying off', () {
    var table = <String, List<double>>{};
    const stateKey = 'day|0|2|2|2|1|none';
    for (var i = 0; i < 25; i++) {
      table = BondMind.learn(
        table: table,
        stateKey: stateKey,
        action: 0,
        reward: 1.2,
        nextKey: stateKey,
      );
    }
    final row = table[stateKey]!;
    expect(row[0], greaterThan(0.8));
    for (var i = 1; i < row.length; i++) {
      expect(row[0], greaterThan(row[i]));
    }
  });

  test('being ignored pulls that ask down', () {
    final table = BondMind.learn(
      table: const {},
      stateKey: 'night|1|1|1|1|1|none',
      action: 2,
      reward: responseReward(bid: 'brush', action: 'ignore', satiation: 50, energy: 50, coat: 30),
      nextKey: 'night|1|1|1|1|1|none',
    );
    expect(table['night|1|1|1|1|1|none']![2], lessThan(0));
  });

  test('matching a hungry meal ask is strongly rewarded', () {
    final reward = responseReward(bid: 'meal', action: 'feed', satiation: 20, energy: 60, coat: 60);
    final miss = responseReward(bid: 'meal', action: 'groom', satiation: 20, energy: 60, coat: 60);
    expect(reward, greaterThan(1));
    expect(miss, lessThan(0));
  });

  test('the routine model notices a repeated hour', () {
    var routine = RoutineModel();
    for (var i = 0; i < 5; i++) {
      routine = routine.observe('feed', 18);
    }
    expect(routine.anticipate(18), 'feed');
    expect(routine.anticipate(3), isNull);
  });

  test('a repeated hour can pull the ask even when stats are even', () {
    final kin = sample();
    final key = BondMind.keyFor(kin, DateTime.now());
    final action = BondMind.greedy(
      table: const {},
      stateKey: key,
      kin: kin,
      steps: 2,
      anticipatedBid: 'meal',
    );
    expect(BondMind.actions[action], 'meal');
  });

  test('pattern phrases echo a dominant transition', () {
    var ear = SequenceEar();
    for (var i = 0; i < 12; i++) {
      ear = ear.observe([0, 2]);
    }
    var openedOnTwo = 0;
    for (var seed = 0; seed < 80; seed++) {
      final sequence = ear.compose(6, math.Random(seed), echo: true);
      expect(sequence.first, 0);
      if (sequence[1] == 2) openedOnTwo++;
    }
    expect(openedOnTwo, greaterThan(48));
  });

  test('rearing opens the first rite after real care, and not before', () {
    final fresh = Kin.fresh(name: 'Miso', species: SpeciesId.solbit);
    expect(readyToEvolve(fresh, {}), isFalse);
    final ready = fresh.copy(careCount: 4, bond: 18);
    expect(readyToEvolve(ready, {}), isTrue);
    final grown = ready.copy(stage: 1, careCount: 10, bond: 40, xp: 120);
    expect(readyToEvolve(grown, {}), isFalse);
    expect(readyToEvolve(grown, {'pattern'}), isTrue);
  });

  test('offline hours make a kin needier without emptying them', () {
    final save = ValeSave.fresh(keeper: 'Nia', kinName: 'Miso', species: SpeciesId.marrow);
    final later = CareSim.applyOffline(save, const Duration(hours: 10));
    expect(later.kin.satiation, lessThan(save.kin.satiation));
    expect(later.kin.satiation, greaterThanOrEqualTo(8));
    expect(later.kin.daysTogether, 1);
    expect(later.memories.first.text, contains('While you were away'));
  });

  test('ember strikes land harder on bloom than on tide', () {
    expect(typeMod(KinElement.ember, KinElement.bloom), greaterThan(1));
    expect(typeMod(KinElement.ember, KinElement.tide), lessThan(1));
  });

  test('a favorite bite raises joy more than a shrug', () {
    final kin = Kin.fresh(name: 'Miso', species: SpeciesId.pipkin);
    final bag = {'sunberry': 1, 'kelpbit': 1};
    final loved = CareSim.feed(kin, 'sunberry', bag);
    final plain = CareSim.feed(kin, 'kelpbit', bag);
    expect(loved.kin.joy, greaterThan(plain.kin.joy));
    expect(loved.bag['sunberry'], 0);
  });
}
