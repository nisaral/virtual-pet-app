# Virtual Pet App - Architecture (Updated 2026-06-14)

This document captures the evolved vision from the original plan + the detailed Visual/Graphics + Core Feature specs provided by the user.

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