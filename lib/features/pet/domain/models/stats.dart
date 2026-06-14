/// Value class for the five core stats. Immutable + helpers.
class Stats {
  const Stats({
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.energy,
    required this.affection,
  });

  final double hunger;      // high = needs food
  final double happiness;
  final double cleanliness;
  final double energy;
  final double affection;

  double get average => (hunger + happiness + cleanliness + energy + affection) / 5;

  Stats copyWith({
    double? hunger,
    double? happiness,
    double? cleanliness,
    double? energy,
    double? affection,
  }) {
    return Stats(
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      cleanliness: cleanliness ?? this.cleanliness,
      energy: energy ?? this.energy,
      affection: affection ?? this.affection,
    );
  }

  Map<String, double> toMap() => {
        'hunger': hunger,
        'happiness': happiness,
        'cleanliness': cleanliness,
        'energy': energy,
        'affection': affection,
      };

  factory Stats.fromMap(Map<String, dynamic> map) => Stats(
        hunger: (map['hunger'] as num).toDouble(),
        happiness: (map['happiness'] as num).toDouble(),
        cleanliness: (map['cleanliness'] as num).toDouble(),
        energy: (map['energy'] as num).toDouble(),
        affection: (map['affection'] as num).toDouble(),
      );

  /// Apply deltas from an action (negative for hunger reduction = good).
  Stats applyDeltas(Map<String, double> deltas) {
    return copyWith(
      hunger: (hunger + (deltas['hunger'] ?? 0)).clamp(0, 100),
      happiness: (happiness + (deltas['happiness'] ?? 0)).clamp(0, 100),
      cleanliness: (cleanliness + (deltas['cleanliness'] ?? 0)).clamp(0, 100),
      energy: (energy + (deltas['energy'] ?? 0)).clamp(0, 100),
      affection: (affection + (deltas['affection'] ?? 0)).clamp(0, 100),
    );
  }

  @override
  String toString() => 'Stats(hunger: ${hunger.toStringAsFixed(1)}, happiness: ${happiness.toStringAsFixed(1)}, ...)';
}
