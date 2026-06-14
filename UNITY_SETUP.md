# Unity + Flutter Hybrid Setup (Post-Phone Testing Pivot)

This is the path to move from the successful button-based/claymation Flutter prototype (tested on phone, full RAG/growth/grooming/haptics/mini-animations) to high-fidelity 3D interactive simulation.

**Current State (Flutter APK)**: Polished 2D "clay" pet with all core logic (milestone growth on grooming/care + 35-day min, floating thoughts, gesture grooming, emotional UI, RAG memories). Use this to validate features before full Unity port. The prototype builds/runs via GitHub Actions (no local Flutter needed for APK).

**Goal**: Unity for 3D pet + habitat (Blend Trees, morph targets, raycast mini-games, prefabs). Flutter shell for everything else (UI overlays, persistence, RAG/LLM, auth).

## 1. Prerequisites
- Unity 2022.3 LTS+ (or 2023+ for better features).
- Flutter 3.29+ (current).
- Android Studio / Xcode for exports.
- `flutter_unity_widget` (add to pubspec when ready; currently commented).
- Blender for models/morphs.

## 2. Unity Project Setup (Core 3D)
1. Create new Unity 3D project (or use existing).
2. **Models & Morphs (per spec)**:
   - In Blender: Base model per species (Whale, Cow, Snake).
   - Define **Blend Shapes / Morph Targets**: Baby (round/squishy), Juvenile, Adult (elongated).
   - Export as FBX/glTF with morph targets enabled.
3. **Animations (Blend Trees)**:
   - Import to Unity.
   - Create **Blend Tree** for each species (e.g., 1D or 2D tree blending "Idle Happy", "Sad", "Playing/Groomed", "Swim" for whale).
   - Parameters: `Mood` (0-1 from stats), `GrowthProgress` (0-1 from PetState), `IsGrooming`, `Happiness`.
   - Drive from Flutter via messages (see bridge below).
4. **Environments (Prefabs - no hardcoding)**:
   - Create 3D prefabs: Pond (whale - water + bubbles), Pasture (cow - grass + flowers), Cave (snake - rocks + glow).
   - Swap at runtime based on `currentEnvironmentId` or species/evolution choice (Discovery Path).
   - Add dynamic elements: Time-of-day lights, particle weather (rain/fireflies via script).
5. **Interactions (Raycast + Gestures in 3D)**:
   - **Grooming**: Raycast from touch on pet mesh → brush particles + stat update (sent to Flutter).
   - **Mini-Games (integrated in habitat, not separate screens)**:
     - **Target Catch (Whale)**: Touch/drag to move whale; catch falling objects (particles or prefabs). Happiness++.
     - **Weed Pull (Cow)**: Raycast + drag to remove weed prefabs. Cleanliness++.
     - **Maze Chase (Snake)**: Draw path (or touch to guide); AI follows to treat. Energy++.
   - All update PetState via bridge → RAG memory + growth milestones.
6. **Overlays from Flutter**:
   - Floating thought bubbles (RAG/LLM text) as UI.Text or WorldSpace Canvas over pet.
   - Gift decorations: Instantiate 3D shells/flowers from mini-game rewards; persist via Flutter inventory.
7. **Export for Flutter**:
   - Unity → Build Settings → Android/iOS → Export project (or use Unity as Library).
   - For flutter_unity_widget: Follow package docs (create UnityPlayer, embed in Flutter widget).

## 3. Flutter Side (Shell + Bridge)
- Add to pubspec (uncomment when Unity export ready):
  ```yaml
  flutter_unity_widget: ^0.2.0
  ```
- **UnityView Widget** (stub in current code - replace/enhance PetVisual):
  ```dart
  // In a new file: lib/features/habitat/unity_view.dart
  import 'package:flutter_unity_widget/flutter_unity_widget.dart';
  // ...
  UnityWidget(
    onUnityCreated: onUnityCreated,
    onUnityMessage: (msg) { /* e.g., {"action":"groom","zone":"head"} -> performAction */ },
  );
  ```
  - Send messages from Flutter: `unityWidgetController.postMessage("PetController", "SetGrowth", growthProgress);`
  - Receive from Unity (e.g., mini-game complete → update stats + award gift).
- **Keep Current Logic**: PetController, Simulator (growth on grooming/care + min days), RAG (LLMChatService), local JSON/Supabase.
- **Enhance for New Features** (prototyped in current Flutter, portable):
  - Floating thought bubbles: Stack over UnityView (or current PetVisual) with AnimatedPositioned + RAG text.
  - Real-time events: Device time (already in living space) + geolocator + weather API stub (rain particles in Unity).
  - Gifts: Extend PetState with `gifts: List<String>`. Mini-games award (e.g., "shell" from TargetCatch). Apply in Unity as prefab instances.
  - Evolution Discovery: On milestone in simulator, show choice dialog (unlock Pond/Pasture/Cave). Set `currentEnvironment`.
- **UI/UX Cleanup**: Integrate into main HabitatPage (no bloat). Gestures on 3D view launch mini-games (overlays or Unity scenes). "Talk" = mic in habitat → real-time 3D reaction + floating bubble.
- **Data-Driven (no hardcode)**: Species/Environment configs (JSON or models) drive prefab names, animation params, gift visuals.

## 4. Message Protocol (Flutter <-> Unity)
- Stats: Flutter → Unity: `{ "growth": 0.45, "mood": 0.8, "hunger": 0.3 }`
- Events: Unity → Flutter: `{ "type": "miniGameComplete", "game": "targetCatch", "reward": "shell" }`
- Environment: Flutter → Unity: `{ "environment": "pond", "timeOfDay": "night", "weather": "rain" }`
- Thoughts: Flutter (RAG) → Unity: `{ "text": "The water is calm...", "duration": 5 }` (display as bubble).

## 5. CI / Build Notes
- Flutter side: Current GitHub Actions (with patches for NDK/Kotlin) still works for prototype.
- Unity: Export Android/iOS libs separately (Unity Cloud Build or local). Combine in Flutter build (complex - may need custom script or separate APK for now).
- Test: Prototype mini-games/gifts/events in current Flutter first (gesture-based over PetVisual), then port to Unity.

## 6. Migration Steps (Practical)
1. Set up Unity project + models/prefabs/Blend Trees as above.
2. Export Unity project → add to Flutter assets or via flutter_unity_widget setup.
3. Swap PetVisual → UnityView in HabitatPage (keep Flutter overlays for thoughts/gifts/menus).
4. Port 3 mini-games to Unity (raycast + particles for polish).
5. Wire RAG thoughts as floating bubbles (Unity UI or particles with text).
6. Add weather API (Flutter side) → send to Unity for particles.
7. Gifts: Mini-game rewards → Flutter inventory → Unity instantiate decorations.
8. Evolution choices: Flutter dialog → set environment prefab in Unity.
9. Test on phone: Use current successful APK flow; Unity export adds 3D layer.
10. Polish: Haptics (already in Flutter) + Unity audio for "purrs" during groom.

This gives agency (discovery evolution), immersion (3D gestures/mini-games in habitat), and personality (RAG bubbles + persistent from memories).

Current prototype proves the "soul" (care loop, RAG, growth on real care). Unity adds the visuals and active play.

See ARCHITECTURE.md for full details. Questions? The code here (PetState, Simulator, etc.) is the foundation - just embed the 3D on top.

Next: Uncomment flutter_unity_widget when your Unity export is ready, or ask for help prototyping a specific mini-game in current Flutter. 

Build was successful - great job testing on phone! This pivot will make the next version magical for your girlfriend.