import 'package:virtual_pet_app/core/utils/vector_utils.dart';

/// Episodic memory entry. The heart of the RAG feature.
/// In full ObjectBox version this would be annotated with @Entity and @HnswIndex on embedding.
class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.text,
    required this.metadataJson,
    required this.importance,
    required this.embedding,
    this.statSnapshot,
  });

  final String id;               // uuid or timestamp based
  final DateTime timestamp;
  final String eventType;        // feed, play, clean, pet, talk, milestone, away_...
  final String text;             // natural language for journal + RAG context
  final String metadataJson;     // JSON string of extra (item, deltas, etc.)
  final double importance;       // 0.0 - 1.0
  final List<double> embedding;  // vector (demo dim or 768)
  final Map<String, double>? statSnapshot; // optional snapshot at time of event

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'text': text,
        'metadataJson': metadataJson,
        'importance': importance,
        'embedding': embedding,
        'statSnapshot': statSnapshot,
      };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: json['eventType'] as String,
        text: json['text'] as String,
        metadataJson: json['metadataJson'] as String,
        importance: (json['importance'] as num).toDouble(),
        embedding: (json['embedding'] as List).cast<double>(),
        statSnapshot: json['statSnapshot'] != null
            ? Map<String, double>.from((json['statSnapshot'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())))
            : null,
      );

  /// Convenience: recency boost (more recent = higher effective importance for retrieval)
  double recencyBoost(DateTime now, {double halfLifeHours = 72}) {
    final hours = now.difference(timestamp).inMinutes / 60.0;
    return (1.0 / (1.0 + hours / halfLifeHours)).clamp(0.1, 1.0);
  }
}
