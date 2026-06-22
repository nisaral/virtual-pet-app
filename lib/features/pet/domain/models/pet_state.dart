import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';

/// The complete persistent state for a single pet.
/// Updated to match new architecture spec (growth via milestones + progress 0-1,
/// shared memory for multiplayer, etc.).
/// JSON-ready for Supabase or local.
class PetState {
  const PetState({
    required this.id,
    required this.petType,
    required this.name,
    required this.createdAt,
    required this.lastUpdated,
    required this.lastInteraction,
    required this.stats,
    required this.ageDays,
    required this.level,
    required this.xp,
    required this.evolutionStage,
    required this.growthStage,
    required this.growthProgress, // 0.0 baby -> 1.0 adult (morph target value)
    required this.interactionCount, // for milestone-based growth
    required this.currentEnvironment,
    required this.gifts,
    required this.unlockedEnvironments,
    required this.isSleeping,
    required this.inventory,
    required this.unlockedCosmetics,
    required this.customizations,
    required this.memories,
    this.schemaVersion = 2,
  });

  final String id;
  final PetType petType;
  final String name;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final DateTime lastInteraction;

  final Stats stats;
  final int ageDays;
  final int level;
  final int xp;
  final String evolutionStage;

  // New per spec: growth engine (milestones + smooth 0-1 progress for morphs)
  final int growthStage; // 0=baby, 1=juvenile, 2=adult
  final double growthProgress; // 0.0 to 1.0 - drives blend/morph in visuals
  final int interactionCount; // total successful care actions for milestone growth

  // For Unity pivot + new features (Discovery Path, gifts, environments - post-phone testing)
  final String currentEnvironment; // e.g. "pond", "pasture", "cave" - swap prefabs
  final List<String> gifts; // e.g. ["shell", "flower"] from mini-games for 3D decorations
  final List<String> unlockedEnvironments; // for evolution choices (Discovery Path)

  final bool isSleeping;
  final List<Map<String, dynamic>> inventory; // simple [{itemId, quantity}]
  final List<String> unlockedCosmetics;
  final Map<String, dynamic> customizations;

  final List<MemoryEntry> memories; // kept in memory for RAG + shared memory log

  final int schemaVersion;

  PetState copyWith({
    String? id,
    PetType? petType,
    String? name,
    DateTime? createdAt,
    DateTime? lastUpdated,
    DateTime? lastInteraction,
    Stats? stats,
    int? ageDays,
    int? level,
    int? xp,
    String? evolutionStage,
    int? growthStage,
    double? growthProgress,
    int? interactionCount,
    String? currentEnvironment,
    List<String>? gifts,
    List<String>? unlockedEnvironments,
    bool? isSleeping,
    List<Map<String, dynamic>>? inventory,
    List<String>? unlockedCosmetics,
    Map<String, dynamic>? customizations,
    List<MemoryEntry>? memories,
    int? schemaVersion,
  }) {
    return PetState(
      id: id ?? this.id,
      petType: petType ?? this.petType,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      stats: stats ?? this.stats,
      ageDays: ageDays ?? this.ageDays,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      evolutionStage: evolutionStage ?? this.evolutionStage,
      growthStage: growthStage ?? this.growthStage,
      growthProgress: growthProgress ?? this.growthProgress,
      interactionCount: interactionCount ?? this.interactionCount,
      currentEnvironment: currentEnvironment ?? this.currentEnvironment,
      gifts: gifts ?? this.gifts,
      unlockedEnvironments: unlockedEnvironments ?? this.unlockedEnvironments,
      isSleeping: isSleeping ?? this.isSleeping,
      inventory: inventory ?? this.inventory,
      unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
      customizations: customizations ?? this.customizations,
      memories: memories ?? this.memories,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  // Matches the spec JSON structure + extensions for growth/milestones/RAG
  Map<String, dynamic> toJson() => {
        'pet_id': id,
        'species': petType.id,
        'stats': {
          'hunger': stats.hunger,
          'hygiene': stats.cleanliness, // hygiene = cleanliness per spec
          'growth_stage': growthStage,
          'growth_progress': growthProgress,
          ...stats.toMap(),
        },
        'memory_vector_id': memories.isNotEmpty ? memories.last.id : null,
        'last_interaction': lastInteraction.toIso8601String(),
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
        'ageDays': ageDays,
        'level': level,
        'xp': xp,
        'evolutionStage': evolutionStage,
        'interactionCount': interactionCount,
        'currentEnvironment': currentEnvironment,
        'gifts': gifts,
        'unlockedEnvironments': unlockedEnvironments,
        'isSleeping': isSleeping,
        'inventory': inventory,
        'unlockedCosmetics': unlockedCosmetics,
        'customizations': customizations,
        'memories': memories.map((m) => m.toJson()).toList(),
        'schemaVersion': schemaVersion,
      };

  factory PetState.fromJson(Map<String, dynamic> json) {
    final petType = PetType.fromId((json['species'] ?? json['petType']) as String);
    final statsMap = (json['stats'] as Map<String, dynamic>?) ?? {};
    final memoriesJson = (json['memories'] as List?) ?? [];
    return PetState(
      id: (json['pet_id'] ?? json['id']) as String,
      petType: petType,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      lastInteraction: DateTime.parse(json['last_interaction'] ?? json['lastInteraction'] as String),
      stats: Stats.fromMap(statsMap.isNotEmpty ? statsMap : (json['stats'] as Map<String, dynamic>)),
      ageDays: (json['ageDays'] ?? 0) as int,
      level: (json['level'] ?? 1) as int,
      xp: (json['xp'] ?? 0) as int,
      evolutionStage: (json['evolutionStage'] ?? 'baby') as String,
      growthStage: (statsMap['growth_stage'] ?? json['growthStage'] ?? 0) as int,
      growthProgress: ((statsMap['growth_progress'] ?? json['growthProgress'] ?? 0.0) as num).toDouble(),
      interactionCount: (json['interactionCount'] ?? 0) as int,
      currentEnvironment: (json['currentEnvironment'] ?? 'pond') as String,
      gifts: ((json['gifts'] as List?) ?? []).cast<String>(),
      unlockedEnvironments: ((json['unlockedEnvironments'] as List?) ?? []).cast<String>(),
      isSleeping: (json['isSleeping'] ?? false) as bool,
      inventory: ((json['inventory'] as List?) ?? []).cast<Map<String, dynamic>>(),
      unlockedCosmetics: ((json['unlockedCosmetics'] as List?) ?? []).cast<String>(),
      customizations: Map<String, dynamic>.from(json['customizations'] as Map? ?? {}),
      memories: memoriesJson.map((e) => MemoryEntry.fromJson(e as Map<String, dynamic>)).toList(),
      schemaVersion: (json['schemaVersion'] as int?) ?? 2,
    );
  }

  /// Convenience for RAG / display
  String get moodDescription {
    final avg = stats.average;
    if (avg > 80) return 'ecstatic';
    if (avg > 65) return 'happy';
    if (avg > 45) return 'content';
    if (avg > 25) return 'restless';
    return 'sad';
  }
}
