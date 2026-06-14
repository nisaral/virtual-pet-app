# Virtual Pet App - Architecture (Updated post-phone testing, 2026-06-14)

This document captures the evolved vision from the original plan + the detailed Visual/Graphics + Core Feature specs + the post-testing pivot to 3D interactive simulation (Unity + Flutter hybrid) provided by the user after successful APK testing on phone.

**Status**: Current MVP is polished Flutter prototype (claymation 2D with full logic, RAG, haptics, growth, grooming, thoughts, etc.) that builds and runs on Android. Pivot to full 3D is next phase. All logic (PetState, simulator, RAG, milestones) is portable to Unity embedding.

## Visual & Graphics Strategy (Current Flutter + Unity Future)

**Current (Flutter APK - successful phone build):**
- **Claymation / Soft 3D aesthetic** implemented procedurally with `CustomPainter` + implicit animations, squash/stretch, procedural lighting/shadows (time-of-day), depth-of-field blur on habitat, emotional states (shake for low hygiene, contextual idle sway vs bounce based on last memory).
- No asset placeholders: fully code-driven "toon" look.
- **Growth "Morph" approximation**: `growthProgress` (0.0 baby → 1.0 adult) lerps proportions (now tied to grooming/care quality + hard min 35 real days).
- **Interactive Grooming Scene**: Tap zones on pet (raycast simulation) for active care.
- **Dynamic Living Space**: Time-of-day backgrounds + early environmental events.
- Species have distinct shapes + details.
- Haptics on groom (medium + light for high contentment).
- Micro-animations: 2.5s elastic growth morph, bouncy thought pop-ins.
- Stats via behavior (not just bars).

**Pivot to 3D (Unity + flutter_unity_widget - recommended for high-fidelity):**
- **The Engine**: Switch core pet/habitat rendering to Unity. Use `flutter_unity_widget` to embed the 3D Unity scene inside the existing Flutter shell (Flutter for menus, Supabase auth, RAG memory persistence, chat overlays; Unity for pet + environment).
- **Animations**: Use Unity **Blend Trees** (not separate models). Blend between "idle", "sad", "playing", "groomed" based on pet's mood/stats/growthProgress (drive from Flutter via messages or shared state).
- **Environments**: Do not hardcode. Create **Environment Prefabs** (3D Pond for whale, Pasture for cow, Cave for snake). Swap prefab on species/evolution or milestone unlocks. Dynamic lighting/weather from real device time + API.
- **Art Style**: Claymation/Soft 3D + Toon Shader in Unity (warm, hand-crafted). Use Blender for base model + **Blend Shapes/Morph Targets** for Baby/Juvenile/Adult (drive single `growthPercentage` 0-1 float).
- **Why Unity**: Native blend shapes, excellent 3D tooling, Timeline for state-driven animations, easy raycasting for interactions, particle systems for gifts/feedback. Original plan noted Unity strength for rich visuals vs Flutter.
- **Integration**: Flutter shell remains (Riverpod state, local JSON/Supabase, RAG). Send stat changes from Unity to Flutter (and vice versa) via the widget bridge. Current CustomPainter PetVisual can be fallback or 2D "journal" view.

Current Flutter version is a high-fidelity 2D prototype that validates all logic and runs on phone. Use it to prototype mini-games/UI before full Unity port.

## Core Feature Specifications (Post-Testing Pivot)

### Redesigning Interaction (Active Care Loop - No Button Bloat)
- **Contextual Interaction**: Integrate directly into 3D/habitat view. Taps/gestures on pet launch contextual actions or mini-games. No isolated "Talk" page.
  - **Microphone for Talking**: Enable mic access. Speech near phone → pet reacts in 3D (head tilt, look at camera) + RAG memory update + floating thought response.
  - **Integrated Mini-Games** (happen in the 3D habitat, update stats directly):
    - **Target Catch (Whale/Orca)**: User touches/drags to guide whale to catch falling stars/bubbles. Increases Happiness. (Flutter prototype: gesture-driven particle catcher; later Unity scene with Blend Tree "swim" anim).
    - **Weed Pull (Cow)**: Tap/drag weeds out of pasture to clean. Increases Cleanliness/Hygiene. (Flutter: drag-to-remove widgets overlaid on habitat; later Unity raycast on 3D weeds).
    - **Maze Chase (Snake)**: Draw path for snake to reach treat. Improves Energy. (Flutter: simple path drawing + AI follow; later Unity navmesh).
  - These replace button presses; actions feed the care loop, RAG, and growth milestones.

### Rethinking the "Evolution" Flow (Discovery Path)
- **Milestone Unlocks with Agency**: Not auto/linear (Cow→Snake→Whale). Hit interaction milestone (e.g., grooming-focused) → award "Evolution Key".
  - Choice UI: Pick next environment/species to unlock (gives player agency).
  - Persistent Personality: RAG memories influence "DNA" (e.g., past "stressed" memories bias future mood/animations even after evolution).
- Overlay "thought" as floating bubble in 3D (not buried in journal). Keep full RAG.

### Interactive Mini-Games (Integrated into the Habitat)
- As above: Target Catch, Weed Pull, Maze Chase - direct in 3D scene (gestures on Unity view or Flutter overlay during transition).
- Rewards feed stats + gift system.

### New Interactive Features
- **Floating Thought Bubbles**: LLM/RAG "pet thoughts" appear as subtle 3D floating bubbles over the pet (tap to "hear" full response or update memory). Immediate and visual (no separate page).
- **Real-time Environmental Events** (device clock + API):
  - Nighttime: Environment dims, fireflies (cow) or bioluminescent lights (whale).
  - Weather: If raining in real location (geolocator + weather API), rain in 3D pasture/pond.
- **"Gift" System**: Mini-games award "found" items (shells for whale, flowers for cow). User "gives" them to pet to decorate 3D habitat (visual changes: shells on pond floor, flowers in pasture). Persistent via inventory in PetState + Unity prefab swaps or particle effects.

### The "Active" Care Loop + Growth
- Growth still milestone + care-quality (heavy on grooming) + min 35 real days.
- All interactions (games, gifts, mic) directly update stats/mood/RAG without menu bloat.
- Environment swaps on evolution/species for "rearing" feel.

## Database & Architecture (Portable to Unity)
**Current MVP (Flutter, successful phone build)**: Local JSON + all new features (mini-games, gifts, events, floating thoughts, gesture interactions).

**Unity Hybrid**:
- Flutter shell: Menus, Supabase (auth/RBAC/shared_state for multiplayer), RAG persistence, LLM thoughts (generate in Flutter, send to Unity for bubble display).
- Unity: 3D pet/habitat with Blend Trees, prefabs, raycast games, gifts as 3D objects.
- Bridge: flutter_unity_widget for embedding + message passing (stats ↔ animations, gifts ↔ decorations).
- Data model (PetState) extended for: unlockedEnvironments, giftsInventory, currentEnvironmentId, lastWeather.

See new UNITY_SETUP.md for Unity-side (Blender morphs, blend trees, prefabs, message protocol).

**Multiplayer (Future)**: Shared state in Supabase; Unity scenes sync via Flutter bridge.

## Current Implementation Status & Migration Path
- All prior logic (growth on grooming, RAG thoughts, haptics, emotional UI, micro-anims, etc.) preserved and enhanced.
- **Flutter Prototypes**: Mini-games, floating bubbles, environmental events, gifts implemented as overlays/gestures on current habitat view (ready to swap for Unity).
- **To Pivot**:
  1. Set up Unity project (export Android/iOS libs).
  2. Add `flutter_unity_widget` + embed UnityView (replace/enhance PetVisual).
  3. Port environments to prefabs, animations to Blend Trees driven by Flutter stats.
  4. Move mini-games to Unity (raycast/gestures).
  5. Overlay floating thoughts + gifts as Unity objects.
  6. CI: Build Unity export + Flutter (complex; may need separate Unity Cloud Build).

Current code is the validated "soul" (RAG, care loop, personality). Unity adds the "body" (3D fidelity).

Enjoy the phone-tested prototype - now let's make the 3D leap! 

For your girlfriend: Current APK has the enhanced clay pet with all core features. Unity version will be next APK after migration.

## Visual & Graphics Strategy (Implemented + Future)

**Current (Flutter APK - what builds today via GitHub Actions):**
- **Claymation / Soft 3D aesthetic** implemented procedurally with `CustomPainter`.
- No asset placeholders: fully code-driven "toon" look with soft layered shadows, rounded forms, pastel clay colors per species.
- **Growth "Morph" approximation**: `growthProgress` (0.0 baby → 1.0 adult) lerps body proportions, feature sizes, and posture (baby = rounder/squishier head, adult = more elongated/proportional). This gives smooth visual change without pop-in.
- **Mood & State reactive**: Happiness changes bob intensity + smile strength. Low hygiene adds "mess" overlay. Sleeping closes eyes.
- **Interactive Grooming Scene**: Tap head or body zones on the pet (simulates raycast hit on mesh). Triggers `groom` action → hygiene/happiness boost + memory + particle "brushed" effect.
- **Dynamic Living Space**: Simple time-of-day background (pond blues for whale day/night, pasture greens for cow, etc.). Real `DateTime` driven.
- Species have distinct shapes + details (whale tail/spout, cow ears/spots, snake patterns).

**Recommended Full Implementation (Blender + Unity / Advanced Flutter):**
- Use **Blender** to create base model + **Blend Shapes / Morph Targets** for Baby → Juvenile → Adult stages.
- Export glTF or FBX with morph targets.
- In engine: drive a single `growthPercentage` (0.0-1.0) float into the material/shader. The mesh smoothly blends (no separate models or pop).
- **Art Style**: Claymation/Soft 3D + Toon Shader (warm, hand-crafted, emotionally resonant).
- **Grooming Scene**: Dedicated 3D room. Raycast from touch → brush strokes on mesh vertices. Add particle systems (clay dust, hearts).
- **Living Space**: Fully dynamic environment. Pond (whale) or pasture (cow) that changes lighting/weather based on real-world time + pet mood. Time-of-day + seasonal elements.
- **Why Unity shines here**: Native blend shapes, excellent 3D tooling, Timeline for idle/mood animations, easy raycasting/physics. The original architecture plan noted Unity's strength for rich 2D/3D animation vs Flutter's UI focus.

Current Flutter version is a high-fidelity 2D approximation that captures the *feeling* and all the logic (growth progress, milestones, grooming). It runs beautifully as a mobile APK today.

## Core Feature Specifications

### The Care Loop (Retention Heart)
- **Decay**: Real-time + offline via `TimeSimulator` + `decayRates` per species. Long absence generates narrative "away" memories.
- **Hygiene/Hunger**: Direct stat impact. Low values visibly degrade the pet (mess overlay, mood shift).
- **Growth Trigger (per spec)**: Primarily **Interaction Milestones** (cumulative successful actions: feed/play/groom/etc.). Not pure time. `interactionCount` drives `growthProgress` (smooth 0-1) and `growthStage` (0/1/2).
  - Baby (0-49 interactions) → Juvenile (50-149) → Adult (150+).
  - `growthProgress` is the blend/morph driver.
- **Mood**: Derived from stats. Affects visuals (bob, expression, color temperature) and future idle animations.

### Multiplayer / Shared Space (Future)
- **Shared State**: `shared_state` JSONB column + `last_interaction` timestamp for optimistic concurrency.
- **Conflict Resolution**: Last-write-wins on timestamp. Clients subscribe to realtime updates (Supabase Realtime or Firebase).
- **RBAC**:
  - `Owner`: Full control (rename, evolution decisions, reset).
  - `Guest`: Read + limited daily interactions (e.g. one groom/feed per day).
- Implementation: Supabase Auth + `profiles` table + RLS policies (see `supabase/schema.sql`).
- Current MVP: Single local owner (you + gf can both use the same device or take turns with the APK).

### AI Personality / "Brain" (RAG + Thoughts)
- **RAG Memory**: `MemoryEntry` with text + fake (or real) embeddings + importance + recency. Hybrid retrieval for context.
- **Pet Thoughts**: On app open, a prominent thought bubble generated from `LLMChatService.generateCurrentThought(pet)`.
  - Context: current stats, growthProgress, time of day, recent memory, species personality.
- **Full Chat**: In Talk tab. Uses retrieved memories + personality prompt.
- **Future Real LLM**: The service builds clean prompts. Swap the mock generator for an Edge Function / direct call to Grok/OpenAI/Gemini. Pass the same rich context + retrieved memories.
- Example thought (from code): "The water is calm in this beautiful day, but it would be nicer with you here."

## Database & Architecture

**Current (MVP - GitHub APK builds this today)**:
- Local JSON via `path_provider` + `PetState` (matches the spec JSON shape).
- `toJson`/`fromJson` produce the exact structure in the user query.
- Fully offline, private, works on any Android phone after sideloading.

**Production (Supabase - see supabase/schema.sql)**:
- `pets` table with JSONB `stats` (hunger, hygiene, growth_stage, growth_progress).
- `pet_memories` with vector(768) for pgvector RAG.
- `profiles` for roles.
- RLS + optimistic concurrency via `last_interaction`.
- Realtime subscriptions for shared space across phones.

**Growth + Milestones**: Can live in app (current) or be moved to Postgres functions for server-authoritative multiplayer.

## Current Implementation Status (Flutter)

All core logic and the "best graphics" request have been implemented in pure Flutter (no extra assets required for the APK build).

- PetState / Simulator / Controller fully updated for growth milestones + progress.
- `PetVisual`: High-quality procedural claymation painter (no emoji placeholders).
- Grooming interaction + dynamic living space + live pet thoughts.
- RAG memory + LLM thoughts preserved and enhanced.
- GitHub Actions workflow builds a clean release APK.

**To get the APK for your girlfriend**:
1. Zip the `C:\Users\nisar\virtual-pet-app` folder (it now contains `.github/workflows/build-apk.yml` + all improvements).
2. Upload to a new public GitHub repo.
3. Go to Actions → download the artifact (no local Flutter/Android Studio needed).

The app will have smooth growth visuals (morph-like), meaningful grooming, time-aware backgrounds, and a pet that *remembers* via thoughts and chat.

For the true 3D Blender + morph targets + Unity version described in the spec, treat the current code as the validated logic + UI prototype. The data model and services are designed to be portable.

Enjoy surprising her — the pet will have real personality and memories from day one.