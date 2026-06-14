import 'package:flutter/material.dart';
import 'package:virtual_pet_app/features/pet/domain/models/stats.dart';

class StatBars extends StatelessWidget {
  const StatBars({super.key, required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatBar(label: 'Hunger', value: stats.hunger, color: Colors.orange),
        _StatBar(label: 'Happiness', value: stats.happiness, color: Colors.pink),
        _StatBar(label: 'Cleanliness', value: stats.cleanliness, color: Colors.blue),
        _StatBar(label: 'Energy', value: stats.energy, color: Colors.amber),
        _StatBar(label: 'Affection', value: stats.affection, color: Colors.purple),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 14,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Text('${value.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
