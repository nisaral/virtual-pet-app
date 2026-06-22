import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/features/pet/application/pet_simulator.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type_config.dart';

void main() {
  group('PetSimulator', () {
    late PetState basePet;

    setUp(() {
      final now = DateTime(2026, 6, 14);
      basePet = PetState(
        id: 'test-pet',
        petType: PetType.whale,
        name: 'Testy',
        createdAt: now,
        lastUpdated: now,
        lastInteraction: now,
        stats: const Stats(hunger: 60, happiness: 70, cleanliness: 80, energy: 65, affection: 55),
        ageDays: 5,
        level: 2,
        xp: 10,
        evolutionStage: 'baby',
        growthStage: 0,
        growthProgress: 0.0,
        interactionCount: 10,
        currentEnvironment: 'pond',
        gifts: [],
        unlockedEnvironments: ['pond'],
        isSleeping: false,
        inventory: [],
        unlockedCosmetics: [],
        customizations: {},
        memories: [],
      );
    });

    test('applyAction(feed) reduces hunger and creates memory with decent importance', () {
      final result = PetSimulator.applyAction(current: basePet, action: 'feed');

      expect(result.newState.stats.hunger, lessThan(basePet.stats.hunger));
      expect(result.newMemory, isNotNull);
      expect(result.newMemory!.eventType, 'feed');
      expect(result.newMemory!.importance, greaterThan(0.3));
      expect(result.newState.memories.length, 1);
    });

    test('applyAction respects preferred actions (bonus for whale on feed)', () {
      final result = PetSimulator.applyAction(current: basePet, action: 'feed');
      // Whale prefers feed → bigger improvement than non-preferred
      expect(result.newState.stats.hunger, lessThan(50)); // quite a drop
    });

    test('computeMood returns sensible values', () {
      expect(PetSimulator.computeMood(const Stats(hunger: 10, happiness: 90, cleanliness: 90, energy: 90, affection: 90)), 'ecstatic');
      expect(PetSimulator.computeMood(const Stats(hunger: 95, happiness: 30, cleanliness: 20, energy: 20, affection: 30)), 'starving');
    });

    test('createAwayMemory produces a valid memory when text provided', () {
      final mem = PetSimulator.createAwayMemory('I got very hungry while you were away...', basePet.stats);
      expect(mem, isNotNull);
      expect(mem!.eventType, 'away');
      expect(mem.text, contains('hungry'));
    });
  });
}
