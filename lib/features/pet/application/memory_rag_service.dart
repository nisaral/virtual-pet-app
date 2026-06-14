import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/core/utils/vector_utils.dart';

/// Memory + RAG service.
/// MVP uses fake embeddings + cosine + hybrid recency/importance ranking.
/// Production version: swap embedder for real on-device model + ObjectBox HNSW query.
class MemoryRAGService {
  /// Retrieve the most relevant memories for a query (chat or reflection).
  /// Returns top memories with a short explanation string for UI.
  static List<MemoryEntry> retrieveRelevant({
    required List<MemoryEntry> allMemories,
    required String query,
    int topK = 6,
  }) {
    if (allMemories.isEmpty || query.trim().isEmpty) {
      // Fallback: most recent + highest importance
      final sorted = [...allMemories]..sort((a, b) {
          final scoreA = a.importance * a.recencyBoost(DateTime.now());
          final scoreB = b.importance * b.recencyBoost(DateTime.now());
          return scoreB.compareTo(scoreA);
        });
      return sorted.take(topK).toList();
    }

    final qVec = VectorUtils.fakeEmbed(query);
    final now = DateTime.now();

    final scored = allMemories.map((m) {
      final sim = VectorUtils.cosineSimilarity(qVec, m.embedding);
      final recency = m.recencyBoost(now);
      final hybrid = (sim * 0.55) + (m.importance * 0.25) + (recency * 0.20);
      return (memory: m, score: hybrid);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((s) => s.memory).toList();
  }

  /// Build a compact context block for the "LLM" prompt (or mock chat logic).
  static String buildContextBlock(List<MemoryEntry> memories, PetState pet) {
    if (memories.isEmpty) return 'No strong memories yet. This is a new relationship.';
    final lines = memories.map((m) {
      final days = DateTime.now().difference(m.timestamp).inDays;
      final when = days == 0 ? 'today' : '$days days ago';
      return '- ${m.text} ($when, importance ${(m.importance * 100).round()}%)';
    }).join('\n');
    return 'Relevant memories for ${pet.name}:\n$lines';
  }
}
