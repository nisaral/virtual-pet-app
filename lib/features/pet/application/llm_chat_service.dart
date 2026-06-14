import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/application/memory_rag_service.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type_config.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';

/// Very lightweight "LLM" chat service for MVP.
/// Uses RAG-retrieved memories + current stats + personality prompt to produce
/// in-character responses without any external calls (fully offline & private).
/// 
/// When ready for real RAG: replace _generateMockReply with call to
/// flutter_gemma (or cloud) using the exact prompt returned by buildPrompt().
class LLMChatService {
  /// Main entry: given user message + current pet state, return pet's reply + used memories.
  static ({String reply, List<String> usedMemorySnippets}) generateReply({
    required PetState pet,
    required String userMessage,
  }) {
    final config = PetTypeConfig.forType(pet.petType);
    final relevant = MemoryRAGService.retrieveRelevant(
      allMemories: pet.memories,
      query: userMessage,
      topK: 5,
    );

    final context = MemoryRAGService.buildContextBlock(relevant, pet);

    final prompt = '''
You are ${pet.name}, ${config.type.displayName.toLowerCase()}.
${config.personality}

Current state: ${pet.stats.toMap()}. Overall mood: ${pet.moodDescription}. Level ${pet.level} (${pet.evolutionStage}).

$context

User just said: "$userMessage"

Reply in 1-3 short, cute, in-character sentences. Reference one memory naturally if it fits. Stay true to personality. End with a small question or affection sometimes.
''';

    final reply = _generateMockReply(pet, userMessage, relevant, config);
    final snippets = relevant.map((m) => m.text).toList();

    return (reply: reply, usedMemorySnippets: snippets);
  }

  // Rule + template based "generation" that feels smart thanks to RAG context.
  // This makes the demo immediately impressive and fully local.
  // Per spec: also used for standalone "pet thoughts" on open.
  static String _generateMockReply(
    PetState pet,
    String userMsg,
    List memories,
    PetTypeConfig config,
  ) {
    final lower = userMsg.toLowerCase();
    final mood = pet.moodDescription;
    final name = pet.name;

    String base;
    if (lower.contains('hungry') || lower.contains('food') || lower.contains('eat')) {
      base = mood == 'starving'
          ? "I am sooo hungry... please feed me soon!"
          : "I could go for a snack. ${config.type == PetType.whale ? 'Some fresh kelp would be lovely.' : config.type == PetType.cow ? 'Hay or apples?' : 'Something warm and wriggly?'}";
    } else if (lower.contains('happy') || lower.contains('love') || lower.contains('miss')) {
      base = "Aww, I missed you too! Being with you always makes my ${config.type == PetType.snake ? 'scales' : 'heart'} feel warm.";
    } else if (lower.contains('play') || lower.contains('game') || lower.contains('groom')) {
      base = "Yes! Let's play or groom! ${config.preferredActions.contains('play') ? 'I have so much energy for it.' : 'Even if I am a little tired, time with you is the best.'}";
    } else if (memories.isNotEmpty && (lower.contains('remember') || lower.contains('what') || lower.contains('yesterday'))) {
      final m = memories.first as dynamic;
      base = "Of course I remember... ${m.text} That was special.";
    } else {
      // Default personality-tinged reply
      base = switch (config.type) {
        PetType.whale => "The currents of our time together are gentle and good. Thank you for checking on me.",
        PetType.cow => "Moo~ I'm doing alright! It's always better when you're here though.",
        PetType.snake => "Hisss... you always show up at the best times. I was just thinking about you.",
        _ => "I'm glad you're here.",
      };
    }

    // Inject mild mood awareness
    if (mood == 'sad' || mood == 'restless') {
      base += " I feel a bit ${mood} right now... but talking helps.";
    } else if (mood == 'ecstatic') {
      base += " Everything feels wonderful today!";
    }

    return base;
  }

  /// Generates a standalone "pet thought" for the home screen (per spec).
  /// Takes rich context: stats, growth, time of day, recent memory.
  /// Ready to be replaced by real LLM API call with the same prompt builder.
  static String generateCurrentThought(PetState pet) {
    final config = PetTypeConfig.forType(pet.petType);
    final mood = pet.moodDescription;
    final hour = DateTime.now().hour;
    final timeDesc = hour < 7 ? 'early morning' : (hour < 18 ? 'beautiful day' : 'quiet evening');

    final recent = pet.memories.isNotEmpty ? pet.memories.last.text : null;

    String thought;
    if (pet.stats.hunger > 80) {
      thought = "The ${timeDesc} feels empty without a snack...";
    } else if (pet.growthProgress > 0.7) {
      thought = "I'm getting so big! I wonder what new adventures we'll have.";
    } else if (recent != null && recent.toLowerCase().contains('groom')) {
      thought = "That brushing felt amazing. My ${config.type == PetType.whale ? 'skin' : 'coat'} is so smooth now.";
    } else {
      thought = switch (config.type) {
        PetType.whale => "The water is calm in this $timeDesc, but it would be nicer with you here.",
        PetType.cow => "The pasture is peaceful. I hope you come brush me again soon, moo~",
        PetType.snake => "Curled up warm. Thinking about our last ${recent != null ? 'playtime' : 'talk'}.",
        _ => "Just thinking about you in this $timeDesc.",
      };
    }

    if (mood == 'sad' || mood == 'restless') {
      thought += " ...I miss our time together.";
    }
    return thought;
  }
}
