# virtual-pet-app

Cross-platform virtual pet app (Whale / Cow / Snake) built following the approved Lead Architect plan (2026-06-14).

## Features implemented (MVP matching the architectural plan)

- **Three distinct pets**: Whale, Cow, Snake with different decay rates, personality prompts, and preferred actions (data-driven via `PetTypeConfig`).
- **Persistent state**: Full `PetState` (stats, progression, inventory, customizations) + list of `MemoryEntry` saved locally via JSON file (path_provider). Survives restarts.
- **Offline time simulation**: On launch/resume, real elapsed time since `lastUpdated` is applied using `TimeSimulator.applyOfflineDecay`. Generates narrative "while you were away" memories for significant changes.
- **Core care loop**: Feed, Play, Clean, Pet, Talk. Stats update with deltas, mood computed, XP/level/evolution (demo). Memories auto-created on every action.
- **RAG memory system** (the key differentiator):
  - `MemoryEntry` with timestamp, eventType, natural language `text`, importance, and **fake embedding** (stable, hash-based 64-dim for demo).
  - `MemoryRAGService`: hybrid retrieval (cosine similarity on embeddings + importance + recency boost).
  - Used both in the Journal view and (most visibly) the Talk/Chat screen.
- **"Smart" chat**: `LLMChatService` builds a rich prompt (personality + current stats + retrieved memories) and produces cute in-character replies **completely locally and offline** (no API keys). Memories are recalled and shown in the UI ("🧠 Recalled:...").
- **Reactive UI** with Riverpod: live stats bars, reactive pet visual (color + scale + emoji overlays), bottom nav (Pet / Talk / Memories).
- **Dev helpers**: "Simulate time away" button + adopt/switch pet menu (in AppBar on Pet tab).

## Project Structure (as proposed)

See the approved plan for full details. Core pieces live under:
- `lib/core/` — constants, time + vector utils
- `lib/features/pet/domain/models/` — PetState, Stats, MemoryEntry, PetType + Config (pure)
- `lib/features/pet/application/` — PetSimulator, MemoryRAGService, LLMChatService, PetController (Riverpod)
- `lib/features/pet/data/` — Local JSON datasource + RepositoryImpl (swappable for ObjectBox)
- `lib/features/.../presentation/` — pages + widgets (PetVisual, StatBars, etc.)

## Getting Started (Run Immediately)

1. Make sure you have Flutter SDK installed and on your PATH.
2. In this directory:
   ```bash
   flutter pub get
   flutter run   # or flutter run -d chrome / -d windows etc.
   ```
3. On first launch you adopt "Bubbles" the whale. Interact using the action buttons.
4. Close the app for a while (or use the bug icon to simulate 18 hours away), relaunch — watch the offline decay + new memories appear.
5. Go to the **Talk** tab, ask questions like "Are you hungry?", "What did we do yesterday?", "Do you remember playing?". The pet will reply using retrieved memories.

## Next Steps (per the approved plan phases)

- Add real **Rive** assets (`.riv` files with state machines bound to stats/mood) under `assets/rive/`. Update `PetVisual` and pubspec.
- Upgrade persistence to **ObjectBox** (add the packages, annotate entities, run `flutter pub run build_runner build`, implement vector index on embeddings). The repository abstraction makes this low-risk.
- Real on-device embeddings + LLM via `flutter_gemma` (or current 2026 equivalent). Keep the mock as fallback / lite mode.
- Expand progression, inventory items per pet type, notifications, more evolution stages.
- Cloud sync option (Supabase/Firebase) as Phase 2.
- Tests (see `test/` — skeleton ready).

## Testing the Architecture (Verification per plan)

- **Core loop + memory creation**: Perform actions → stats change, new MemoryEntry appears in journal.
- **Offline progression**: Use dev "simulate time away" or actually background the app for 30+ minutes. Relaunch and observe decay + "away" memories.
- **RAG recall**: After several different interactions, open Talk and reference past events. Check that retrieved memories appear in the UI and influence replies. Different pet types should feel distinct.
- **Persistence**: Kill the app / reboot device → everything (including memories) is still there.
- Run `flutter test` once you add real test cases (unit tests for `PetSimulator` and `MemoryRAGService` are high value).

## Notes from Architect

- The data model and services are intentionally engine- and DB-agnostic so future Unity port or ObjectBox migration is feasible.
- All RAG/LLM work is 100% on-device and private in this implementation.
- See the full plan file in your Grok session for deeper rationale, trade-offs (Flutter vs Unity), schema details, and phased rollout.

Enjoy raising your virtual pets — and make sure they remember you!
