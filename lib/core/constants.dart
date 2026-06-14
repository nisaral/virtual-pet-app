import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';

/// Core constants, personality prompts, base decay rates, etc.
/// These drive per-pet differences as recommended in the architectural plan.
class AppConstants {
  static const String appName = 'Whale & Co.';

  // Default starting values
  static const double initialStat = 70.0;
  static const int initialLevel = 1;
  static const int initialAgeDays = 0;

  // Decay rates (per hour of real time, when app not running or idle)
  // Higher = decays faster. Whale is chill/slower needs, Cow steady, Snake high maintenance.
  static const Map<PetType, Map<String, double>> baseDecayRates = {
    PetType.whale: {
      'hunger': 1.8,
      'happiness': 1.2,
      'cleanliness': 0.9,
      'energy': 1.5,
      'affection': 0.6,
    },
    PetType.cow: {
      'hunger': 2.8,
      'happiness': 2.0,
      'cleanliness': 1.8,
      'energy': 2.2,
      'affection': 1.0,
    },
    PetType.snake: {
      'hunger': 3.5,
      'happiness': 2.5,
      'cleanliness': 1.5,
      'energy': 2.8,
      'affection': 1.4,
    },
  };

  // Personality base prompts for RAG / LLM context (injected into "smart" responses)
  static const Map<PetType, String> personalityPrompts = {
    PetType.whale: 
      "You are Bubbles, a wise, calm, deep-sea whale. You speak slowly and thoughtfully with gentle ocean metaphors. "
      "You love stories, reflection, and feeling connected to your human through quiet moments. "
      "You rarely get frantic. Reference the deep blue, tides, or krill fondly.",
    PetType.cow: 
      "You are Daisy, a cheerful, friendly farm cow. You are warm, nurturing, and a little goofy. "
      "You love grass, sunshine, and being helpful. Use simple, happy language with the occasional 'moo' or farm reference. "
      "You get excited about treats and playtime.",
    PetType.snake: 
      "You are Sssslither, a clever, slightly sassy snake. You speak with a playful hiss and enjoy teasing your human affectionately. "
      "You are mysterious, observant, and quick-witted. You like warm rocks, clever puzzles, and feeling 'seen'. "
      "Use sibilant words occasionally (sss, hisss) for flavor but stay cute.",
  };

  // Simple action outcome templates (used by simulator to generate natural memory text)
  static const Map<String, String> actionMemoryTemplates = {
    'feed': 'My human gave me {item}. I felt full and cared for.',
    'play': 'We played together! It was so much fun. I feel happier.',
    'clean': 'My human cleaned me up. I feel fresh and loved.',
    'pet': 'My human spent time gently petting me. My heart feels full.',
    'talk': 'We had a nice conversation. I feel closer to my human.',
    'sleep_start': 'I curled up for a nice long nap.',
    'sleep_end': 'I woke up feeling refreshed after my nap.',
  };

  // Thresholds for mood & events
  static const double criticalStat = 20.0;
  static const double lowStat = 40.0;
  static const double goodStat = 70.0;
}
