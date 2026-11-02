# Lumina Vale — Plan: from Flutter prototype to a real 3D game

Target: a **2.5D** creature-raising RPG on Android in the style of Pokémon X/Y.

"2.5D" here means what X/Y actually does: **real 3D models and 3D environments, seen
through a fixed, tilted camera, in a world laid out on a tile grid.** You get 3D depth,
lighting and animation, but it plays like a classic top-down RPG: no free camera
rotation, readable grid-aligned towns and routes, and movement constrained to the map.
(This is different from "HD-2D", which uses 2D sprites in a 3D world. X/Y doesn't use
sprites. If you'd rather have sprites, see the note at the end of §3.)
Look: chibi cel-shaded creatures, diorama-like towns, soft lighting.
The look is the reference. Creatures, names, UI, music and story stay **original**:
Pipkin / Marrow / Solbit, Bloom / Tide / Ember, the Glen. Copy nothing from Pokémon's
designs, UI layouts or audio.

Supersedes the engine sections of `ARCHITECTURE.md` and `UNITY_SETUP.md`.

---

## 1. Where the project is today (honest diagnosis)

| Area | What exists | Why it doesn't feel like a game |
|---|---|---|
| Rendering | `lib/vale/stage3d.dart` + `lib/world/overworld_renderer.dart` draw the world with Flutter `Canvas` (`drawOval`, `drawPath`) and a fake tilt: `sy = y*0.78 - z` | No real 3D: no depth buffer, lighting, shading, shadows or perspective. Every creature is a stack of ovals. **This is the main reason it failed.** Flutter's Canvas can't do X/Y-quality 3D, whatever the art. |
| 3D assets | `sproutkit.glb`, `aquapup.glb`, `embercub.glb` (rigged, 7 clips each: Idle, Happy_Hop, Eat, Pet_Enjoy, Refuse, Sleep, Walk), `glen_stage.glb` | **Never rendered.** `kinGlb()` / `clipForPose()` are only used in a test, and `pubspec.yaml` doesn't bundle `assets/models/`. The models come from `tools/build_3d_assets.py`, which puts them together from ico-spheres and cones, so even when rendered they're placeholder blobs without textures or faces. |
| Flow | 15 full screens swapped by `AnimatedSwitcher` (`vale_app.dart`) | Feels like an app with menus. A game has one world you move through, with transitions and cutscenes. |
| Control | The joystick moves the pet directly | There's no avatar for the player (keeper). The pet's own AI (`SpatialMind`) has to fight your joystick. |
| Game logic | `models.dart`, `care_sim.dart`, `learning.dart` (BondMind Q-learning, RoutineModel, SequenceEar, MoveMind), `ml/spatial_mind.dart`, `controller.dart` (~3,600 lines) | **This is good** and is the differentiator: a creature that learns your routine. Keep it and port it. |
| Dead code | `lib/features/**` (the old whale/cow/snake app) isn't imported anywhere. `cow_idle.glb` (8 MB), `snake_titanoboa…glb` (7 MB), `low_poly…whale.glb` and `animated_lowpoly_cow…glb` are third-party with unknown licenses | Confusing, and a licensing risk if shipped. |
| Secrets | `.env` holds the OpenRouter key and was staged for commit. `.gitignore` had no `.env` rule. The key is also compiled into the APK through `String.fromEnvironment` | Anyone who has the APK can extract the key. It needs a server-side proxy. |
| Audio | `tone.dart` synthesizes beeps | No music or real SFX: about half of "game feel" is missing. |

---

## 2. Engine decision

**Recommendation: Unity 6 LTS + URP (Universal Render Pipeline), as a standalone native game.
Retire Flutter. Do not embed Unity inside Flutter.**

Why:
- X/Y's look needs real-time 3D: toon shaders, outlines, skinned animation, blend shapes,
  baked lighting and post-processing. URP does all of this well on mobile.
- Embedding with `flutter_unity_widget` (the old `UNITY_SETUP.md` plan) gives you two
  build systems, a message bridge, and a plugin that lags behind Unity releases. For a
  solo dev that's double the cost for no player-visible gain. Everything the Flutter shell
  provided (menus, save, chat UI) is easy to build in Unity.
- Mature tooling for this genre: Animator blend trees, Cinemachine, Timeline (for
  evolution cutscenes), NavMesh (pet roaming), glTFast (loads your existing `.glb` files
  right away as placeholders), and GameCI for GitHub Actions builds.
- Your Dart logic is plain, engine-free code. It ports almost line-for-line to C#.

(If you'd rather have fully free/open-source tooling and a lighter editor, Godot 4 is the
alternative and this plan maps onto it almost 1:1. Unity is recommended for its larger
learning ecosystem and asset store.)

The Flutter app gets archived on a `flutter-prototype` branch as the reference for the port.

---

## 3. Visual target: style spec

Every asset and shader gets checked against this.

**Camera: the core of the 2.5D feel**
- **Fixed angle and the player can't rotate it.** Yaw is locked to the grid (world "north"
  is always up the screen).
- Perspective with a **narrow FOV (22–30°)** from further away (about 14–18 m) and a pitch
  of 50–55°. The narrow lens flattens the view so it reads almost like a 2D map, while
  buildings and creatures keep their 3D volume and parallax. (Orthographic is an option for
  an even flatter look, but it loses the subtle depth that makes X/Y feel 3D.)
- Cinemachine follow camera that tracks on X/Z only, with soft damping and dead zones.
  Per-area **camera zones** change the framing (tighter and lower inside houses, wider in
  open routes, a fixed shot in small rooms). Only the framing changes, never the
  player-facing rotation.
- Battle is the one place the camera goes fully 3D: separate virtual cameras with cuts
  (intro sweep, attacker over-shoulder, hit close-up).

**Movement and the world grid (2.5D rules)**
- The world is built on a **1 m tile grid**: paths, buildings, fences, ledges, tall grass
  and water edges all snap to it. Use Unity `Grid` + Tilemap Extras **GameObject Brush** to
  paint 3D kit prefabs like tiles.
- The Keeper moves with **8-direction analog** control (like X/Y's circle pad), with
  collision against grid-aligned colliders. An optional **4-direction tile-step** mode
  gives the classic feel.
- Grid features: one-way **ledges** (hop down), tall-grass patches (encounters or forage
  spots), interact-facing (an A button on the tile you face), and doors as warp tiles
  with a fade.
- The kin follows a few tiles behind you, or roams on its own (NavMesh baked on the
  same grid).

**Creatures**
- Chibi proportions: head about the size of the body, big readable silhouette, short limbs.
- 3–6k triangles each, one 1024² hand-painted texture (512² for NPCs).
- Faces: eyes and mouth on a separate material using UV-offset expression sheets (blink,
  happy, sad, angry, sleepy), driven from the Animator. This is the trick that makes
  creatures feel alive. Blend shapes are fine too.
- 3 stages per species (baby, juvenile, adult) as separate meshes sharing a similar rig.

**Shading (custom URP shader; Claude can write it)**
- 2–3 step toon ramp on the main light, plus a soft rim light.
- Inverted-hull outlines, about 1.5–2 px at gameplay distance. Width scales with camera
  distance and can be tinted per material (darker shade of the base color, not pure black).
- Shadows from a single realtime directional light on characters. The environment uses
  baked lightmaps and vertex-color AO.

**World**
- Modular kit on a 1 m grid: grass and path tiles with painted blends, cliff edges and
  corners, fences, bridges, water edges, 3 house types, trees (painted trunk + alpha-cutout
  foliage cards), bushes, flowers, rocks, signs.
- Stylized water shader: depth color gradient, foam at intersections, scrolling normals.
- Day phases (`DayPhase` already exists): one lighting preset per phase (sun color and
  angle, ambient, fog, LUT), blended over time.
- Weather (`SkyMood` already exists): petals, rain and fireflies as Particle Systems.

**Post-processing:** light bloom, a color-grading LUT per day phase, slight vignette, and
optional tilt-shift depth of field in towns. Keep the post stack small for mobile.

**Performance budget (mid-range Android):** 60 fps, under 150 batches on screen, under
150k triangles on screen, SRP Batcher and GPU instancing on, ASTC textures. The fixed
camera helps a lot here: you always know exactly what's on screen, so off-screen detail
can be culled hard.

> **Sprite alternative ("HD-2D").** If you'd rather draw 2D pixel or painted sprites than
> model creatures, the same Unity setup works: billboarded sprite characters on the same 3D
> tile world with the same fixed camera. It's cheaper on creature art (no rigging), but it
> looks less like X/Y. Decide this before Phase 2, because it changes the whole art pipeline.

---

## 4. Game design reframe: same soul, game-shaped

| Today (Flutter screen) | In the game |
|---|---|
| Joystick drives the pet | **You play the Keeper** (a small chibi avatar). The kin walks the world on its own, driven by `SpatialMind` goals through NavMesh: it follows you, forages, naps at the house, visits friends. The learning AI becomes something you can watch happen. |
| `DenScreen` + `GlenStage` | The **Glen**: one hand-built 3D area with the Homestead, Tool Shed, Care Pavilion, berry trees, rune stones, a pond, and the NPCs Sprout, Aqua, Lina and Bram. |
| Feed / Groom / Rest screens | **In-world interactions**: walk to the bowl at the Pavilion → feeding camera; tap-and-drag to brush with a raycast on the real mesh (dust particles, a happy face, haptics); sleep at the house → fade, time passes. |
| `SparScreen` (turn-based with `MoveMind`) | **Battle scene**: a ring arena, camera cuts, move VFX per element, damage numbers, stamina bars, and the AI's move suggestion shown as the kin's "eagerness". |
| Pattern / Ribbons / Outing | Mini-games run inside the world (the glyph duet at the rune stones, the ribbon chase in the meadow). Outings get a Timeline cutscene. |
| `EvolveScreen` rite | A **Timeline cutscene**: the kin glows, a light-pillar VFX plays, the mesh swaps behind the bloom, then a reveal pose. |
| Mind / Journal screens | A pause-menu "Journal" book UI with the learned routine heatmap, memories and bond stats. |
| OpenRouter chat | Speech bubbles over the kin. Requests go through a small serverless proxy (for example a Supabase Edge Function or Cloudflare Worker), so the API key never ships in the app. |

**Vertical slice first:** one species (Pipkin) with all 3 stages, the Glen, care
interactions, one mini-game, sparring, and evolution. Nothing new gets added until that
slice looks and feels finished.

---

## 5. Phased plan

### Phase 0: Cleanup and setup (≈1 week)
- [x] Unstage `.env` and add `.env` to `.gitignore`.
- [ ] **Rotate the OpenRouter key** (it may already be in an APK build).
- [ ] Create the `flutter-prototype` branch to archive the current app.
- [ ] Delete `lib/features/**` and the four third-party GLBs (or record their licenses,
      for example Sketchfab CC-BY with attribution).
- [ ] Install: Unity Hub → Unity 6 LTS with **Android Build Support** (OpenJDK + SDK/NDK);
      Blender 4.5 LTS or newer; Git LFS.
- [ ] Create the Unity project (URP Mobile template) in `game/` (or a fresh repo), with
      Unity's `.gitignore` and `.gitattributes` for LFS (`*.fbx *.blend *.png *.psd *.wav *.ogg`).
- [ ] Add packages: Cinemachine, Input System, glTFast, Timeline, AI Navigation, TextMeshPro.

### Phase 1: Art pipeline and look test (≈2 weeks)
- [ ] Mood board plus 3 "style tiles" (a creature, a house, a patch of ground) to lock the
      palette and painting style.
- [ ] Toon + outline shader for URP, water shader, foliage shader (wind sway via vertex color).
- [ ] Blender → Unity export conventions: FBX, scale 1.0, apply transforms, −Z forward,
      Y up; names like `SK_Pipkin_Stage0`, `A_Pipkin_Walk`, `T_Pipkin_D`, `M_Toon_Pipkin`.
- [ ] Blender Python batch-export script (Claude can write this) that exports every
      collection to `game/Assets/_Game/Art/...` with the right settings.
- [ ] **Look test scene**: grey-box Glen + the existing `sproutkit.glb` (through glTFast)
      with the toon shader, the real camera and post-processing. If it doesn't look like the
      target here, fix it before making more art.

### Phase 2: Creature art (≈1–2 weeks per creature stage; the biggest effort)
For each species × 3 stages (9 models; start with Pipkin only):
- [ ] Concept: front/side turnaround plus an expression sheet.
- [ ] Model: low-poly box modelling (or sculpt → retopo) at 3–6k triangles.
- [ ] UV → hand-paint in Blender Texture Paint, ArmorPaint or Substance Painter.
- [ ] Rig (Rigify or a simple custom rig with tail and ear bones) + face material
      with an expression UV sheet.
- [ ] Animations: `Idle, Walk, Run, Happy_Hop, Eat, Pet_Enjoy, Refuse, Sleep, Attack_Physical,
      Attack_Special, Guard, Hit, Faint, Evolve_Pose`. Keep the existing clip names so
      `clipForPose()` still maps.
- [ ] Keeper avatar and 4 NPCs: one shared humanoid rig, with variation through outfits and
      textures.

Hand-modelling and painting need a human: you, or a commissioned artist (fastest path to
real quality). AI mesh generators (Meshy, Tripo, etc.) can give a starting base, but those
meshes still need retopology, clean UVs and a rig. `tools/build_3d_assets.py` stays only as
a placeholder generator.

### Phase 3: World building (≈2–3 weeks)
- [ ] Modular environment kit in Blender (list in §3), exported as prefabs.
- [ ] Build the Glen in Unity: snap kit pieces to the grid, use Polybrush for vertex-color
      blends, place props.
- [ ] Bake lightmaps and set up light probes for characters.
- [ ] Day-phase lighting presets + blender script; weather particles; ambient life
      (butterflies, fish in the pond, smoke from the chimney).
- [ ] Interiors (`lib/world/interiors.dart`): Homestead and Shed as separate small scenes
      with a door fade transition.

### Phase 4: Code port to C# (≈3 weeks; runs alongside Phases 2–3)
```
game/Assets/_Game/Scripts/
  Core/       GameState, SaveSystem (JSON, same shape as ValeSave), TimeService, EventBus
  Data/       SpeciesDef, MoveDef, FoodDef as ScriptableObjects (from SpeciesCatalog)
  Kin/        Kin, CareSim (offline decay, care outcomes), MoodResolver
  AI/         BondMind, RoutineModel, SequenceEar, MoveMind, SpatialMind, WorldLedger, DreamTrace
  World/      KeeperController, KinAgent (NavMesh + SpatialMind goals), Interactable,
              NpcController, Pickup, DoorTransition, DayNightDirector, WeatherDirector
  Battle/     BattleStateMachine, TypeChart, BattleCameraDirector, MoveVfx
  Minigames/  BrushGame, GlyphDuet, RibbonChase
  UI/         HUD, JournalBook, DialogueBox, SpeechBubble (UI Toolkit or uGUI)
  Net/        ChatProxyClient (talks to the serverless proxy, never to OpenRouter directly)
```
| Dart source | C# target |
|---|---|
| `vale/models.dart` | `Data/*` ScriptableObjects + `Kin/Kin.cs` |
| `vale/care_sim.dart` | `Kin/CareSim.cs` (pure static, unit-tested) |
| `vale/learning.dart` | `AI/BondMind.cs`, `RoutineModel.cs`, `SequenceEar.cs`, `MoveMind.cs` |
| `ml/spatial_mind.dart` | `AI/SpatialMind.cs`, `WorldLedger.cs`, `DreamTrace.cs` |
| `vale/controller.dart` | split into `GameState` + the World/Battle/Minigame systems |
| `vale/save_store.dart` | `Core/SaveSystem.cs` (`Application.persistentDataPath`) |
| `test/unit/*` | Unity Test Framework EditMode tests (same expectations) |

Keeping the JSON save shape lets an optional importer bring an existing Flutter save
across, so your current kin survives the move.

### Phase 5: Game feel (≈2 weeks, then ongoing)
- [ ] Animator: locomotion blend tree driven by speed, a face layer, and an additive
      "breathing" layer. Mood (from `Kin.moodAt`) sets the idle variant and the face.
- [ ] Juice: squash and stretch on hops, footstep dust, heart and sparkle particles,
      screen shake on hits, UI tweens (DOTween), haptics.
- [ ] Audio: one music loop per day phase plus battle and evolution themes (commissioned or
      licensed royalty-free), SFX for steps, eating, brushing, UI and moves, and a
      creature "voice" made of pitched chirps per species. Unity Audio Mixer with ducking.
- [ ] Dialogue boxes with typewriter text and portrait expressions.

### Phase 6: Battle and evolution polish (≈2 weeks)
- [ ] Arena scene, intro camera sweep, move VFX per element (Bloom: leaves and petals;
      Tide: water splash; Ember: sparks), hit flash and knockback, faint animation.
- [ ] Evolution Timeline cutscene with a mesh swap under the bloom flash.

### Phase 7: Build, CI and release (≈1 week)
- [ ] GameCI on GitHub Actions (`game-ci/unity-builder`) → Android AAB/APK artifact.
      Needs `UNITY_LICENSE`, `UNITY_EMAIL` and `UNITY_PASSWORD` repo secrets (a free
      Personal license works). This replaces `.github/workflows/build-apk.yml`.
- [ ] Addressables for creature and area content; ASTC texture compression; IL2CPP ARM64.
- [ ] Device profiling on a real phone (Unity Profiler + Frame Debugger) against the §3 budget.

**Rough total for one person:** about 3–4 months to a polished vertical slice. Creature
art is the critical path. Commissioning the 3 Pipkin stages could take about 6 weeks off.

---

## 6. Who does what

| Claude can write | Needs you or an artist |
|---|---|
| All C# (logic port, controllers, AI, battle, UI, save, tests) | Concept art and taste calls on the style tiles |
| Toon/outline/water/foliage shaders, post settings, lighting presets | Sculpting, modelling, UV and hand-painting creatures |
| Blender Python: batch export, kit-piece generators, naming/validation, placeholder meshes | Keyframe animation (the nuance of the acting) |
| Unity editor tools (grid snapping, prefab validators, scene builders) | Music (commission or license) |
| GameCI workflow, serverless chat proxy, Addressables setup | Unity license activation, device testing |

---

## 7. First milestone ("it's a game now")

> Walk the Keeper around a grey-box, grid-built Glen under the fixed 2.5D camera, in cel-shaded 3D on an Android phone, with
> placeholder Pipkin (the existing `sproutkit.glb`) roaming on its own using the ported
> `SpatialMind`, a follow camera, the day/night cycle, and feeding at the Pavilion.

Concrete steps: Phase 0 → Unity project → glTFast import of the existing GLBs → toon
shader → KeeperController + Cinemachine → port `models`/`care_sim`/`spatial_mind` →
KinAgent on NavMesh → GameCI APK.
