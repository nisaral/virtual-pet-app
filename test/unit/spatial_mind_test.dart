import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/ml/spatial_mind.dart';
import 'package:virtual_pet_app/vale/models.dart';

void main() {
  test('curiosity is higher for a fresh state-action than a worn one', () {
    expect(SpatialMind.intrinsic(0), greaterThan(SpatialMind.intrinsic(20)));
    expect(SpatialMind.goals, contains('GoTo_FoodBowl'));
    expect(SpatialMind.goals, contains('Explore_New_Tile'));
  });

  test('a hungry context prefers the bowl once that goal is rewarded', () {
    const key = 'day|0|2|1|glen|none|none';
    var table = <String, List<double>>{};
    for (var i = 0; i < 12; i++) {
      table = SpatialMind.learn(
        table: table,
        stateKey: key,
        action: SpatialMind.indexOf('GoTo_FoodBowl'),
        reward: 1.2,
        nextKey: key,
        visits: i,
      );
    }
    final row = table[key]!;
    final bowl = SpatialMind.indexOf('GoTo_FoodBowl');
    for (var i = 0; i < row.length; i++) {
      if (i == bowl) continue;
      expect(row[bowl], greaterThan(row[i]));
    }
  });

  test('woods stay shut until level and forage both land', () {
    final fresh = WorldLedger();
    expect(regionUnlocked('glen', level: 1, ledger: fresh), isTrue);
    expect(regionUnlocked('woods', level: 2, ledger: fresh), isFalse);
    expect(regionUnlocked('woods', level: 2, ledger: fresh.copy(foraged: 5)), isTrue);
    expect(regionUnlocked('ruins', level: 4, ledger: fresh), isFalse);
  });

  test('a two-step chain credits the earlier berry step', () {
    final table = SpatialMind.creditPair(
      table: const {},
      firstKey: 'bush',
      firstAction: SpatialMind.indexOf('Forage_BerryBush'),
      firstReward: 0.2,
      secondKey: 'bowl',
      secondAction: SpatialMind.indexOf('GoTo_FoodBowl'),
      secondReward: 1.4,
      thirdKey: 'bowl',
    );
    final berry = table['bush']![SpatialMind.indexOf('Forage_BerryBush')];
    expect(berry, greaterThan(0.3));
  });

  test('dream replay keeps the sixteen richest traces', () {
    var buffer = <DreamTrace>[];
    for (var i = 0; i < 20; i++) {
      buffer = rememberDream(
        buffer,
        DreamTrace(stateKey: 's$i', action: 0, reward: i.toDouble(), nextKey: 'n$i', icon: 'Berry'),
      );
    }
    expect(buffer, hasLength(16));
    expect(buffer.first.reward, 19);
    final replayed = replayDreams(const {}, buffer);
    expect(replayed['s19'], isNotNull);
  });

  test('a whistle cue is remembered for its zone', () {
    final cue = SpatialMind.favoredCue({'woods|feed': 3, 'woods|brush': 1}, 'woods');
    expect(cue, 'feed');
    expect(SpatialMind.goalForCue('feed'), SpatialMind.indexOf('GoTo_FoodBowl'));
  });

  test('the spatial key keeps zone and tool', () {
    final key = SpatialMind.keyFor(
      phase: DayPhase.dusk,
      hunger: 20,
      energy: 80,
      social: 40,
      zone: 'shed',
      tool: 'ball',
      nearby: 'sprout',
    );
    expect(key, contains('shed'));
    expect(key, contains('ball'));
  });
}