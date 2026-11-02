using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// Catching wild kin, the Kindex and kin box, the town shop and ranger lab,
    /// fishing, digging and the rangers' daily requests.
    public sealed partial class Director
    {
        bool minigame;
        float cullAt;
        readonly List<Wanderer> caughtFolk = new();
        readonly Dictionary<Vector2Int, GameObject> digSites = new();
        string digDay;

        static string KindexKey(SpeciesId s, int stage) => $"{s}:{stage}";

        int KindexCaughtCount()
        {
            var got = new HashSet<string>();
            foreach (var c in gm.Save.Caught) got.Add(KindexKey(c.Species, c.Stage));
            return got.Count;
        }

        /// Far-off wild kin switch off entirely so dozens of them stay cheap on phones.
        void CullWild()
        {
            if (Time.unscaledTime < cullAt || !keeper) return;
            cullAt = Time.unscaledTime + 0.5f;
            var p = keeper.transform.position;
            foreach (var w in wild)
            {
                bool on = !w.Away && (w.transform.position - p).sqrMagnitude < 34f * 34f;
                if (w.gameObject.activeSelf != on) w.gameObject.SetActive(on);
            }
        }

        // ---- Catching ------------------------------------------------------------------

        void AfterWildSpar(Wanderer w, string title, bool won)
        {
            if (!won || gm.Save.Charms <= 0)
            {
                ui.Say("", won ? $"The {title} is worn out, but you have no charms left. It slips away." : $"The {title} bounds off into the grass.");
                StartCoroutine(WildAway(w));
                return;
            }
            ui.Choose($"The {title} is tired out", new List<Choice>
            {
                new($"Throw a charm ({gm.Save.Charms})", () => StartCoroutine(ThrowCharm(w, title, true)), $"about {Mathf.RoundToInt(CatchChance(w.Stage, true) * 100)}% chance"),
                new("Let it go", () => StartCoroutine(WildAway(w))),
            }, () => StartCoroutine(WildAway(w)));
        }

        /// Harder for grown-up kin; much easier once a spar has tired it, and a trusting
        /// companion steadies your aim.
        float CatchChance(int stage, bool afterSpar)
        {
            float trust = gm.Save.Psyche[Emotion.Trust];
            return Mathf.Clamp(0.32f - stage * 0.1f + (afterSpar ? 0.38f : 0) + trust * 0.15f, 0.05f, 0.92f);
        }

        IEnumerator ThrowCharm(Wanderer w, string title, bool afterSpar)
        {
            if (gm.Save.Charms <= 0) { ui.Say("", "No charms left. The Kin Mart in Brookside sells them."); StartCoroutine(WildAway(w)); yield break; }
            gm.Save.Charms--;
            bool caught = UnityEngine.Random.value < CatchChance(w.Stage, afterSpar);
            ProcAudio.I?.Play("confirm", 0.7f, 1.3f);
            Fx.Sparkle(w.transform.position, new Color(0.7f, 0.95f, 1f));
            bool done = false;
            ui.Say(new[] { ("", "You toss a lumen charm..."), ("", "It glows and wobbles... once..."), ("", caught ? "...twice... and settles!" : "...it bursts open!") }, () => done = true);
            while (!done) yield return null;
            if (!caught)
            {
                ui.Say("", $"The {title} shakes free and darts away.");
                StartCoroutine(WildAway(w));
                yield break;
            }
            var zone = GlenMap.ZoneAt(GlenMap.ToCell(w.transform.position));
            var ck = new CaughtKin { Species = w.Species, Stage = w.Stage, Name = title, Zone = zone };
            gm.Save.Caught.Add(ck);
            gm.Save.Seen.Add(KindexKey(w.Species, w.Stage));
            Fx.Hearts(w.transform.position);
            ProcAudio.I?.Chirp(w.Species, 1.2f);
            // The companion has a new friend: novelty and company are their own reward.
            gm.Save.Psyche.OnExplore("Visit_AnimalFriend", 1f, true);
            gm.Kin.Joy = Catalog.ClampStat(gm.Kin.Joy + 4);
            CareSim.Remember(gm.Save, $"Caught a wild {title} in {RegionTitle(zone)}. {gm.Kin.Name} sniffed it all the way home.");
            gm.Notify();
            gm.Persist();
            w.Away = true;
            w.gameObject.SetActive(false);
            SpawnCaughtKin();
            string request = RequestProgress();
            ui.Say("", $"Caught the {title}! It heads off to wait in your glen.{request}");
            StartCoroutine(WildAway(w));
        }

        static string RegionTitle(string zone)
        {
            foreach (var r in GlenMap.Regions) if (r.Id == zone) return r.Title;
            return zone switch { "thicket" => "the Wildwood", "meadow" => "the glen meadow", _ => "the Vale" };
        }

        /// Caught kin roam the meadow east of the homestead (the newest dozen are out).
        void SpawnCaughtKin()
        {
            foreach (var f in caughtFolk) { folk.Remove(f); friendKin.Remove(f.transform); if (f) Destroy(f.gameObject); }
            caughtFolk.Clear();
            var home = GlenMap.SpotById("meadow").Cell;
            var list = gm.Save.Caught;
            for (int i = Mathf.Max(0, list.Count - 12); i < list.Count; i++)
            {
                var c = list[i];
                var go = new GameObject(c.Name);
                go.layer = 8;
                var w = go.AddComponent<Wanderer>();
                var cell = GlenMap.NearestWalkable(home + new Vector2Int(i % 4 - 2, i / 4 % 3 - 1));
                w.Id = "caught"; w.DisplayName = c.Name; w.Home = cell; w.Range = 4;
                w.Species = c.Species; w.Stage = c.Stage;
                w.Lines = new[] { $"{c.Name} trots over. It remembers the day you met in {RegionTitle(c.Zone)}." };
                w.Creature = CreatureVisual.Create(go.transform, c.Species, c.Stage);
                go.transform.localScale = Vector3.one * 0.85f;
                var col = go.AddComponent<SphereCollider>();
                col.center = Vector3.up * 0.35f; col.radius = 0.3f;
                go.transform.position = GlenMap.ToWorld(cell);
                folk.Add(w);
                friendKin.Add(go.transform);
                caughtFolk.Add(w);
            }
        }

        void ShowKindex()
        {
            var options = new List<Choice>();
            foreach (var def in Catalog.All)
            for (int stage = 0; stage < 3; stage++)
            {
                string key = KindexKey(def.Id, stage);
                int caught = gm.Save.Caught.FindAll(c => c.Species == def.Id && c.Stage == stage).Count;
                bool seen = gm.Save.Seen.Contains(key) || caught > 0 || (gm.Kin.Species == def.Id && gm.Kin.Stage >= stage);
                string title = def.TitleFor(stage);
                string sub = caught > 0 ? $"caught ×{caught}" : seen ? "seen" : "???";
                var d = def;
                int st = stage;
                options.Add(new Choice(seen ? title : "?????", () => ui.Say("Kindex", seen
                    ? $"{title}, {d.Element} kin, form {st + 1} of 3. {Habitat(d.Id, st)}"
                    : "Not seen yet. Wild kin hide in tall grass all over the Vale."), sub));
            }
            ui.Choose($"Kindex · {KindexCaughtCount()}/9 caught", options, () => { });
        }

        static string Habitat(SpeciesId s, int stage)
        {
            string where = s switch
            {
                SpeciesId.Pipkin => "Most common in the Wildwood and Bloom Meadows",
                SpeciesId.Marrow => "Fond of Tidewake Bay, Mistmarsh and the isles",
                _ => "Basks in the Sunbake Dunes and Redrock Canyon",
            };
            return stage == 0 ? where + "." : where + (stage == 2 ? ", but grown ones keep to Crag Peaks, Aurora Lake and Coral Isle." : ", and the far regions.");
        }

        void ShowKinBox()
        {
            var list = gm.Save.Caught;
            if (list.Count == 0) { ui.Say("", "Your kin box is empty. Spar a wild kin in tall grass, then throw a lumen charm."); return; }
            var options = new List<Choice>();
            for (int i = list.Count - 1; i >= 0 && options.Count < 12; i--)
            {
                var c = list[i];
                options.Add(new Choice(c.Name, () => ui.Choose(c.Name, new List<Choice>
                {
                    new("Let it return to the wild", () =>
                    {
                        list.Remove(c);
                        CareSim.Remember(gm.Save, $"You let {c.Name} go home to {RegionTitle(c.Zone)}.");
                        SpawnCaughtKin();
                        gm.Persist();
                        ui.Toast($"{c.Name} bounds away.");
                    }),
                }, () => { }), $"from {RegionTitle(c.Zone)} · {c.At:MMM d}"));
            }
            ui.Choose($"Kin box · {list.Count}", options, () => { });
        }

        string BagText()
        {
            var parts = new List<string>();
            foreach (var f in Catalog.Foods)
                if (gm.Save.Bag.TryGetValue(f.Id, out int n) && n > 0) parts.Add($"{f.Name} ×{n}");
            parts.Add($"lumen charm ×{gm.Save.Charms}");
            return $"{string.Join(", ", parts)}. {gm.Save.Gleam} gleam. Fish caught: {gm.Save.FishCaught}.";
        }

        // ---- Town ----------------------------------------------------------------------

        static int PriceOf(string foodId) => foodId switch { "milkdrop" => 5, "spicecrumb" => 4, _ => 3 };
        const int CharmPrice = 6;

        void ShopMenu()
        {
            var opts = new List<Choice>
            {
                new($"Lumen charm · {CharmPrice}g", () => Buy(null, CharmPrice), $"you have {gm.Save.Charms}", gm.Save.Gleam >= CharmPrice),
            };
            foreach (var f in Catalog.Foods)
            {
                var food = f;
                int price = PriceOf(f.Id);
                gm.Save.Bag.TryGetValue(f.Id, out int have);
                opts.Add(new Choice($"{f.Name} · {price}g", () => Buy(food.Id, price), $"you have {have}", gm.Save.Gleam >= price));
            }
            ui.Say("Clerk", $"Welcome to the Kin Mart! You've got {gm.Save.Gleam} gleam.", () => ui.Choose("Buy", opts, () => { }));
        }

        void Buy(string foodId, int price)
        {
            if (gm.Save.Gleam < price) { ui.Toast("Not enough gleam."); return; }
            gm.Save.Gleam -= price;
            if (foodId == null) gm.Save.Charms++;
            else { gm.Save.Bag.TryGetValue(foodId, out int n); gm.Save.Bag[foodId] = n + 1; }
            ProcAudio.I?.Play("confirm", 0.6f, 1.2f);
            gm.Notify();
            ShopMenu();
        }

        void LabMenu()
        {
            ui.Choose("Ranger lab", new List<Choice>
            {
                new("Rest on the healing pad", HealKin, "restores energy"),
                new("Kindex", ShowKindex, $"{KindexCaughtCount()}/9 caught"),
                new("Ranger request", () => RangerRequestMenu("Professor Alder")),
            }, () => { });
        }

        void HealKin()
        {
            string key = $"heal:{DateTime.Now:yyyyMMddHH}";
            if (gm.Save.TakenPickups.Contains(key)) { ui.Say("Professor Alder", "The pad needs to recharge. Try again in a little while."); return; }
            gm.Save.TakenPickups.Add(key);
            gm.Kin.Energy = Catalog.ClampStat(gm.Kin.Energy + 45);
            gm.Kin.Asleep = false;
            if (kin) Fx.Sparkle(kin.transform.position, new Color(0.6f, 1f, 0.8f));
            gm.Notify();
            ui.Say("Professor Alder", $"There. {gm.Kin.Name} is full of beans again.");
        }

        // ---- Ranger requests -----------------------------------------------------------

        void RangerRequestMenu(string who)
        {
            var req = gm.Save.Request;
            bool stale = req == null || req.Given.Date != DateTime.Now.Date;
            if (stale && (req == null || req.Rewarded || req.Given.Date < DateTime.Now.Date))
            {
                var pool = Catalog.All;
                var pick = pool[new System.Random(DateTime.Now.DayOfYear * 31).Next(pool.Length)].Id;
                gm.Save.Request = req = new RangerRequest { Species = pick, Given = DateTime.Now };
                ui.Say(who, $"Today's survey: catch a wild {Catalog.Of(pick).TitleFor(0)} or one of its kind, and come tell me. Five gleam and two charms for your trouble.");
                return;
            }
            if (req.Rewarded) { ui.Say(who, "You've done today's survey. Come back tomorrow!"); return; }
            if (RequestMet(req))
            {
                req.Rewarded = true;
                gm.Save.Gleam += 5;
                gm.Save.Charms += 2;
                gm.Save.Psyche.OnPraise(true);
                gm.Notify();
                ui.Say(who, "That's the one! Here's five gleam and two lumen charms. Your kin looks proud of you.");
                return;
            }
            ui.Say(who, $"Still looking for a {Catalog.Of(req.Species).TitleFor(0)}-line kin. {Habitat(req.Species, 0)}.");
        }

        bool RequestMet(RangerRequest req) =>
            gm.Save.Caught.Exists(c => c.Species == req.Species && c.At >= req.Given);

        string RequestProgress()
        {
            var req = gm.Save.Request;
            return req != null && !req.Rewarded && RequestMet(req) ? " That's today's ranger request done. Go tell Rowan or the lab." : "";
        }

        // ---- Fishing -------------------------------------------------------------------

        IEnumerator Fish()
        {
            minigame = true;
            keeper.Busy = true;
            ui.SetPrompt("");
            ui.Toast("You cast the line... wait for the bite, then press A!");
            float wait = UnityEngine.Random.Range(1.6f, 4.2f), t = 0;
            bool early = false;
            GameInput.ConsumeA();
            while (t < wait)
            {
                if (GameInput.ConsumeA()) { early = true; break; }
                t += Time.deltaTime;
                yield return null;
            }
            bool hooked = false;
            if (!early)
            {
                ProcAudio.I?.Play("confirm", 0.9f, 1.6f);
                ui.SetPrompt("!!");
                ui.Toast("!! Something bites!");
                float window = 0.85f;
                while (window > 0)
                {
                    if (GameInput.ConsumeA()) { hooked = true; break; }
                    window -= Time.deltaTime;
                    yield return null;
                }
            }
            ui.SetPrompt("");
            keeper.Busy = false;
            minigame = false;
            gm.Save.Psyche.OnPlay("fishing", hooked ? 0.8f : 0.1f);
            if (!hooked) { ui.Say("", early ? "You reeled in too soon. Nothing there." : "It got away!"); gm.Notify(); yield break; }
            gm.Save.FishCaught++;
            float roll = UnityEngine.Random.value;
            var zone = GlenMap.ZoneAt(keeper.Cell);
            if (roll < 0.12f)
            {
                // Sometimes it isn't a fish at all.
                Wanderer pick = null;
                foreach (var w in wild) if (!w.Away && !w.Talking) { pick = w; break; }
                if (pick != null)
                {
                    var (_, stage) = WildLife.Pick(zone, wildRng);
                    SetWild(pick, SpeciesId.Marrow, stage);
                    pick.gameObject.SetActive(true);
                    pick.Home = GlenMap.NearestWalkable(keeper.Cell);
                    pick.transform.position = GlenMap.ToWorld(pick.Home);
                    pick.Face(keeper.transform.position);
                    MeetWild(pick, true);
                    yield break;
                }
            }
            if (roll < 0.3f) { gm.Collect($"fish:{DateTime.Now.Ticks}", "gleam", 3); ui.Say("", "A glinting old bottle! Three gleam rattle inside."); }
            else if (roll < 0.45f) { AddFood("milkdrop"); ui.Say("", "A sweet-water clam. That's a milkdrop for the bowl."); }
            else { AddFood("kelpbit"); ui.Say("", $"A wriggling minnow, swapped for kelp. That's fish number {gm.Save.FishCaught}."); }
            if (kin) Fx.Hearts(kin.transform.position);
            gm.Notify();
        }

        void AddFood(string id)
        {
            gm.Save.Bag.TryGetValue(id, out int n);
            gm.Save.Bag[id] = n + 1;
        }

        // ---- Digging -------------------------------------------------------------------

        /// Each day a fresh handful of buried treasures sparkle on sand and snow.
        void BuildDigSites()
        {
            string day = DateTime.Now.ToString("yyyyMMdd");
            if (digDay == day) return;
            digDay = day;
            foreach (var g in digSites.Values) if (g) Destroy(g);
            digSites.Clear();
            var rng = new System.Random(DateTime.Now.DayOfYear * 7919 + DateTime.Now.Year);
            int tries = 0;
            while (digSites.Count < 18 && tries++ < 6000)
            {
                var c = new Vector2Int(rng.Next(2, GlenMap.Width - 2), rng.Next(2, GlenMap.Height - 2));
                var t = GlenMap.At(c.x, c.y);
                if (t is not (Tile.Sand or Tile.Snow or Tile.Dune or Tile.Flowers)) continue;
                if (gm.Save.TakenPickups.Contains(DigKey(c))) continue;
                var mark = GlenBuilder.Make("DigSparkle", world.transform, MeshKit.Blob(1), Mats.Toon(new Color(1f, 0.95f, 0.6f), 0.4f, emission: new Color(1.2f, 1f, 0.4f)));
                mark.transform.position = GlenMap.ToWorld(c) + Vector3.up * 0.15f;
                mark.transform.localScale = new Vector3(0.25f, 0.08f, 0.25f);
                mark.AddComponent<Bob>();
                digSites[c] = mark;
            }
        }

        string DigKey(Vector2Int c) => $"dig:{digDay}:{c.x},{c.y}";
        Vector2Int digTarget;

        bool FindDig()
        {
            BuildDigSites();
            var cell = keeper.Cell;
            foreach (var kv in digSites)
                if ((kv.Key - cell).sqrMagnitude <= 1) { digTarget = kv.Key; return true; }
            return false;
        }

        void Dig()
        {
            if (!digSites.TryGetValue(digTarget, out var mark)) return;
            gm.Save.TakenPickups.Add(DigKey(digTarget));
            digSites.Remove(digTarget);
            if (mark) Destroy(mark);
            if (kin) { kin.Visual.SetPose(KinPose.Cheer); Fx.Sparkle(kin.transform.position, new Color(1f, 0.9f, 0.5f)); }
            gm.Save.Psyche.OnExplore("Explore_New_Tile", 0.7f, true);
            float roll = UnityEngine.Random.value;
            if (roll < 0.25f) { gm.Save.Charms++; ui.Say("", $"{gm.Kin.Name} paws up a buried lumen charm!"); }
            else if (roll < 0.5f) { AddFood("spicecrumb"); ui.Say("", "A sealed tin of spicecrumbs, still crunchy."); }
            else
            {
                int g = UnityEngine.Random.Range(2, 7);
                gm.Save.Gleam += g;
                ui.Say("", $"You dig together and find {g} gleam!");
            }
            gm.Notify();
        }
    }

    public sealed class Bob : MonoBehaviour
    {
        Vector3 start;
        float seed;

        void Start() { start = transform.position; seed = UnityEngine.Random.value * 6f; }

        void Update()
        {
            transform.position = start + Vector3.up * (Mathf.Sin(Time.time * 3f + seed) * 0.05f);
            transform.Rotate(0, 90 * Time.deltaTime, 0);
        }
    }
}
