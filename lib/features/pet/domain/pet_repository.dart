import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';

/// Abstract repository (plan recommends abstraction for easy swap of ObjectBox <-> JSON <-> cloud).
abstract class PetRepository {
  Future<PetState?> getActivePet();
  Future<void> savePet(PetState pet);
  Future<void> addMemory(String petId, MemoryEntry memory);
  Future<List<MemoryEntry>> getMemories(String petId, {int limit = 50});
  Future<void> clearAll();
}
