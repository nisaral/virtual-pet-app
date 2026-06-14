import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type_config.dart';
import 'package:virtual_pet_app/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:virtual_pet_app/features/pet/data/datasources/local_pet_datasource.dart';
import 'package:virtual_pet_app/features/pet/application/pet_simulator.dart';
import 'package:virtual_pet_app/features/pet/application/memory_rag_service.dart';
import 'package:virtual_pet_app/core/utils/time_simulator.dart';
import 'package:virtual_pet_app/core/utils/vector_utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Riverpod AsyncNotifier that owns the live PetState, handles actions,
/// time simulation on load, and persistence.
/// This is the central "brain" of the app.
final petControllerProvider =
    AsyncNotifierProvider<PetController, PetState>(PetController.new);

class PetController extends AsyncNotifier<PetState> {
  late final PetRepositoryImpl _repo;

  @override
  Future<PetState> build() async {
    final ds = LocalPetDataSource();
    _repo = PetRepositoryImpl(ds);

    PetState? loaded = await _repo.getActivePet();

    if (loaded == null) {
      // First launch - create default pet (user can "adopt" others later)
      loaded = _createDefaultPet(PetType.whale, name: 'Bubbles');
      await _repo.savePet(loaded);
    } else {
      // Apply offline time progression (key requirement)
      final now = DateTime.now();
      final elapsed = now.difference(loaded.lastUpdated);
      final config = PetTypeConfig.forType(loaded.petType);

      final result = TimeSimulator.applyOfflineDecay(
        elapsed: elapsed,
        currentStats: loaded.stats,
        decayRates: config.decayRates,
      );

      if (elapsed.inMinutes > 5) {
        // Update state with decayed values
        var updated = loaded.copyWith(
          stats: result.newStats,
          lastUpdated: now,
        );

        // Add "away" memories
        for (final txt in result.awayMemories) {
          final mem = PetSimulator.createAwayMemory(txt, result.newStats);
          if (mem != null) {
            updated = updated.copyWith(memories: [...updated.memories, mem]);
            await _repo.addMemory(updated.id, mem);
          }
        }
        loaded = updated;
        await _repo.savePet(loaded);
      }
    }

    return loaded;
  }

  PetState _createDefaultPet(PetType type, {required String name}) {
    final now = DateTime.now();
    final config = PetTypeConfig.forType(type);
    return PetState(
      id: _uuid.v4(),
      petType: type,
      name: name,
      createdAt: now,
      lastUpdated: now,
      lastInteraction: now,
      stats: const Stats(
        hunger: 65,
        happiness: 72,
        cleanliness: 80,
        energy: 68,
        affection: 55,
      ),
      ageDays: 0,
      level: 1,
      xp: 0,
      evolutionStage: 'baby',
      growthStage: 0, // baby
      growthProgress: 0.0,
      interactionCount: 1, // the adoption counts as first interaction
      currentEnvironment: 'pond', // default for whale; swap on evolution choice
      gifts: [],
      unlockedEnvironments: ['pond'],
      isSleeping: false,
      inventory: [
        {'itemId': 'basic_food', 'quantity': 3},
      ],
      unlockedCosmetics: [],
      customizations: {},
      memories: [
        MemoryEntry(
          id: _uuid.v4(),
          timestamp: now.subtract(const Duration(minutes: 1)),
          eventType: 'adopted',
          text: 'My human adopted me today! I am excited and a little nervous.',
          metadataJson: '{"source":"creation"}',
          importance: 0.95,
          embedding: VectorUtils.fakeEmbed('adopted today'),
        ),
      ],
    );
  }

  /// Perform a care action. Updates state + persists + creates memory.
  Future<void> performAction(String action, {Map<String, dynamic>? extra}) async {
    final current = state.value;
    if (current == null) return;

    final result = PetSimulator.applyAction(
      current: current,
      action: action,
      extra: extra,
    );

    state = AsyncValue.data(result.newState);
    await _repo.savePet(result.newState);
    if (result.newMemory != null) {
      await _repo.addMemory(result.newState.id, result.newMemory!);
    }
  }

  /// Simple pet switch / adopt new (demo). In real app would have a selection flow.
  Future<void> switchPet(PetType newType, {String? customName}) async {
    final now = DateTime.now();
    final config = PetTypeConfig.forType(newType);
    final name = customName ?? 'New ${config.displayName}';

    final fresh = PetState(
      id: _uuid.v4(),
      petType: newType,
      name: name,
      createdAt: now,
      lastUpdated: now,
      lastInteraction: now,
      stats: const Stats(hunger: 60, happiness: 75, cleanliness: 85, energy: 70, affection: 50),
      ageDays: 0,
      level: 1,
      xp: 0,
      evolutionStage: 'baby',
      growthStage: 0,
      growthProgress: 0.0,
      interactionCount: 1,
      currentEnvironment: 'pasture',
      gifts: [],
      unlockedEnvironments: ['pasture'],
      isSleeping: false,
      inventory: [{'itemId': 'basic_food', 'quantity': 5}],
      unlockedCosmetics: [],
      customizations: {},
      memories: [],
    );

    state = AsyncValue.data(fresh);
    await _repo.savePet(fresh);
  }

  /// Gift system (post-testing spec): award from mini-games for 3D habitat decorations (Unity prefabs).
  /// Awards persist in PetState.gifts and can decorate environment (visual stub in current clay painter).
  Future<void> awardGift(String giftId) async {
    final current = state.value;
    if (current == null) return;
    final updatedGifts = [...current.gifts, giftId];
    final updated = current.copyWith(gifts: updatedGifts);
    state = AsyncValue.data(updated);
    await _repo.savePet(updated);
  }

  /// Force a "time jump" for testing offline progression (dev helper).
  Future<void> simulateTimeAway(Duration duration) async {
    final current = state.value;
    if (current == null) return;

    final config = PetTypeConfig.forType(current.petType);
    final result = TimeSimulator.applyOfflineDecay(
      elapsed: duration,
      currentStats: current.stats,
      decayRates: config.decayRates,
    );

    var updated = current.copyWith(
      stats: result.newStats,
      lastUpdated: DateTime.now(),
    );

    for (final txt in result.awayMemories) {
      final mem = PetSimulator.createAwayMemory(txt, result.newStats);
      if (mem != null) {
        updated = updated.copyWith(memories: [...updated.memories, mem]);
      }
    }

    state = AsyncValue.data(updated);
    await _repo.savePet(updated);
  }

  /// Expose RAG retrieval for the chat page (uses current state memories).
  List<MemoryEntry> getRelevantMemories(String query, {int topK = 5}) {
    final current = state.value;
    if (current == null) return [];
    return MemoryRAGService.retrieveRelevant(
      allMemories: current.memories,
      query: query,
      topK: topK,
    );
  }
}
