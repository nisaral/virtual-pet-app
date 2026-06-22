import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_state.dart';
import 'package:virtual_pet_app/features/pet/domain/models/pet_type.dart';
import 'package:virtual_pet_app/features/pet/presentation/widgets/pet_visual.dart'; // fallback to 2D for snake or missing model

/// 3D Pet View using model_viewer_plus for user-provided .glb models.
/// 
/// Format for models you provide:
/// - .glb (binary glTF) - single file, best for mobile. Include embedded textures.
/// - Animations: Add named animation clips in the model (e.g. "Idle", "Happy", "Sad", "Eat", "Play", "Groom").
/// - Rigged models preferred for smooth movement.
/// - Place in assets/models/whale.glb, cow.glb, snake.glb
/// - Low-poly recommended for performance (under 50k triangles).
/// 
/// Usage: Pass current PetState to drive animation-name based on mood/growth.
/// Example: If growth high and happy -> "Play" or "Happy" clip.
/// 
/// For Unity: Replace this with flutter_unity_widget + your exported Unity scene (Blend Trees for mood/growth blending).
class Pet3DView extends StatelessWidget {
  const Pet3DView({
    super.key,
    required this.pet,
    this.width = 300,
    this.height = 300,
  });

  final PetState pet;
  final double width;
  final double height;

  String get _modelPath {
    switch (pet.petType) {
      case PetType.whale:
        return 'assets/models/whale.glb'; // your model with idle, run, dying + blinking blendshape
      case PetType.cow:
        // your two cow models - switch by growth (not hardcoded)
        return pet.growthStage == 0 || pet.growthProgress < 0.5
            ? 'assets/models/cow_small.glb'
            : 'assets/models/cow_big.glb';
      case PetType.snake:
        return ''; // no model yet - fallback
    }
  }

  String get _animationName {
    // Drive from state - not hardcoded. Matches your whale exactly: idle, run, dying.
    // Blinking blendshape plays as part of the model.
    // For cow: static or their built-in (small/big models).
    if (pet.isSleeping) return 'idle';
    if (pet.stats.hunger > 80 || pet.stats.cleanliness < 30) return 'dying';
    if (pet.stats.happiness > 80 || pet.growthProgress > 0.7) return 'run';
    return 'idle';
  }

  @override
  Widget build(BuildContext context) {
    if (pet.petType == PetType.snake || _modelPath.isEmpty) {
      // Fallback to 2D (enhanced realistic clay shading) until snake.glb
      return PetVisual(pet: pet);
    }
    // Real 3D: your whale (animations + blendshape), cow small/big models.
    // Animation from state to match your clips (idle/run/dying) - not hardcoded.
    return SizedBox(
      width: width,
      height: height,
      child: ModelViewer(
        src: _modelPath,
        alt: '${pet.name} the ${pet.petType.displayName}',
        ar: false,
        autoRotate: false,
        animationName: _animationName,
        backgroundColor: const Color.fromARGB(0, 0, 0, 0),
      ),
    );
  }
}