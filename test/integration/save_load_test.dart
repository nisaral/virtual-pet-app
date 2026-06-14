import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/features/pet/data/datasources/local_pet_datasource.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';

void main() {
  group('LocalPetDataSource (JSON persistence roundtrip)', () {
    late LocalPetDataSource ds;

    setUp(() {
      ds = LocalPetDataSource();
    });

    test('save + load roundtrip preserves PetState and memories', () async {
      // Use a temp unique id to avoid collision in real Documents dir during test
      final original = PetState(
        id: 'integration-test-pet-${DateTime.now().millisecondsSinceEpoch}',
        petType: PetType.snake,
        name: 'TestSnek',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        lastInteraction: DateTime.now(),
        stats: const Stats(hunger: 30, happiness: 90, cleanliness: 50, energy: 40, affection: 80),
        ageDays: 12,
        level: 4,
        xp: 55,
        evolutionStage: 'adult',
        isSleeping: true,
        inventory: [
          {'itemId': 'mice', 'quantity': 2}
        ],
        unlockedCosmetics: ['tiny_hat'],
        customizations: {'color': 'midnight'},
        memories: [],
      );

      await ds.savePet(original);
      final loaded = await ds.loadPet();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'TestSnek');
      expect(loaded.petType, PetType.snake);
      expect(loaded.stats.hunger, 30);
      expect(loaded.inventory.first['itemId'], 'mice');
      expect(loaded.customizations['color'], 'midnight');
      expect(loaded.isSleeping, true);
    });

    tearDown(() async {
      // Best effort cleanup of test file (not critical)
      try {
        await ds.clear();
      } catch (_) {}
    });
  });
}
