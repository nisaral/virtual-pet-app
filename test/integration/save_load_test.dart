import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:virtual_pet_app/features/pet/data/datasources/local_pet_datasource.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';

class _DocsPath extends PathProviderPlatform {
  _DocsPath(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalPetDataSource (JSON persistence roundtrip)', () {
    late LocalPetDataSource ds;
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('lumina-pet-test');
      PathProviderPlatform.instance = _DocsPath(temp.path);
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
        growthStage: 2,
        growthProgress: 1.0,
        interactionCount: 200,
        currentEnvironment: 'cave',
        gifts: [],
        unlockedEnvironments: ['cave'],
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
      try {
        await ds.clear();
      } catch (_) {}
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });
  });
}
