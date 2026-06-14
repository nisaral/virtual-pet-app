import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';

/// Simple file-based JSON persistence for immediate runnable MVP.
/// Matches the plan's "local_pet_datasource" but uses JSON instead of ObjectBox initially.
/// Easy to replace with ObjectBox implementation (same interface).
class LocalPetDataSource {
  static const _petFileName = 'active_pet.json';

  Future<File> _getPetFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_petFileName');
  }

  Future<PetState?> loadPet() async {
    try {
      final file = await _getPetFile();
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      if (contents.isEmpty) return null;
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return PetState.fromJson(json);
    } catch (e) {
      // Corrupt file or first run - return null and let caller create default
      return null;
    }
  }

  Future<void> savePet(PetState pet) async {
    final file = await _getPetFile();
    final json = jsonEncode(pet.toJson());
    await file.writeAsString(json, flush: true);
  }

  Future<void> addMemory(MemoryEntry memory) async {
    // Load current, append memory, save (simple for MVP; not optimal for huge history)
    final current = await loadPet();
    if (current == null) return;
    final updatedMemories = [...current.memories, memory];
    // Keep memory list reasonable (plan mentions pruning later)
    final capped = updatedMemories.length > 300
        ? updatedMemories.sublist(updatedMemories.length - 300)
        : updatedMemories;
    final updated = current.copyWith(memories: capped);
    await savePet(updated);
  }

  Future<void> clear() async {
    final file = await _getPetFile();
    if (await file.exists()) await file.delete();
  }
}
