import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:intl/intl.dart';

/// Memory journal - shows the pet's episodic memories.
/// Demonstrates the persistent RAG storage in human-readable form.
class MemoryJournalPage extends ConsumerWidget {
  const MemoryJournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Journal'),
      ),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading memories: $e')),
        data: (pet) {
          final memories = [...pet.memories]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (memories.isEmpty) {
            return const Center(child: Text('No memories yet. Start caring for your pet!'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: memories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = memories[index];
              return _MemoryTile(memory: m);
            },
          );
        },
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final MemoryEntry memory;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().add_jm().format(memory.timestamp);
    final imp = (memory.importance * 100).round();

    return ListTile(
      leading: CircleAvatar(
        child: Text(memory.eventType[0].toUpperCase()),
      ),
      title: Text(memory.text),
      subtitle: Text('$dateStr  •  Importance: $imp%  •  ${memory.eventType}'),
      isThreeLine: true,
      trailing: memory.eventType == 'away'
          ? const Icon(Icons.access_time, size: 18, color: Colors.grey)
          : null,
    );
  }
}
