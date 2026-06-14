import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:virtual_pet_app/features/pet/domain/pet_repository.dart';
import 'package:virtual_pet_app/features/pet/data/datasources/local_pet_datasource.dart';

/// Concrete implementation using the local JSON datasource.
/// In future: swap in ObjectBox version that also maintains vector index.
class PetRepositoryImpl implements PetRepository {
  PetRepositoryImpl(this._dataSource);

  final LocalPetDataSource _dataSource;

  @override
  Future<PetState?> getActivePet() => _dataSource.loadPet();

  @override
  Future<void> savePet(PetState pet) => _dataSource.savePet(pet);

  @override
  Future<void> addMemory(String petId, MemoryEntry memory) => _dataSource.addMemory(memory);

  @override
  Future<List<MemoryEntry>> getMemories(String petId, {int limit = 50}) async {
    final pet = await getActivePet();
    if (pet == null || pet.id != petId) return [];
    final sorted = [...pet.memories]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> clearAll() => _dataSource.clear();
}
