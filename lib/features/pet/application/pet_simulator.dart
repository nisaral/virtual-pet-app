import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/features/pet/domain/models/memory_entry.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type_config.dart';
import 'package:virtual_pet_app/core/constants.dart';
import 'package:virtual_pet_app/core/utils/vector_utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Pure-ish simulation service for stat changes, mood, progression, and memory generation.
/// Updated per new spec: Growth driven by Interaction Milestones + smooth progress (0-1 for morph targets).
/// Care loop uses decay_rate logic. Mood affects visuals.
class PetSimulator {
  // Growth is now **totally dependent on grooming and quality of care** (per latest spec).
  // Strong bias toward 'groom', 'clean', 'pet', 'feed' (good care).
  // Minimum real calendar time: 30-45 days even with perfect care.
  // Use a "care_quality_points" system weighted heavily to grooming.
  static const int MIN_GROWTH_DAYS = 35; // 30-45 days min

  // Care points per action (grooming is king for growth)
  static const Map<String, int> carePoints = {
    'groom': 12,
    'clean': 8,
    'pet': 6,
    'feed': 5,
    'play': 3,
    'talk': 2,
  };

  /// Apply an action (feed, play, etc.) and return new state + created memory (if any).
  static ({PetState newState, MemoryEntry? newMemory}) applyAction({
    required PetState current,
    required String action,
    Map<String, dynamic>? extra, // e.g. {'item': 'kelp'}
  }) {
    final config = PetTypeConfig.forType(current.petType);
    final now = DateTime.now();

    // Base deltas (positive = improvement). Tune per action/type.
    Map<String, double> deltas = switch (action) {
      'feed' => {'hunger': -35, 'happiness': +8, 'affection': +5},
      'play' => {'happiness': +25, 'energy': -12, 'affection': +10},
      'clean' => {'cleanliness': -40, 'happiness': +12, 'affection': +4},
      'pet' => {'happiness': +15, 'affection': +18, 'energy': +3},
      'talk' => {'happiness': +10, 'affection': +12},
      'groom' => {'hygiene': -30, 'happiness': +18, 'affection': +8}, // Grooming is core for growth
      _ => {'happiness': +5},
    };

    // Bonus if action matches pet preference
    if (config.preferredActions.contains(action)) {
      deltas = deltas.map((k, v) => MapEntry(k, v * 1.25));
    }

    final newStats = current.stats.applyDeltas(deltas);

    // XP / level (demo)
    int newXp = current.xp + (action == 'play' || action == 'groom' ? 12 : 6);
    int newLevel = current.level;
    String newStage = current.evolutionStage;

    // === NEW GROWTH LOGIC: Grooming & Care Quality + Min 35 days ===
    final newInteractionCount = current.interactionCount + 1;
    final carePointsEarned = carePoints[action] ?? 1;

    // Accumulate "care quality" for growth (heavily favors grooming)
    // We store effective care points in a custom field via metadata or reuse interactionCount * quality
    // For simplicity, we derive growth from a weighted "effectiveCare" 
    // (in real, could add careQualityScore to PetState)
    final daysSinceCreation = now.difference(current.createdAt).inDays;
    final timeFactor = (daysSinceCreation / MIN_GROWTH_DAYS).clamp(0.0, 1.0);

    // Care-driven progress (grooming dominant)
    final careDrivenProgress = (newInteractionCount * 0.004) + (carePointsEarned * 0.008); // tuned for grooming bias

    // Final growthProgress = care quality * time floor (min days enforced)
    double newGrowthProgress = (careDrivenProgress * timeFactor).clamp(0.0, 1.0);

    int newGrowthStage = 0;
    if (newGrowthProgress > 0.66) {
      newGrowthStage = 2; // adult
    } else if (newGrowthProgress > 0.33) {
      newGrowthStage = 1; // juvenile
    }

    // Force min time for stage changes
    if (newGrowthStage > current.growthStage && daysSinceCreation < MIN_GROWTH_DAYS) {
      newGrowthStage = current.growthStage;
      newGrowthProgress = (current.growthStage + 0.33).clamp(0.0, 0.99);
    }

    if (newXp >= current.level * 25) {
      newLevel += 1;
      newXp = 0;
      if (newLevel % 3 == 0) {
        newStage = newLevel < 6 ? 'juvenile' : 'adult';
      }
    }

    // Generate memory text (improved for spec)
    String text = AppConstants.actionMemoryTemplates[action] ?? 'We did something nice together.';
    final item = extra?['item'] as String?;
    if (item != null) {
      text = text.replaceAll('{item}', item);
    }
    if (action == 'groom') {
      text = 'My human gently brushed me. It felt so good and I feel cleaner!';
    }

    final memory = MemoryEntry(
      id: _uuid.v4(),
      timestamp: now,
      eventType: action,
      text: text,
      metadataJson: '{"action":"$action","deltas":${deltas.toString()}${item != null ? ',"item":"$item"' : ''},"care_points":$carePointsEarned}',
      importance: _calculateImportance(deltas, action),
      embedding: VectorUtils.fakeEmbed(text),
      statSnapshot: newStats.toMap(),
    );

    final updated = current.copyWith(
      stats: newStats,
      lastInteraction: now,
      lastUpdated: now,
      level: newLevel,
      xp: newXp,
      evolutionStage: newStage,
      growthStage: newGrowthStage,
      growthProgress: newGrowthProgress.clamp(0.0, 1.0),
      interactionCount: newInteractionCount,
      memories: [...current.memories, memory],
    );

    return (newState: updated, newMemory: memory);
  }

  static double _calculateImportance(Map<String, double> deltas, String action) {
    double sum = deltas.values.fold(0.0, (p, e) => p + e.abs());
    double base = (sum / 80.0).clamp(0.2, 1.0);
    if (action == 'play' || action == 'talk') base *= 1.15;
    return base.clamp(0.1, 1.0);
  }

  /// Compute a simple mood string from current stats (used in UI + RAG prompt).
  static String computeMood(Stats stats) {
    final avg = stats.average;
    if (stats.hunger > 85) return 'starving';
    if (stats.cleanliness < 15) return 'filthy';
    if (avg > 82) return 'ecstatic';
    if (avg > 68) return 'happy';
    if (avg > 48) return 'content';
    if (avg > 28) return 'restless';
    return 'sad';
  }

  /// Create an "away" memory from simulator results (used by time handling).
  static MemoryEntry? createAwayMemory(String text, Stats statsAtTime) {
    if (text.isEmpty) return null;
    return MemoryEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      eventType: 'away',
      text: text,
      metadataJson: '{"source":"offline"}',
      importance: 0.65,
      embedding: VectorUtils.fakeEmbed(text),
      statSnapshot: statsAtTime.toMap(),
    );
  }
}
