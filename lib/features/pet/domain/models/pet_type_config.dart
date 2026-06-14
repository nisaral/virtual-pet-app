import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/core/constants.dart';

/// Data-driven configuration per pet type. Easy to extend with more pets or balance changes.
class PetTypeConfig {
  const PetTypeConfig({
    required this.type,
    required this.displayName,
    required this.emoji,
    required this.decayRates,
    required this.personality,
    required this.preferredActions,
    required this.baseDescription,
  });

  final PetType type;
  final String displayName;
  final String emoji;
  final Map<String, double> decayRates;
  final String personality;
  final List<String> preferredActions; // e.g. ['feed', 'play']
  final String baseDescription;

  static final Map<PetType, PetTypeConfig> all = {
    PetType.whale: PetTypeConfig(
      type: PetType.whale,
      displayName: 'Whale',
      emoji: '🐳',
      decayRates: AppConstants.baseDecayRates[PetType.whale]!,
      personality: AppConstants.personalityPrompts[PetType.whale]!,
      preferredActions: ['feed', 'pet', 'talk'],
      baseDescription: 'A gentle giant of the deep who values calm companionship.',
    ),
    PetType.cow: PetTypeConfig(
      type: PetType.cow,
      displayName: 'Cow',
      emoji: '🐄',
      decayRates: AppConstants.baseDecayRates[PetType.cow]!,
      personality: AppConstants.personalityPrompts[PetType.cow]!,
      preferredActions: ['feed', 'play', 'clean'],
      baseDescription: 'A cheerful farm friend who thrives on attention and good food.',
    ),
    PetType.snake: PetTypeConfig(
      type: PetType.snake,
      displayName: 'Snake',
      emoji: '🐍',
      decayRates: AppConstants.baseDecayRates[PetType.snake]!,
      personality: AppConstants.personalityPrompts[PetType.snake]!,
      preferredActions: ['play', 'pet', 'talk'],
      baseDescription: 'A clever and affectionate serpent with a playful sense of humor.',
    ),
  };

  static PetTypeConfig forType(PetType type) => all[type]!;
}
