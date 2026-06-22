import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/features/pet/application/memory_rag_service.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/core/utils/vector_utils.dart';

MemoryEntry _makeMem(String text, double importance, DateTime ts) => MemoryEntry(
      id: text.hashCode.toString(),
      timestamp: ts,
      eventType: 'test',
      text: text,
      metadataJson: '{}',
      importance: importance,
      embedding: VectorUtils.fakeEmbed(text),
    );

void main() {
  group('MemoryRAGService', () {
    test('retrieveRelevant returns most relevant + recent memories for query', () {
      final now = DateTime.now();
      final memories = [
        _makeMem('I was fed fresh kelp and felt full.', 0.9, now.subtract(const Duration(hours: 2))),
        _makeMem('We played with a shiny ball for a long time.', 0.7, now.subtract(const Duration(days: 1))),
        _makeMem('My human cleaned my tank and I felt refreshed.', 0.6, now.subtract(const Duration(hours: 30))),
        _makeMem('I took a long nap while you were away.', 0.5, now.subtract(const Duration(days: 3))),
      ];

      final results = MemoryRAGService.retrieveRelevant(
        allMemories: memories,
        query: 'remember when I was fed',
        topK: 2,
      );

      expect(results.length, 2);
      // The "fed kelp" memory should rank very high due to embedding similarity + high importance
      expect(results.first.text, contains('fed fresh kelp'));
    });

    test('buildContextBlock produces readable prompt fragment', () {
      final pet = PetState(
        id: 'p1',
        petType: PetType.cow,
        name: 'Daisy',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        lastInteraction: DateTime.now(),
        stats: const Stats(hunger: 40, happiness: 80, cleanliness: 70, energy: 60, affection: 75),
        ageDays: 10,
        level: 3,
        xp: 40,
        evolutionStage: 'juvenile',
        growthStage: 1,
        growthProgress: 0.5,
        interactionCount: 100,
        currentEnvironment: 'pasture',
        gifts: [],
        unlockedEnvironments: ['pasture'],
        isSleeping: false,
        inventory: [],
        unlockedCosmetics: [],
        customizations: {},
        memories: [],
      );

      final mems = [
        _makeMem('We played together yesterday.', 0.8, DateTime.now().subtract(const Duration(days: 1))),
      ];

      final block = MemoryRAGService.buildContextBlock(mems, pet);
      expect(block, contains('Daisy'));
      expect(block, contains('played together'));
      expect(block, contains('importance'));
    });

    test('empty memories returns empty or fallback gracefully', () {
      final results = MemoryRAGService.retrieveRelevant(allMemories: [], query: 'anything');
      expect(results, isEmpty);
    });
  });
}
