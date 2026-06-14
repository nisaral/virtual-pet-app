import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';
import 'package:virtual_pet_app/core/constants.dart';

/// Pure time-delta simulation logic (core of offline progression).
/// Called on app resume/load to apply real-world elapsed time decay.
class TimeSimulator {
  /// Apply decay and produce side effects (memories, events) for elapsed real hours.
  /// Returns updated stats + list of generated memory texts (for "while you were away").
  static ({Stats newStats, List<String> awayMemories, bool hadCriticalEvent}) applyOfflineDecay({
    required Duration elapsed,
    required Stats currentStats,
    required Map<String, double> decayRates, // per hour
  }) {
    if (elapsed.inSeconds <= 0) {
      return (newStats: currentStats, awayMemories: [], hadCriticalEvent: false);
    }

    final double hours = elapsed.inMinutes / 60.0;
    final List<String> memories = [];
    bool critical = false;

    double hunger = _applyDecay(currentStats.hunger, decayRates['hunger']! * hours);
    double happiness = _applyDecay(currentStats.happiness, decayRates['happiness']! * hours);
    double cleanliness = _applyDecay(currentStats.cleanliness, decayRates['cleanliness']! * hours);
    double energy = _applyDecay(currentStats.energy, decayRates['energy']! * hours);
    double affection = _applyDecay(currentStats.affection, decayRates['affection']! * hours);

    // Generate narrative memories for big changes or thresholds crossed
    if (hunger > AppConstants.criticalStat && currentStats.hunger <= AppConstants.criticalStat) {
      memories.add('I got very hungry while you were away...');
      critical = true;
    }
    if (happiness < AppConstants.lowStat && currentStats.happiness >= AppConstants.goodStat) {
      memories.add('I felt a little lonely and sad without you.');
    }
    if (cleanliness < AppConstants.lowStat) {
      memories.add('I got quite messy while waiting for you.');
    }
    if (energy < AppConstants.lowStat && hours > 4) {
      memories.add('I took a long rest while you were gone.');
    }

    // Big overall drop summary
    final double avgDrop = (currentStats.average - ((hunger + happiness + cleanliness + energy + affection) / 5));
    if (avgDrop > 15 && hours > 2) {
      memories.add('The hours without you were long. I missed our time together.');
    }

    final newStats = Stats(
      hunger: hunger.clamp(0, 100),
      happiness: happiness.clamp(0, 100),
      cleanliness: cleanliness.clamp(0, 100),
      energy: energy.clamp(0, 100),
      affection: affection.clamp(0, 100),
    );

    return (
      newStats: newStats,
      awayMemories: memories,
      hadCriticalEvent: critical,
    );
  }

  static double _applyDecay(double current, double amount) {
    return (current + amount).clamp(0.0, 100.0);
  }
}
