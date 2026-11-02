using System;
using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// The kin in the world. It follows the Keeper, but every few seconds it asks
    /// SpatialMind what it wants (bowl, berries, friends, nap, explore, a trick), walks
    /// there on the grid, and learns from how it went. Scripted scenes (feeding,
    /// brushing, battle, evolution) take it over through Hold / Release.
    public sealed class KinAgent : MonoBehaviour
    {
        public KeeperController Keeper;
        public CreatureVisual Visual;
        public Func<IReadOnlyList<Transform>> Friends;
        public GlenWorld World;

        public string Thought { get; private set; } = "";
        public string Goal { get; private set; } = "Follow_Keeper";
        public bool Held => held;

        readonly PathMover mover = new() { Speed = 2.7f };
        readonly System.Random rng = new();
        bool held;
        float decideTimer = 6f, doTimer, repathTimer;
        string stateKey = "";
        int goalIndex;
        float goalStarted;
        bool doing;
        Vector2Int goalCell;
        readonly Queue<Vector2Int> recent = new();

        public Vector2Int Cell => GlenMap.ToCell(transform.position);

        public void Rebuild()
        {
            var kin = GameManager.I.Kin;
            if (Visual) Destroy(Visual.gameObject);
            Visual = CreatureVisual.Create(transform, kin.Species, kin.Stage);
        }

        public void Place(Vector2Int c) => transform.position = GlenMap.ToWorld(c);

        public void Hold()
        {
            held = true;
            mover.Stop();
            doing = false;
            Thought = "";
        }

        public void Release()
        {
            held = false;
            decideTimer = 4f;
            Goal = "Follow_Keeper";
        }

        public void WalkTo(Vector2Int cell) => mover.SetPath(Cell, cell);
        public bool Arrived => !mover.Moving && !mover.Hopping;

        public void Face(Vector3 worldPoint)
        {
            var d = worldPoint - transform.position;
            d.y = 0;
            if (d.sqrMagnitude > 0.001f) transform.rotation = Quaternion.LookRotation(d);
        }

        void Update()
        {
            var gm = GameManager.I;
            if (gm == null || !gm.HasGame || Visual == null) return;
            float dt = Time.deltaTime;
            var kin = gm.Kin;

            var dir = mover.Tick(transform, dt);
            if (dir.sqrMagnitude > 0.01f)
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(dir), 1 - Mathf.Exp(-dt * 10f));

            if (held)
            {
                if (mover.Moving) Visual.SetPose(KinPose.Walk);
                return;
            }

            if (kin.Asleep)
            {
                mover.Stop();
                Visual.SetPose(KinPose.Sleep);
                Thought = "zzz";
                return;
            }

            if (doing)
            {
                doTimer -= dt;
                if (doTimer <= 0) FinishGoal();
                return;
            }

            if (mover.Moving) Visual.SetPose(KinPose.Walk);
            else
            {
                // Body language follows the loudest feeling.
                var feel = gm.Save.Psyche.Dominant;
                Visual.SetPose(feel is Emotion.Frustration or Emotion.Anxiety || kin.MoodAt(DateTime.Now) == Mood.Sulking ? KinPose.Sulk : KinPose.Idle);
                if (feel == Emotion.Excitement && UnityEngine.Random.value < dt * 0.4f) Visual.Hop(0.3f);
            }

            if (Goal == "Follow_Keeper") Follow(dt);
            else if (!mover.Moving && !mover.Hopping) ArriveAtGoal();
            else if (Time.time - goalStarted > 25f) FinishGoal(); // gave up

            decideTimer -= dt;
            if (decideTimer <= 0 && Goal == "Follow_Keeper") Decide();
        }

        void Follow(float dt)
        {
            if (!Keeper) return;
            float dist = Vector3.Distance(transform.position, Keeper.transform.position);
            repathTimer -= dt;
            mover.Speed = dist > 4f ? 4.6f : 2.9f;
            if (dist > 1.9f && repathTimer <= 0)
            {
                repathTimer = 0.4f;
                var behind = GlenMap.ToCell(Keeper.transform.position - Keeper.Forward * 1.1f);
                if (!GlenMap.Walkable(behind.x, behind.y)) behind = Keeper.Cell;
                mover.SetPath(Cell, behind);
                if (mover.Path.Count > 1) mover.Path.RemoveAt(mover.Path.Count - 1);
            }
            else if (dist < 1.2f) mover.Stop();
            if (dist > 14f) Place(GlenMap.NearestWalkable(Keeper.Cell)); // lost: catch up
            if (!mover.Moving && dist < 2.5f) Face(Keeper.transform.position);
        }

        // ---- SpatialMind loop ----------------------------------------------------------

        string NearbyTag()
        {
            var fr = Friends?.Invoke();
            if (fr != null)
                foreach (var f in fr)
                    if (f && Vector3.Distance(f.position, transform.position) < 4f) return "friend";
            if (Keeper && Vector3.Distance(Keeper.transform.position, transform.position) < 3f) return "keeper";
            return "none";
        }

        void Decide()
        {
            var gm = GameManager.I;
            var kin = gm.Kin;
            decideTimer = 9f + (float)rng.NextDouble() * 8f;
            stateKey = SpatialMind.KeyFor(Catalog.PhaseAt(DateTime.Now), kin.Satiation, kin.Energy, kin.Joy, GlenMap.ZoneAt(Cell), NearbyTag());
            goalIndex = SpatialMind.Choose(gm.Save.SpatialQ, stateKey, gm.Save.SpatialCounts, kin.Satiation, kin.Energy, kin.Joy, rng, gm.Save.SpatialSteps, gm.Save.Mind("spatial"));
            gm.Save.SpatialSteps++;
            Goal = SpatialMind.Goals[goalIndex];
            Thought = SpatialMind.ThoughtFor(Goal);
            goalStarted = Time.time;
            goalCell = TargetFor(Goal);
            if (Goal == "Follow_Keeper" || Goal == "Perform_Trick") { ArriveAtGoal(); return; }
            mover.Speed = 2.6f;
            mover.SetPath(Cell, goalCell);
            if (mover.Path.Count == 0) ArriveAtGoal();
        }

        Vector2Int TargetFor(string goal)
        {
            switch (goal)
            {
                case "GoTo_FoodBowl": return GlenMap.Buildings[2].Door;
                case "Rest_At_House": return GlenMap.Buildings[0].Door + Vector2Int.right;
                case "Play_At_Shed": return GlenMap.Buildings[1].Door + Vector2Int.left;
                case "Forage_BerryBush":
                {
                    Vector2Int best = Cell;
                    float bestD = float.MaxValue;
                    foreach (var s in GlenMap.Spots)
                    {
                        if (s.Kind != "berrybush") continue;
                        float d = Vector2Int.Distance(Cell, s.Cell);
                        if (d < bestD) { bestD = d; best = GlenMap.NearestWalkable(s.Cell + Vector2Int.up); }
                    }
                    return best;
                }
                case "Visit_AnimalFriend":
                {
                    var fr = Friends?.Invoke();
                    if (fr != null && fr.Count > 0)
                    {
                        var f = fr[rng.Next(fr.Count)];
                        if (f) return GlenMap.NearestWalkable(GlenMap.ToCell(f.position) + Vector2Int.left);
                    }
                    return Cell;
                }
                case "Explore_New_Tile":
                {
                    for (int i = 0; i < 20; i++)
                    {
                        var c = Cell + new Vector2Int(rng.Next(-9, 10), rng.Next(-9, 10));
                        if (GlenMap.Walkable(c.x, c.y) && !recent.Contains(c)) return c;
                    }
                    return Cell;
                }
                default: return Cell;
            }
        }

        void ArriveAtGoal()
        {
            doing = true;
            var kin = GameManager.I.Kin;
            switch (Goal)
            {
                case "GoTo_FoodBowl":
                    if (World && World.BowlFood) Face(World.BowlFood.position);
                    Visual.SetPose(KinPose.Eat);
                    doTimer = 3f;
                    break;
                case "Forage_BerryBush":
                    Visual.SetPose(KinPose.Eat);
                    doTimer = 2.5f;
                    break;
                case "Rest_At_House":
                    doTimer = kin.Energy < 45 ? 8f : 2f;
                    Visual.SetPose(kin.Energy < 45 ? KinPose.Sleep : KinPose.Idle);
                    break;
                case "Perform_Trick":
                    if (Keeper) Face(Keeper.transform.position);
                    Visual.Spin();
                    Visual.Hop(0.45f);
                    ProcAudio.I?.Chirp(kin.Species, 1.2f);
                    doTimer = 1.4f;
                    break;
                case "Visit_AnimalFriend":
                    Visual.SetPose(KinPose.Hop);
                    ProcAudio.I?.Chirp(kin.Species, 1.1f);
                    doTimer = 2.5f;
                    break;
                case "Play_At_Shed":
                    Visual.SetPose(KinPose.Hop);
                    doTimer = 2.2f;
                    break;
                case "Follow_Keeper":
                    doTimer = 0.1f;
                    break;
                default:
                    Visual.SetPose(KinPose.Idle);
                    doTimer = 1.2f;
                    break;
            }
        }

        void FinishGoal()
        {
            doing = false;
            var gm = GameManager.I;
            var kin = gm.Kin;
            float reward = 0f;
            bool nearKeeper = Keeper && Vector3.Distance(Keeper.transform.position, transform.position) < 4f;
            switch (Goal)
            {
                case "GoTo_FoodBowl":
                    reward = kin.Satiation < 55 ? 0.7f : -0.15f;
                    kin.Satiation = Catalog.ClampStat(kin.Satiation + 5);
                    break;
                case "Forage_BerryBush":
                {
                    string key = $"forage:{DateTime.Now:yyyyMMdd}:{goalCell}";
                    if (!gm.Save.TakenPickups.Contains(key) && rng.NextDouble() < 0.6)
                    {
                        gm.Collect(key, "sunberry");
                        gm.Say($"{kin.Name} found a sunberry and brought it to you!");
                        reward = 0.8f;
                    }
                    else reward = 0.05f;
                    break;
                }
                case "Visit_AnimalFriend":
                    reward = 0.2f + (100 - kin.Joy) / 160f;
                    kin.Joy = Catalog.ClampStat(kin.Joy + 3);
                    break;
                case "Rest_At_House":
                    reward = kin.Energy < 45 ? 0.8f : -0.2f;
                    if (kin.Energy < 45) kin.Energy = Catalog.ClampStat(kin.Energy + 10);
                    break;
                case "Perform_Trick":
                    reward = nearKeeper ? 0.55f : -0.05f;
                    break;
                case "Play_At_Shed":
                    reward = kin.Energy > 30 ? 0.3f : -0.2f;
                    kin.Joy = Catalog.ClampStat(kin.Joy + 2);
                    kin.Energy = Catalog.SoftFloor(kin.Energy - 2);
                    break;
                case "Explore_New_Tile":
                    reward = 0.1f;
                    recent.Enqueue(Cell);
                    if (recent.Count > 12) recent.Dequeue();
                    break;
                case "Follow_Keeper":
                    reward = nearKeeper ? 0.25f : 0f;
                    break;
            }
            if (!string.IsNullOrEmpty(stateKey))
            {
                string countKey = $"{stateKey}#{goalIndex}";
                gm.Save.SpatialCounts.TryGetValue(countKey, out int visits);
                gm.Save.SpatialCounts[countKey] = visits + 1;
                string next = SpatialMind.KeyFor(Catalog.PhaseAt(DateTime.Now), kin.Satiation, kin.Energy, kin.Joy, GlenMap.ZoneAt(Cell), NearbyTag());
                // The feeling of the outing is part of the reward the map policy learns from.
                reward += gm.Save.Psyche.OnExplore(Goal, reward, visits == 0) * 2f;
                SpatialMind.Learn(gm.Save.SpatialQ, stateKey, goalIndex, reward, next, visits, gm.Save.Mind("spatial"));
            }
            gm.Notify();
            Goal = "Follow_Keeper";
            Thought = "";
        }
    }

    /// Villagers and wandering friend-kin: idle, amble around home, face whoever talks.
    public sealed class Wanderer : MonoBehaviour
    {
        public string Id, DisplayName;
        public string[] Lines = Array.Empty<string>();
        public Vector2Int Home;
        public float Range = 3;
        public ChibiCharacter Human;
        public CreatureVisual Creature;
        /// Wild kin: roam tall grass, can be sparred or befriended, then slip away for a while.
        public bool Wild;
        public bool Away;
        public SpeciesId Species;
        public int Stage;
        readonly PathMover mover = new() { Speed = 1.5f };
        float wait;
        int line;
        public bool Talking;

        void Start() => wait = UnityEngine.Random.Range(1f, 5f);

        public string NextLine()
        {
            if (Lines.Length == 0) return "...";
            var l = Lines[line % Lines.Length];
            line++;
            return l;
        }

        void Update()
        {
            float dt = Time.deltaTime;
            if (Talking) { mover.Stop(); SetSpeed(0); return; }
            var dir = mover.Tick(transform, dt);
            if (dir.sqrMagnitude > 0.01f)
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(dir), 1 - Mathf.Exp(-dt * 8f));
            SetSpeed(mover.Moving ? 0.35f : 0);
            if (mover.Moving) return;
            wait -= dt;
            if (wait > 0) return;
            wait = UnityEngine.Random.Range(3f, 8f);
            // Wild kin keep to cover: they only pick tall grass to wander to.
            for (int tries = 0; tries < (Wild ? 6 : 1); tries++)
            {
                var c = Home + new Vector2Int(UnityEngine.Random.Range(-(int)Range, (int)Range + 1), UnityEngine.Random.Range(-(int)Range, (int)Range + 1));
                if (!GlenMap.Walkable(c.x, c.y)) continue;
                if (Wild && GlenMap.At(c.x, c.y) != Tile.TallGrass) continue;
                mover.SetPath(GlenMap.ToCell(transform.position), c);
                break;
            }
        }

        void SetSpeed(float s)
        {
            if (Human) Human.Speed01 = s;
            if (Creature) Creature.SetPose(s > 0 ? KinPose.Walk : KinPose.Idle);
        }

        public void Face(Vector3 p)
        {
            var d = p - transform.position;
            d.y = 0;
            if (d.sqrMagnitude > 0.001f) transform.rotation = Quaternion.LookRotation(d);
        }
    }
}
