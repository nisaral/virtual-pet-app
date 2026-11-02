using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuminaVale
{
    /// Boots the whole game from one empty scene and runs the overworld loop:
    /// what the A button means right now, menus, and handing off to activities.
    public sealed partial class Director : MonoBehaviour
    {
        GameManager gm;
        GameUI ui;
        GridCamera cam;
        GlenWorld world;
        KeeperController keeper;
        KinAgent kin;
        DayNightDirector dayNight;
        WeatherDirector weather;
        SparBattle battle;
        BrushGame brush;
        GlyphDuet duet;
        GleamHunt hunt;
        readonly List<Wanderer> folk = new();
        readonly List<Transform> friendKin = new();
        bool inScene;           // an activity or cutscene owns the screen
        bool started;
        bool evolvePending;
        InteriorRoom indoor;
        Building indoorBuilding;
        Vector2Int outdoorCell;
        Bounds outdoorCam;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void AutoBoot()
        {
            if (FindFirstObjectByType<Director>()) return;
            new GameObject("Director").AddComponent<Director>();
        }

        void Start()
        {
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.SystemSetting;
            gm = new GameObject("GameManager").AddComponent<GameManager>();
            new GameObject("Audio").AddComponent<ProcAudio>();

            BuildCameraAndLight(out var sun);
            world = GlenBuilder.Build();
            cam.Clamp = world.Bounds;

            weather = new GameObject("Weather").AddComponent<WeatherDirector>();
            weather.Chimney = world.ChimneyTop;
            dayNight = new GameObject("DayNight").AddComponent<DayNightDirector>();
            dayNight.Sun = sun;
            dayNight.World = world;
            dayNight.Cam = cam.Cam;
            dayNight.Volume = DayNightDirector.CreateVolume();
            dayNight.Weather = weather;

            ui = new GameObject("UI").AddComponent<GameUI>();
            ui.Init(cam.Cam);

            BuildKeeper();
            BuildFolk();

            var acts = new GameObject("Activities");
            battle = acts.AddComponent<SparBattle>();
            battle.UI = ui; battle.Camera = cam;
            brush = acts.AddComponent<BrushGame>(); brush.enabled = false;
            duet = acts.AddComponent<GlyphDuet>(); duet.enabled = false;
            hunt = acts.AddComponent<GleamHunt>(); hunt.enabled = false;

            gm.Toast += ui.Toast;
            gm.KinChanged += () => ui.Refresh(gm.Save, dayNight.Phase);
            gm.EvolveReady += () => evolvePending = true;
            gm.BidRaised += bid => { if (kin) { kin.Visual.Hop(0.25f); ProcAudio.I?.Chirp(gm.Kin.Species); } };
            dayNight.PhaseChanged += p => ProcAudio.I?.Music(p.ToString().ToLowerInvariant());

            weather.Follow = keeper.transform;
            cam.Target = keeper.transform;
            cam.Snap();
            ProcAudio.I.Music(Catalog.PhaseAt(DateTime.Now).ToString().ToLowerInvariant());
            ShowTitle();
        }

        void BuildCameraAndLight(out Light sun)
        {
            var camGo = new GameObject("MainCamera") { tag = "MainCamera" };
            var c = camGo.AddComponent<Camera>();
            c.clearFlags = CameraClearFlags.SolidColor;
            c.nearClipPlane = 0.3f;
            c.farClipPlane = 56f;
            var data = camGo.AddComponent<UniversalAdditionalCameraData>();
            data.renderPostProcessing = true;
            data.antialiasing = AntialiasingMode.FastApproximateAntialiasing;
            camGo.AddComponent<AudioListener>();
            cam = camGo.AddComponent<GridCamera>();

            var sunGo = new GameObject("Sun");
            sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.55f;
            sun.shadowBias = 0.04f;
            sun.shadowNormalBias = 0.3f;
            RenderSettings.sun = sun;
        }

        void BuildKeeper()
        {
            var go = new GameObject("Keeper");
            keeper = go.AddComponent<KeeperController>();
            keeper.Body = ChibiCharacter.Create(go.transform, "keeper", new Color(0.95f, 0.42f, 0.38f), new Color(0.32f, 0.22f, 0.18f), new Color(1f, 0.86f, 0.74f), true, new Color(0.96f, 0.96f, 0.96f));
            keeper.Place(GlenMap.SpotById("keeperStart").Cell);
            keeper.transform.rotation = Quaternion.LookRotation(Vector3.back);
        }

        void BuildKin()
        {
            if (kin) Destroy(kin.gameObject);
            var go = new GameObject("Kin");
            kin = go.AddComponent<KinAgent>();
            kin.Keeper = keeper;
            kin.World = world;
            kin.Friends = () => friendKin;
            kin.Rebuild();
            kin.Place(GlenMap.NearestWalkable(keeper.Cell + Vector2Int.right));
            brush.UI = ui; brush.Cam = cam; brush.Kin = kin;
            duet.UI = ui; duet.Cam = cam; duet.World = world; duet.Kin = kin;
            hunt.UI = ui; hunt.Keeper = keeper; hunt.Kin = kin;
            SpawnCaughtKin();
            BuildDigSites();
        }

        void BuildFolk()
        {
            Wanderer Human(string id, string name, Vector2Int home, Color shirt, Color hair, bool hat, string[] lines)
            {
                var go = new GameObject(name);
                go.layer = 8;
                var w = go.AddComponent<Wanderer>();
                home = GlenMap.NearestWalkable(home);
                w.Id = id; w.DisplayName = name; w.Home = home; w.Lines = lines; w.Range = 2;
                w.Human = ChibiCharacter.Create(go.transform, "npc_" + id, shirt, hair, new Color(1f, 0.84f, 0.72f), hat, shirt * 0.8f);
                var col = go.AddComponent<CapsuleCollider>();
                col.center = Vector3.up * 0.6f; col.height = 1.2f; col.radius = 0.25f;
                go.transform.position = GlenMap.ToWorld(home);
                folk.Add(w);
                return w;
            }
            Wanderer Friend(string id, string name, SpeciesId species, Vector2Int home, string[] lines)
            {
                var go = new GameObject(name);
                go.layer = 8;
                var w = go.AddComponent<Wanderer>();
                home = GlenMap.NearestWalkable(home);
                w.Id = id; w.DisplayName = name; w.Home = home; w.Lines = lines; w.Range = 3;
                w.Creature = CreatureVisual.Create(go.transform, species, 0);
                var col = go.AddComponent<SphereCollider>();
                col.center = Vector3.up * 0.35f; col.radius = 0.3f;
                go.transform.position = GlenMap.ToWorld(home);
                folk.Add(w);
                friendKin.Add(go.transform);
                return w;
            }
            Vector2Int V(int x, int y) => new(x + GlenMap.Ox, y + GlenMap.Oy);
            Human("lina", "Lina", V(6, 8), new Color(0.45f, 0.72f, 0.48f), new Color(0.85f, 0.55f, 0.3f), true, new[]
            {
                "The tall grass east of here sparkles at odd hours. Gleam motes! Want to chase some?",
                "Kin learn the hours you keep. Come by at the same time and watch what happens.",
                "Water the garden plots. Tomorrow you'll have sunberries for the bowl.",
            });
            Human("bram", "Bram", V(24, 24), new Color(0.38f, 0.48f, 0.78f), new Color(0.15f, 0.12f, 0.12f), false, new[]
            {
                "Spar's just play-fighting. Bloom beats Tide, Tide beats Ember, Ember beats Bloom.",
                "Your kin remembers which moves worked. Watch for the one it's eager about.",
                "Step into the shed ring any time. I'll be there.",
            });
            Human("neri", "Neri", new Vector2Int(GlenMap.Ox + GlenMap.InnerW + 3, GlenMap.Oy + 16), new Color(0.35f, 0.62f, 0.78f), new Color(0.92f, 0.82f, 0.55f), true, new[]
            {
                "Whales pass the bay at dusk. Sit on the pier and listen.",
                "Tide kin love kelp. Don't feed them sunberries unless they ask.",
            });
            Human("soot", "Soot", new Vector2Int(GlenMap.Ox - 11, GlenMap.Oy + 12), new Color(0.82f, 0.48f, 0.28f), new Color(0.22f, 0.14f, 0.12f), true, new[]
            {
                "The dunes keep heat. Walk slow, sip often.",
                "Ember kin nap in the warm sand. Don't startle them.",
            });
            Human("moss", "Moss", new Vector2Int(GlenMap.Ox + 8, GlenMap.Oy - 7), new Color(0.7f, 0.82f, 0.9f), new Color(0.55f, 0.62f, 0.7f), true, new[]
            {
                "Frostveil is quiet. Soft moss under the ice, if you look.",
                "Come in the cabin if the wind bites.",
            });
            Human("pebble", "Pebble", V(12, 18), new Color(0.72f, 0.58f, 0.78f), new Color(0.4f, 0.28f, 0.22f), false, new[]
            {
                "I keep the path stones tidy. Don't kick them into the brook.",
                "Your kin's coat looks brighter this week.",
            });
            Friend("sprout", "Sprout", SpeciesId.Pipkin, V(14, 8), new[] { "Sprout rustles its leaves at you." });
            Friend("aqua", "Aqua", SpeciesId.Marrow, V(29, 14), new[] { "Aqua blows a bubble. It pops on your nose." });
            Friend("cinder", "Cinder", SpeciesId.Solbit, new Vector2Int(GlenMap.Ox - 10, GlenMap.Oy + 16), new[] { "Cinder hops in a little circle of warm sand." });
            Friend("kelpie", "Kelpie", SpeciesId.Marrow, new Vector2Int(GlenMap.Ox + GlenMap.InnerW + 5, GlenMap.Oy + 14), new[] { "Kelpie slaps the water with its tail." });
            Friend("frost", "Rime", SpeciesId.Pipkin, new Vector2Int(GlenMap.Ox + 12, GlenMap.Oy - 10), new[] { "Rime shakes snow off its ears." });

            int Ox = GlenMap.Ox, Oy = GlenMap.Oy;
            Human("rowan", "Ranger Rowan", new Vector2Int(Ox + 28, Oy + 45), new Color(0.36f, 0.5f, 0.3f), new Color(0.5f, 0.32f, 0.2f), true, new[]
            {
                "The Wildwood's grass runs deep. Wild kin hide in it. Walk through and they'll find you.",
                "A wild kin that loses a spar isn't hurt. It just goes off to think about it.",
                "Treat them kindly and the grown ones stop running from you.",
            });
            Human("fern", "Fern", new Vector2Int(Ox + 14, Oy + 36), new Color(0.88f, 0.66f, 0.3f), new Color(0.28f, 0.2f, 0.16f), false, new[]
            {
                "I count the wild kin every morning. More Fawnlets this year than ever.",
                "Your kin watches how the wild ones move. It learns from them too, you know.",
            });
            Human("oren", "Old Oren", new Vector2Int(Ox + 4, Oy + 48), new Color(0.58f, 0.52f, 0.66f), new Color(0.9f, 0.9f, 0.9f), true, new[]
            {
                "I used to keep a Grovestag. It never did what I said. It did what I meant.",
                "A kin that trusts you listens in a spar. One that doesn't, does its own thing.",
            });
            Human("sable", "Sable", new Vector2Int(Ox - 18, Oy + 23), new Color(0.92f, 0.4f, 0.42f), new Color(0.12f, 0.1f, 0.1f), true, new[]
            {
                "The oasis is cool even at noon. Cindercubs come to drink and doze.",
                "Feed at the same hours every day. Kin can feel a rhythm better than a clock.",
            });
            Human("kesh", "Kesh", new Vector2Int(Ox - 6, Oy + 6), new Color(0.76f, 0.6f, 0.36f), new Color(0.3f, 0.18f, 0.1f), true, new[]
            {
                "There's a road north to the snow from here, if your kin can take the cold.",
                "Wild Blazemanes roam the far dunes. Don't spar one unless your kin is ready.",
            });
            Human("marlo", "Marlo", new Vector2Int(Ox + 39, Oy + 16), new Color(0.3f, 0.52f, 0.72f), new Color(0.74f, 0.5f, 0.3f), false, new[]
            {
                "The pier runs right out to Gull Isle. Strong Tide kin nest in the grass there.",
                "I fish at dawn. The kin out here are calmest then.",
            });
            Human("wren", "Wren", new Vector2Int(Ox + 52, Oy + 16), new Color(0.95f, 0.95f, 0.92f), new Color(0.62f, 0.4f, 0.26f), true, new[]
            {
                "Welcome to Gull Isle! Mind the Ripplemanders, they splash.",
                "Kin raised by the sea get brave. Something about the waves.",
            });
            Human("yuki", "Yuki", new Vector2Int(Ox + 4, Oy - 20), new Color(0.46f, 0.6f, 0.86f), new Color(0.2f, 0.2f, 0.28f), true, new[]
            {
                "The frost-moss meadows are full of tough wild kin. Grown ones, mostly.",
                "Cold makes kin restless. A warm meal settles them faster than anything.",
            });
            Human("tamsin", "Tamsin", new Vector2Int(Ox + 38, Oy + 4), new Color(0.7f, 0.42f, 0.6f), new Color(0.86f, 0.62f, 0.34f), false, new[]
            {
                "Beachcombing! Found a pearl once. Gave it to a Tidewyrm. It seemed to want it.",
            });
            Friend("bramble", "Bramble", SpeciesId.Pipkin, new Vector2Int(Ox + 16, Oy + 44), new[] { "Bramble's antlers catch a leaf. It looks pleased." });
            Friend("sunny", "Sunny", SpeciesId.Solbit, new Vector2Int(Ox - 16, Oy + 26), new[] { "Sunny dips a paw in the oasis and hisses happily." });
            BuildWild();
        }

        // ---- Wild kin --------------------------------------------------------------------

        readonly List<Wanderer> wild = new();
        readonly System.Random wildRng = new();
        float encounterCooldown = 8f;
        Vector2Int lastKeeperCell;

        void BuildWild()
        {
            var seedRng = new System.Random(41);
            foreach (var den in WildLife.Dens())
            {
                var (species, stage) = WildLife.Pick(GlenMap.ZoneAt(den), seedRng);
                var go = new GameObject("Wild");
                go.layer = 8;
                var w = go.AddComponent<Wanderer>();
                w.Wild = true; w.Id = "wild"; w.Home = den; w.Range = 4;
                SetWild(w, species, stage);
                var col = go.AddComponent<SphereCollider>();
                col.center = Vector3.up * 0.35f; col.radius = 0.3f;
                go.transform.position = GlenMap.ToWorld(den);
                folk.Add(w);
                wild.Add(w);
            }
        }

        static void SetWild(Wanderer w, SpeciesId species, int stage)
        {
            if (w.Creature) Destroy(w.Creature.gameObject);
            w.Species = species; w.Stage = stage;
            string title = Catalog.Of(species).TitleFor(stage);
            w.DisplayName = "Wild " + title;
            w.gameObject.name = w.DisplayName;
            w.Lines = new[] { $"A wild {title}! {WildLife.Rustle(species, stage)}." };
            w.Creature = CreatureVisual.Create(w.transform, species, stage);
        }

        /// A wild kin slips off after meeting you, and comes back somewhere else later.
        IEnumerator WildAway(Wanderer w)
        {
            w.Talking = false;
            w.Away = true;
            w.gameObject.SetActive(false);
            yield return new WaitForSeconds(90f + (float)wildRng.NextDouble() * 60f);
            var dens = WildLife.Dens(wildRng.Next());
            var den = dens.Count > 0 ? dens[wildRng.Next(dens.Count)] : w.Home;
            var (species, stage) = WildLife.Pick(GlenMap.ZoneAt(den), wildRng);
            SetWild(w, species, stage);
            w.Home = den;
            w.transform.position = GlenMap.ToWorld(den);
            w.Away = false;
        }

        void MeetWild(Wanderer w, bool ambush)
        {
            string title = Catalog.Of(w.Species).TitleFor(w.Stage);
            var k = gm.Kin;
            w.Talking = true;
            gm.Save.Seen.Add(KindexKey(w.Species, w.Stage));
            ui.Say("", ambush ? $"The grass shivers... a wild {title} leaps out!" : w.NextLine(), () =>
            {
                ui.Choose($"Wild {title}", new List<Choice>
                {
                    new("Spar", () =>
                    {
                        if (k.Energy < 20) { ui.Say("", $"{k.Name} is too tired. The {title} wanders off."); StartCoroutine(WildAway(w)); return; }
                        StartSpar("Wild " + title, w.Species, w.Stage, won => AfterWildSpar(w, title, won));
                    }, w.Stage > k.Stage ? "it looks strong!" : "it learns from every spar"),
                    new($"Throw a charm ({gm.Save.Charms})", () => StartCoroutine(ThrowCharm(w, title, false)), "easier after a spar", gm.Save.Charms > 0),
                    new("Offer a treat", () => BefriendWild(w, title), "costs one food"),
                    new("Let it be", () => { gm.Save.Psyche.OnExplore("wildwatch", 0.3f, gm.Save.MetFolk.Add($"wild:{w.Species}{w.Stage}")); gm.Notify(); StartCoroutine(WildAway(w)); }),
                }, () => StartCoroutine(WildAway(w)));
            });
        }

        void BefriendWild(Wanderer w, string title)
        {
            string food = null;
            foreach (var f in gm.Save.Bag) if (f.Value > 0) { food = f.Key; break; }
            if (food == null) { ui.Say("", $"Your pouch is empty. The {title} sniffs and leaves."); StartCoroutine(WildAway(w)); return; }
            gm.Save.Bag[food]--;
            if (w.Creature) w.Creature.SetPose(KinPose.Hop);
            Fx.Hearts(w.transform.position);
            gm.Kin.Joy = Catalog.ClampStat(gm.Kin.Joy + 3);
            gm.Save.Psyche.OnExplore("Visit_AnimalFriend", 0.8f, gm.Save.MetFolk.Add($"wild:{w.Species}{w.Stage}"));
            CareSim.Remember(gm.Save, $"A wild {title} took a {Catalog.Food(food).Name.ToLowerInvariant()} from your hand. {gm.Kin.Name} watched closely.");
            gm.Collect($"wildgift:{DateTime.Now:yyyyMMddHHmmss}", "gleam", 2);
            ui.Say("", $"The wild {title} eats, nuzzles {gm.Kin.Name}, and leaves two gleam in the grass.");
            gm.Notify();
            StartCoroutine(WildAway(w));
        }

        /// Walking through tall grass can stir up a wild kin that was hiding.
        void CheckEncounter()
        {
            encounterCooldown -= Time.deltaTime;
            var cell = keeper.Cell;
            if (cell == lastKeeperCell) return;
            lastKeeperCell = cell;
            if (encounterCooldown > 0 || GlenMap.At(cell.x, cell.y) != Tile.TallGrass) return;
            if (wildRng.NextDouble() > 0.07) return;
            Wanderer pick = null;
            foreach (var w in wild) if (!w.Away && !w.Talking) { pick = w; break; }
            if (pick == null) return;
            encounterCooldown = 25f;
            // Reroll it for the patch the keeper is standing in, then bring it beside them.
            var (species, stage) = WildLife.Pick(GlenMap.ZoneAt(cell), wildRng);
            SetWild(pick, species, stage);
            pick.gameObject.SetActive(true);
            pick.Home = cell;
            pick.transform.position = GlenMap.ToWorld(GlenMap.NearestWalkable(cell + Vector2Int.right));
            pick.Face(keeper.transform.position);
            pick.Creature.SetPose(KinPose.Cheer);
            ProcAudio.I?.Chirp(species, 1.1f);
            MeetWild(pick, true);
        }

        // ---- Title and new game --------------------------------------------------------

        void ShowTitle()
        {
            GameInput.Locked = true;
            cam.Push(GlenMap.ToWorld(new Vector2Int(19, 15)), 38, 26f, 30);
            ui.ShowTitle(gm.HasGame, Continue, () => StartCoroutine(NewGameFlow()));
        }

        void Continue()
        {
            BuildKin();
            cam.Release();
            GameInput.Locked = false;
            started = true;
            ui.ShowHud(true);
            ui.Refresh(gm.Save, dayNight.Phase);
            var away = gm.Save.Memories.Count > 0 ? gm.Save.Memories[0].Text : "";
            if (away.StartsWith("While you were away")) ui.Say("", away);
            else ui.Toast($"Welcome back, {gm.Save.KeeperName}.");
        }

        IEnumerator NewGameFlow()
        {
            string keeperName = null, kinName = null;
            ui.AskName("What's your name, keeper?", "Keeper", n => keeperName = n);
            while (keeperName == null) yield return null;

            // Starters on the pavilion deck.
            var deck = GlenMap.ToWorld(new Vector2Int(19, 27)) + Vector3.up * 0.16f;
            var showcase = new List<CreatureVisual>();
            for (int i = 0; i < 3; i++)
            {
                var v = CreatureVisual.Create(null, Catalog.All[i].Id, 0);
                v.transform.position = deck + new Vector3((i - 1) * 1.4f, 0, 0);
                v.transform.rotation = Quaternion.LookRotation(Vector3.back);
                showcase.Add(v);
            }
            int picked = 0;
            bool chosen = false;
            ui.StarterPicker(i =>
            {
                picked = i;
                var v = showcase[i];
                cam.Push(v.transform.position + Vector3.up * 0.4f, 24, 4.2f, 30);
                v.SetPose(KinPose.Cheer);
                ProcAudio.I?.Chirp(Catalog.All[i].Id);
                var def = Catalog.All[i];
                ui.Toast($"{def.Name} · {def.Element} kin\n{def.Blurb}");
            }, () => chosen = true);
            while (!chosen) yield return null;
            var species = Catalog.All[picked];
            ui.AskName($"Name your {species.Name}:", species.Name, n => kinName = n);
            while (kinName == null) yield return null;
            foreach (var v in showcase) Destroy(v.gameObject);

            gm.NewGame(keeperName, kinName, species.Id);
            BuildKin();
            kin.Place(GlenMap.NearestWalkable(GlenMap.Buildings[2].Door + Vector2Int.right));
            cam.Release();
            Fx.Sparkle(kin.transform.position, Catalog.ElementColor(species.Element));
            ProcAudio.I?.Play("fanfare");
            started = true;
            ui.ShowHud(true);
            ui.Refresh(gm.Save, dayNight.Phase);
            bool done = false;
            ui.Say(new[]
            {
                ("Lina", $"Welcome to Lumina Vale, {keeperName}! And hello, {kinName}."),
                ("Lina", "Kin learn from you: the food you share, the hours you visit, the games you play."),
                ("Lina", "Feed at the pavilion, brush and praise up close, nap at the homestead. Bram spars by the shed."),
                ("Lina", "Watch the bubble over its head. That's it asking for something. Answer, and it remembers."),
            }, () => done = true);
            while (!done) yield return null;
            GameInput.Locked = false;
        }

        // ---- Overworld loop ------------------------------------------------------------

        enum Target { None, Kin, Folk, Feed, House, Spar, Runes, Berries, Sign, Mail, Farm, Gate, Leave, Bed, Cook, Shop, Lab, Fish, Dig }

        Target target;
        Wanderer targetFolk;
        string targetSpot;

        void Update()
        {
            if (!started || !gm.HasGame) return;
            CullWild();
            if (minigame) return;
            gm.TickFarm();
            ui.SetBubbles(kin ? kin.transform : null, inScene ? null : gm.Kin.PendingBid, inScene ? "" : kin ? kin.Thought : "");

            if (ui.DialogOpen)
            {
                if (GameInput.ConsumeA()) ui.AdvanceDialog();
                ui.SetPrompt("");
                return;
            }
            if (inScene || ui.Blocking || GameInput.Locked) { ui.SetPrompt(""); GameInput.ConsumeA(); return; }

            if (evolvePending)
            {
                evolvePending = false;
                OfferRite();
                return;
            }

            if (indoor != null) FindIndoorTarget();
            else
            {
                CheckEncounter();
                if (ui.DialogOpen || ui.Blocking) return;
                FindTarget();
            }
            ui.SetPrompt(target switch
            {
                Target.Kin => gm.Kin.Asleep ? "Peek" : $"{gm.Kin.Name}",
                Target.Folk => "Talk",
                Target.Feed => "Feed",
                Target.House => "Home",
                Target.Spar => "Spar",
                Target.Runes => "Runes",
                Target.Berries => "Pick",
                Target.Sign => "Read",
                Target.Mail => "Mail",
                Target.Farm => gm.PlotStage(targetSpot) == 2 ? "Harvest" : gm.PlotStage(targetSpot) == 1 ? "Growing" : "Water",
                Target.Gate => "Walk",
                Target.Leave => "Leave",
                Target.Bed => "Rest",
                Target.Cook => "Stove",
                Target.Shop => "Shop",
                Target.Lab => "Ranger",
                Target.Fish => "Fish",
                Target.Dig => "Dig",
                _ => "",
            });
            if (GameInput.ConsumeA()) Interact();
            if (GameInput.ConsumeMenu()) MainMenu();
            if (GameInput.ConsumeMap()) OpenAtlas();
        }

        void FindTarget()
        {
            target = Target.None;
            targetFolk = null;
            var p = keeper.transform.position;
            var ahead = p + keeper.Forward * 0.9f;
            float Dist(Vector3 a) => Vector3.Distance(new Vector3(a.x, 0, a.z), new Vector3(ahead.x, 0, ahead.z));
            float best = 1.5f;
            if (kin && Dist(kin.transform.position) < best) { best = Dist(kin.transform.position); target = Target.Kin; }
            foreach (var f in folk)
            {
                float d = Dist(f.transform.position);
                if (d < best) { best = d; target = Target.Folk; targetFolk = f; }
            }
            if (target != Target.None) return;
            var cell = keeper.Cell;
            foreach (var b in GlenMap.Buildings)
                if (Vector2Int.Distance(cell, b.Door) < 1.25f)
                {
                    if (b.Id == "pavilion") { target = Target.Feed; return; }
                    if (b.Enterable) { target = Target.House; targetSpot = b.Id; return; }
                    if (b.Id == "shed") { target = Target.Spar; return; }
                    return;
                }
            foreach (var s in GlenMap.Spots)
            {
                var sp = GlenMap.ToWorld(s.Cell);
                float d = Dist(sp);
                if (s.Kind == "rune" && d < 2.2f) { target = Target.Runes; return; }
                if (s.Kind == "berrybush" && d < 1.3f) { target = Target.Berries; targetSpot = s.Id; return; }
                if (s.Kind == "sign" && d < 1.2f) { target = Target.Sign; targetSpot = s.Id; return; }
                if (s.Kind == "mailbox" && d < 1.2f) { target = Target.Mail; return; }
                if (s.Kind == "farm" && d < 1.2f) { target = Target.Farm; targetSpot = s.Id; return; }
                if (s.Kind == "gate" && d < 1.4f) { target = Target.Gate; targetSpot = s.Id; return; }
            }
            if (FindDig()) { target = Target.Dig; return; }
            var aheadCell = GlenMap.ToCell(keeper.transform.position + keeper.Forward * 1.1f);
            var aheadTile = GlenMap.At(aheadCell.x, aheadCell.y);
            if (aheadTile is Tile.Water or Tile.DeepWater) target = Target.Fish;
        }

        void Interact()
        {
            ProcAudio.I?.Play("confirm", 0.6f);
            switch (target)
            {
                case Target.Kin: KinMenu(); break;
                case Target.Folk: TalkTo(targetFolk); break;
                case Target.Feed: FeedMenu(); break;
                case Target.House: EnterBuilding(targetSpot); break;
                case Target.Leave: LeaveBuilding(); break;
                case Target.Bed: StartCoroutine(Sleep(false)); break;
                case Target.Cook: ui.Toast("The stove ticks. Cooked treats come later — the bowl is still best."); break;
                case Target.Spar: SparPrompt("Bram"); break;
                case Target.Runes: StartDuet(); break;
                case Target.Berries: PickBerries(targetSpot); break;
                case Target.Farm: TendPlot(targetSpot); break;
                case Target.Gate: OpenAtlas(); break;
                case Target.Shop: ShopMenu(); break;
                case Target.Lab: LabMenu(); break;
                case Target.Fish: StartCoroutine(Fish()); break;
                case Target.Dig: Dig(); break;
                case Target.Sign when targetSpot == "sign1": ui.Say("", "BROOKSIDE TOWN.  Kin Mart west.  Inn in the middle.  Ranger lab east.  Mistmarsh further west, Bloom Meadows east, Southfield down the south road."); break;
                case Target.Sign: ui.Say("", "LUMINA VALE.  Homestead south.  Garden inside the fence.  Sunbake Dunes west.  Tidewake Bay east — whales at dusk.  Frostveil north."); break;
                case Target.Mail:
                {
                    string key = $"mail:{DateTime.Now:yyyyMMdd}";
                    if (!gm.Save.TakenPickups.Contains(key))
                    {
                        gm.Collect(key, "gleam", 3);
                        ui.Say("", "A note from the Vale: \"Thank you for keeping the glen.\" Three gleam are tucked inside.");
                    }
                    else ui.Say("", "The mailbox is empty. Come back tomorrow.");
                    break;
                }
            }
        }

        void KinMenu()
        {
            var k = gm.Kin;
            kin.Face(keeper.transform.position);
            if (k.Asleep)
            {
                ui.Choose($"{k.Name} is asleep", new List<Choice>
                {
                    new("Let it sleep", () => { }),
                    new("Wake gently", () => { k.Asleep = false; k.Joy = Catalog.ClampStat(k.Joy - 2); kin.Visual.SetPose(KinPose.Idle); gm.Notify(); gm.Say($"{k.Name} blinks awake."); }),
                }, () => { });
                return;
            }
            string bid = k.PendingBid;
            string ask = bid != null ? $"  (it wants: {GameUI.BidWord(bid)})" : "";
            ui.Choose($"{k.Name}{ask}", new List<Choice>
            {
                new("Brush", () => StartBrush(), "coat & bond"),
                new("Praise", () => { gm.Praise(); kin.Visual.SetPose(KinPose.Cheer); Fx.Hearts(kin.transform.position); ProcAudio.I?.Chirp(k.Species, 1.15f); }, bid == "trick" ? "it's showing off!" : "a good kin"),
                new("Nuzzle", () => { gm.Nuzzle(); kin.Visual.Squash(0.2f); Fx.Hearts(kin.transform.position); ProcAudio.I?.Chirp(k.Species, 0.95f); }),
                new("Listen", () => StartCoroutine(ChatProxyClient.Thought(gm.Save, line => ui.Say(k.Name, line))), "what is it thinking?"),
                new("Friendly spar", () => SparPrompt("a rival kin"), "play-fight, they learn"),
            }, () => { });
        }

        void TalkTo(Wanderer w)
        {
            w.Talking = true;
            w.Face(keeper.transform.position);
            if (w.Human) w.Human.Wave();
            if (w.Creature) { w.Creature.SetPose(KinPose.Hop); gm.Kin.Joy = Catalog.ClampStat(gm.Kin.Joy + 1); gm.Notify(); }
            void Done() => w.Talking = false;
            if (w.Wild) { MeetWild(w, false); return; }
            if (w.Id == "rowan") { ui.Say(w.DisplayName, w.NextLine(), () => { Done(); RangerRequestMenu(w.DisplayName); }); return; }
            if (w.Id == "bram") { ui.Say(w.DisplayName, w.NextLine(), () => { Done(); SparPrompt("Bram"); }); return; }
            if (w.Id == "lina")
            {
                string gift = $"lina:{DateTime.Now:yyyyMMdd}";
                if (!gm.Save.TakenPickups.Contains(gift))
                {
                    gm.Collect(gift, "sunberry", 2);
                    ui.Say(w.DisplayName, "Morning! Two sunberries from the garden, for you two.");
                }
                ui.Say(w.DisplayName, w.NextLine(), () =>
                {
                    Done();
                    ui.Choose("Chase gleam motes?", new List<Choice> { new("Let's go!", StartHunt, "in the tall grass") }, () => { });
                });
                return;
            }
            if (w.Creature)
            {
                ui.Say(w.DisplayName, w.NextLine(), () =>
                {
                    Done();
                    ui.Choose($"Play-spar with {w.DisplayName}?", new List<Choice>
                    {
                        new("Spar!", () => StartSpar(w.DisplayName), "they learn from it"),
                    }, () => { });
                });
                return;
            }
            ui.Say(w.DisplayName, w.NextLine(), Done);
        }

        void FeedMenu()
        {
            var opts = new List<Choice>();
            foreach (var f in Catalog.Foods)
            {
                gm.Save.Bag.TryGetValue(f.Id, out int n);
                string love = gm.Kin.FoodLove.TryGetValue(f.Id, out var l) && l >= 0.55f ? " · loves it" : "";
                var food = f;
                opts.Add(new Choice($"{f.Name}  x{n}", () => StartCoroutine(FeedScene(food.Id)), f.Blurb + love, n > 0));
            }
            ui.Choose("Share a treat at the bowl", opts, () => { });
        }

        IEnumerator FeedScene(string foodId)
        {
            inScene = true;
            GameInput.Locked = true;
            kin.Hold();
            var bowl = world.BowlFood.position;
            var stand = GlenMap.Buildings[2].Door;
            kin.WalkTo(stand);
            cam.Push(bowl + Vector3.up * 0.3f + Vector3.back * 0.8f, 32, 5.5f, 30);
            float timeout = 6f;
            while (!kin.Arrived && (timeout -= Time.deltaTime) > 0) yield return null;
            kin.Face(bowl);
            kin.Visual.SetPose(KinPose.Eat);
            for (int i = 0; i < 4; i++) { ProcAudio.I?.Play("munch", 0.7f, UnityEngine.Random.Range(0.9f, 1.1f)); yield return new WaitForSeconds(0.35f); }
            var outcome = gm.Feed(foodId);
            if (outcome.Overfed) kin.Visual.SetPose(KinPose.Sulk);
            else { kin.Visual.SetPose(KinPose.Cheer); Fx.Hearts(kin.transform.position); ProcAudio.I?.Chirp(gm.Kin.Species, 1.2f); }
            yield return new WaitForSeconds(1.2f);
            cam.Release();
            kin.Release();
            GameInput.Locked = false;
            inScene = false;
        }

        void FindIndoorTarget()
        {
            target = Target.None;
            var p = keeper.transform.position;
            if (Vector3.Distance(p, indoor.Entry) < 1.15f) { target = Target.Leave; return; }
            if (indoor.Kind == "shop" && Vector3.Distance(p, indoor.Counter) < 1.4f) { target = Target.Shop; return; }
            if (indoor.Kind == "lab" && (Vector3.Distance(p, indoor.Counter) < 1.4f || Vector3.Distance(p, indoor.Bench) < 1.3f)) { target = Target.Lab; return; }
            if (indoor.Kind == "shed" && Vector3.Distance(p, indoor.Bench) < 1.5f) { target = Target.Spar; return; }
            if (Vector3.Distance(p, indoor.Bed) < 1.3f) { target = Target.Bed; return; }
            if (Vector3.Distance(p, indoor.Stove) < 1.2f) { target = Target.Cook; return; }
            if (kin && Vector3.Distance(p, kin.transform.position) < 1.4f) target = Target.Kin;
        }

        void EnterBuilding(string id)
        {
            var b = System.Array.Find(GlenMap.Buildings, x => x.Id == id);
            if (b == null || !b.Enterable) { HouseMenu(); return; }
            if (world.Rooms == null || !world.Rooms.TryGetValue(b.RoomId, out var room)) { HouseMenu(); return; }
            outdoorCell = keeper.Cell;
            outdoorCam = cam.Clamp;
            indoorBuilding = b;
            indoor = room;
            keeper.Indoor = room.Walk;
            keeper.transform.position = room.Entry + Vector3.forward * 0.4f;
            if (kin)
            {
                kin.Hold();
                kin.transform.position = room.Entry + Vector3.right * 0.7f + Vector3.forward * 0.5f;
            }
            cam.Clamp = room.Cam;
            cam.Distance = 7.5f;
            cam.Pitch = 28f;
            cam.Snap();
            ui.Toast($"Inside {b.Name}");
        }

        void LeaveBuilding()
        {
            if (indoorBuilding == null) return;
            keeper.Indoor = null;
            keeper.Place(indoorBuilding.Door);
            if (kin)
            {
                kin.Place(indoorBuilding.Door + Vector2Int.right);
                kin.Release();
            }
            cam.Clamp = outdoorCam;
            cam.Distance = 15.5f;
            cam.Pitch = 52f;
            cam.Snap();
            indoor = null;
            indoorBuilding = null;
        }

        void HouseMenu()
        {
            ui.Choose("Inside?", new List<Choice>
            {
                new("Nap together", () => StartCoroutine(Sleep(false)), "rest & energy"),
                new("Sleep until morning", () => StartCoroutine(Sleep(true)), "8 hours pass"),
            }, () => { });
        }

        IEnumerator Sleep(bool overnight)
        {
            inScene = true;
            GameInput.Locked = true;
            yield return ui.Fade(1, 0.6f);
            if (overnight)
            {
                gm.PassHours(8);
                Catalog.DebugPhaseOverride = DayPhase.Dawn;
            }
            else gm.Rest();
            if (indoor != null)
            {
                keeper.transform.position = indoor.Bed + Vector3.right * 0.5f;
                if (kin) kin.transform.position = indoor.Bed + Vector3.left * 0.4f;
            }
            else
            {
                kin.Place(GlenMap.Buildings[0].Door + Vector2Int.right);
                keeper.Place(GlenMap.Buildings[0].Door);
            }
            cam.Snap();
            yield return new WaitForSeconds(0.6f);
            yield return ui.Fade(0, 0.8f);
            GameInput.Locked = false;
            inScene = false;
        }

        void SparPrompt(string rival)
        {
            if (gm.Kin.Energy < 20) { ui.Say(rival, $"{gm.Kin.Name} looks worn out. Let it rest first!"); return; }
            ui.Choose("A friendly spar?", new List<Choice> { new("Spar!", () => StartSpar(rival), "turn-based, 8 rounds max") }, () => { });
        }

        void StartSpar(string rival) => StartSpar(rival, null, -1, null);

        void StartSpar(string rival, SpeciesId? foeSpecies, int foeStage, Action<bool> after)
        {
            inScene = true;
            kin.Hold();
            kin.gameObject.SetActive(false);
            keeper.Busy = true;
            battle.Finished = won =>
            {
                kin.gameObject.SetActive(true);
                kin.Release();
                keeper.Busy = false;
                inScene = false;
                ProcAudio.I?.Music(dayNight.Phase.ToString().ToLowerInvariant());
                ui.ShowHud(true);
                after?.Invoke(won);
            };
            battle.Begin(rival, foeSpecies, foeStage);
        }

        void StartBrush()
        {
            inScene = true;
            brush.Done = q => { gm.Groom(q); inScene = false; };
            brush.Begin();
        }

        void StartDuet()
        {
            if (GlenMap.HeightAt(keeper.Cell.x, keeper.Cell.y) != 1) { ui.Toast("The runes are up on the hill."); return; }
            inScene = true;
            duet.Done = s => { gm.Play("pattern", s); inScene = false; };
            duet.Begin();
        }

        void StartHunt()
        {
            inScene = true;
            hunt.Done = (s, caught) =>
            {
                gm.Save.Gleam += caught;
                gm.Play("ribbons", s);
                inScene = false;
            };
            hunt.Begin();
            inScene = false; // the hunt is played in the overworld; keep walking enabled
        }

        void PickBerries(string bushId)
        {
            string key = $"{bushId}:{DateTime.Now:yyyyMMdd}";
            if (gm.Save.TakenPickups.Contains(key)) { ui.Toast("Picked clean. It'll refill tomorrow."); return; }
            int index = bushId[^1] - '0';
            string food = index switch { 1 => "kelpbit", 2 => "spicecrumb", _ => "sunberry" };
            gm.Collect(key, food, 2);
            ProcAudio.I?.Play("pickup");
            if (world.Berries.TryGetValue(bushId, out var b)) b.SetActive(false);
        }

        void OfferRite()
        {
            ui.Choose($"{gm.Kin.Name} is shimmering…", new List<Choice>
            {
                new("Begin the rite", () => { inScene = true; StartCoroutine(Evolution.Play(ui, cam, kin, () => { inScene = false; ui.Refresh(gm.Save, dayNight.Phase); })); }, "evolve"),
                new("Not yet", () => { }),
            });
        }

        void TendPlot(string id)
        {
            int st = gm.PlotStage(id);
            if (st == 2)
            {
                gm.HarvestPlot(id);
                if (world.Crops.TryGetValue(id, out var c) && c) c.transform.localScale = new Vector3(0.25f, 0.08f, 0.25f);
                ProcAudio.I?.Play("pickup");
            }
            else if (st == 1) ui.Toast("The sprouts drink. Tomorrow.");
            else
            {
                gm.WaterPlot(id);
                if (world.Crops.TryGetValue(id, out var c) && c) c.transform.localScale = new Vector3(0.4f, 0.28f, 0.4f);
                ProcAudio.I?.Play("confirm", 0.5f);
            }
        }

        void OpenAtlas()
        {
            var choices = new List<Choice>();
            foreach (var r in GlenMap.Regions)
            {
                var region = r;
                bool open = RegionOpen(region.Id);
                choices.Add(new Choice(region.Title, () => TravelTo(region.Cell), region.Blurb, open));
            }
            ui.Choose("Vale map", choices, () => { });
        }

        bool RegionOpen(string id)
        {
            if (id == "glen") return true;
            // Regions open as the kin grows (learned credit), not with a level number.
            float g = gm.Save.Psyche.Growth;
            return id switch
            {
                "wildwood" => g >= 1f,
                "dunes" => g >= 2f,
                "oasis" => g >= 5f,
                "bay" => g >= 8f,
                "isle" => g >= 12f,
                "frost" => g >= 16f,
                _ => true,
            };
        }

        void TravelTo(Vector2Int cell)
        {
            keeper.Place(cell);
            if (kin) kin.transform.position = GlenMap.ToWorld(cell) + Vector3.right * 0.8f;
            cam.Snap();
            ui.Toast(GlenMap.ZoneAt(cell));
        }

        void MainMenu()
        {
            ui.Choose("Menu", new List<Choice>
            {
                new("World map", OpenAtlas, "travel to any region you've opened"),
                new("Kindex", ShowKindex, $"{KindexCaughtCount()}/9 caught · {gm.Save.Seen.Count} seen"),
                new("Kin box", ShowKinBox, $"{gm.Save.Caught.Count} caught kin"),
                new("Bag", () => ui.Say("", BagText()), $"{gm.Save.Gleam} gleam · {gm.Save.Charms} charms"),
                new("Journal", () => ui.ShowJournal(gm.Save, () => { }), "memories & what it learned"),
                new("Change time of day", () => { dayNight.Cycle(); ui.Toast($"Time shifts to {Catalog.PhaseAt(DateTime.Now)}"); }, "preview"),
                new("Save", () => { gm.Persist(); ui.Toast("Saved."); }),
                new("Release kin & restart", () => ui.Choose("Really start over?", new List<Choice>
                {
                    new("Yes, start over", () => { gm.ResetGame(); if (kin) Destroy(kin.gameObject); started = false; ui.ShowHud(false); ShowTitle(); }),
                }, () => { })),
            }, () => { });
        }

        void OnEnable()
        {
            // Restore world state that depends on today's pickups once the save exists.
            StartCoroutine(RefreshBushes());
        }

        IEnumerator RefreshBushes()
        {
            while (world == null || gm == null || !gm.HasGame) yield return null;
            foreach (var kv in world.Berries)
                kv.Value.SetActive(!gm.Save.TakenPickups.Contains($"{kv.Key}:{DateTime.Now:yyyyMMdd}"));
        }
    }
}
