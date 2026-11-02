using System;
using System.Collections.Generic;

namespace LuminaVale
{
    public static class QTable
    {
        public static float[] Row(Dictionary<string, float[]> table, string key, int width) =>
            table.TryGetValue(key, out var row) && row.Length == width ? row : new float[width];

        public static float Max(float[] row)
        {
            float m = row[0];
            foreach (var v in row) if (v > m) m = v;
            return m;
        }

        public static int ArgMax(IReadOnlyList<float> row)
        {
            int best = 0;
            for (int i = 1; i < row.Count; i++) if (row[i] > row[best]) best = i;
            return best;
        }
    }

    [Serializable]
    public sealed class Transition
    {
        public string S, S2;
        public int A;
        public float R;
        /// How surprising this lesson was last time (|TD error|); surprising ones replay more.
        public float P = 1f;
    }

    /// Per-mind learning bookkeeping: visit counts per state-action and a small replay buffer.
    [Serializable]
    public sealed class MindMemory
    {
        public Dictionary<string, int> Visits = new();
        public List<Transition> Replay = new();
        public int Updates;
    }

    /// The shared, sturdier Q-learning step every mind uses:
    ///  - rewards are clipped and NaN-guarded so one odd event can't wreck a table,
    ///  - the step size shrinks per state-action as it gets visited (1/sqrt(n) schedule),
    ///  - a coarse "backoff" state learns alongside, so brand-new states start from what
    ///    similar states taught instead of from zero,
    ///  - a few past transitions are replayed each step so rare lessons aren't forgotten.
    public static class QCore
    {
        public const int ReplayCap = 96, ReplayPerStep = 3, TableCap = 3000;
        public const float RewardClip = 2.5f, MinAlpha = 0.06f;
        static readonly Random rng = new(1234);

        public static string Coarse(string key, params int[] keep)
        {
            var parts = key.Split('|');
            var picked = new List<string>();
            foreach (int i in keep) if (i < parts.Length) picked.Add(parts[i]);
            return "~" + string.Join("|", picked);
        }

        public static int Visits(MindMemory mem, string key, int action) =>
            mem != null && mem.Visits.TryGetValue($"{key}#{action}", out int n) ? n : 0;

        public static int StateVisits(MindMemory mem, string key, int width)
        {
            int t = 0;
            for (int a = 0; a < width; a++) t += Visits(mem, key, a);
            return t;
        }

        /// One TD update; returns the TD error so replay can prioritise surprises.
        static float Step(Dictionary<string, float[]> table, int width, string s, int a, float r, string s2, float alpha, float gamma)
        {
            var row = (float[])QTable.Row(table, s, width).Clone();
            float maxNext = s2 == null ? 0 : QTable.Max(QTable.Row(table, s2, width));
            float td = r + gamma * maxNext - row[a];
            row[a] = Math.Clamp(row[a] + alpha * td, -2f, 3f);
            table[s] = row;
            return td;
        }

        public static void Learn(Dictionary<string, float[]> table, int width, string s, int a, float r, string s2,
            float alphaBase, float gamma, MindMemory mem, string coarseS = null, string coarseS2 = null)
        {
            if (float.IsNaN(r) || float.IsInfinity(r)) r = 0;
            r = Math.Clamp(r, -RewardClip, RewardClip);
            a = Math.Clamp(a, 0, width - 1);
            int n = 0;
            if (mem != null)
            {
                string vk = $"{s}#{a}";
                mem.Visits.TryGetValue(vk, out n);
                mem.Visits[vk] = n + 1;
                mem.Updates++;
            }
            float alpha = Math.Max(MinAlpha, alphaBase / (float)Math.Sqrt(1 + n * 0.25f));
            float tdErr = Step(table, width, s, a, r, s2, alpha, gamma);
            if (coarseS != null) Step(table, width, coarseS, a, r, coarseS2 ?? coarseS, alpha * 0.5f, gamma);
            if (mem == null) return;

            for (int i = 0; i < ReplayPerStep && mem.Replay.Count > 0; i++)
            {
                // Tournament of two: the more surprising memory gets replayed.
                var t1 = mem.Replay[rng.Next(mem.Replay.Count)];
                var t2 = mem.Replay[rng.Next(mem.Replay.Count)];
                var t = t1.P >= t2.P ? t1 : t2;
                t.P = Math.Abs(Step(table, width, t.S, Math.Clamp(t.A, 0, width - 1), t.R, t.S2, alpha * 0.5f, gamma)) + 0.05f;
            }
            mem.Replay.Add(new Transition { S = s, A = a, R = r, S2 = s2, P = Math.Abs(tdErr) + 0.05f });
            if (mem.Updates % 200 == 0 && table.Count > TableCap) Prune(table, width, mem);
            if (mem.Replay.Count > ReplayCap) mem.Replay.RemoveAt(rng.Next(mem.Replay.Count / 2));
        }

        /// Keeps tables bounded over years of play: forgets the least-visited exact states
        /// (their coarse backoffs remain, so nothing is learned from scratch again).
        public static void Prune(Dictionary<string, float[]> table, int width, MindMemory mem)
        {
            var keys = new List<string>(table.Keys);
            keys.RemoveAll(k => k.StartsWith("~"));
            keys.Sort((x, y) => StateVisits(mem, x, width).CompareTo(StateVisits(mem, y, width)));
            int drop = table.Count - TableCap * 9 / 10;
            for (int i = 0; i < drop && i < keys.Count; i++)
            {
                table.Remove(keys[i]);
                for (int a = 0; a < width; a++) mem.Visits.Remove($"{keys[i]}#{a}");
            }
        }

        /// Values for a state, blended toward the coarse backoff while the state is new.
        public static float[] Values(Dictionary<string, float[]> table, int width, string s, string coarse, MindMemory mem)
        {
            var exact = QTable.Row(table, s, width);
            if (coarse == null) return exact;
            var back = QTable.Row(table, coarse, width);
            bool seen = table.ContainsKey(s);
            float w = mem != null ? Math.Min(1f, StateVisits(mem, s, width) / 4f) : seen ? 1f : 0f;
            var v = new float[width];
            for (int i = 0; i < width; i++) v[i] = exact[i] * w + back[i] * (1 - w);
            return v;
        }

        /// Boltzmann choice: better options win more often, but close calls stay varied.
        public static int Softmax(float[] scores, float temperature, Random r)
        {
            float t = Math.Max(0.02f, temperature);
            float max = QTable.Max(scores);
            var p = new double[scores.Length];
            double sum = 0;
            for (int i = 0; i < scores.Length; i++) { p[i] = Math.Exp((scores[i] - max) / t); sum += p[i]; }
            double roll = r.NextDouble() * sum;
            for (int i = 0; i < p.Length; i++) { roll -= p[i]; if (roll <= 0) return i; }
            return p.Length - 1;
        }
    }

    /// Port of BondMind (lib/vale/learning.dart): tabular Q-learning over what the kin asks for.
    public static class BondMind
    {
        public static readonly string[] Actions = { "meal", "play", "brush", "nap", "trick", "wander" };
        public const float Alpha = 0.34f, Gamma = 0.82f;

        public static int IndexOf(string action) => Math.Max(0, Array.IndexOf(Actions, action));

        public static int Bin(float v) => v < 34 ? 0 : v < 67 ? 1 : 2;

        public static string KeyFor(Kin kin, DateTime now) =>
            $"{Catalog.PhaseAt(now).ToString().ToLowerInvariant()}|{Bin(kin.Satiation)}|{Bin(kin.Energy)}|{Bin(kin.Joy)}|{Bin(kin.Coat)}|{Bin(kin.Bond)}|{kin.LastCare}";

        public static float[] Instinct(Kin kin, DayPhase phase, string nature)
        {
            float trick = nature == "duskwit" && (phase == DayPhase.Dusk || phase == DayPhase.Night) ? 0.5f : 0.06f;
            float wander = nature == "brightforage" ? 0.28f : 0.12f;
            float play = nature == "dawnbound" && phase == DayPhase.Dawn ? 0.35f : 0f;
            float brush = nature == "hearthful" ? 0.22f : 0f;
            return new[]
            {
                (100 - kin.Satiation) / 55f,
                (kin.Energy > 26 ? (100 - kin.Joy) / 90f : 0.05f) + play,
                (100 - kin.Coat) / 60f + brush,
                (100 - kin.Energy) / 50f,
                kin.Bond / 140f + trick,
                wander,
            };
        }

        /// Backoff state: time of day plus hunger and energy only.
        public static string CoarseKey(string key) => QCore.Coarse(key, 0, 1, 2);

        public static void Learn(Dictionary<string, float[]> table, string stateKey, int action, float reward, string nextKey, MindMemory mem = null) =>
            QCore.Learn(table, Actions.Length, stateKey, action, reward, nextKey, Alpha, Gamma, mem,
                mem != null ? CoarseKey(stateKey) : null, mem != null ? CoarseKey(nextKey) : null);

        public static float Curiosity(int steps) => Math.Clamp(0.4f * (float)Math.Pow(0.97, steps), 0.07f, 0.4f);

        public static int Choose(Dictionary<string, float[]> table, string stateKey, Kin kin, int steps, string anticipatedBid, Random rng, MindMemory mem = null)
        {
            // A small flat-random floor, then softmax over learned value + instinct.
            if (rng.NextDouble() < Curiosity(steps) * 0.35f) return rng.Next(Actions.Length);
            var learned = QCore.Values(table, Actions.Length, stateKey, CoarseKey(stateKey), mem);
            var gut = Instinct(kin, Catalog.PhaseAt(DateTime.Now), kin.Nature);
            float fade = steps < 6 ? 0.9f : steps < 18 ? 0.45f : 0.22f;
            var scores = new float[Actions.Length];
            for (int i = 0; i < scores.Length; i++)
            {
                scores[i] = learned[i] + gut[i] * fade;
                if (anticipatedBid != null && Actions[i] == anticipatedBid) scores[i] += 0.72f;
            }
            return QCore.Softmax(scores, 0.12f + Curiosity(steps) * 0.6f, rng);
        }

        public static float ResponseReward(string bid, string action, float satiation, float energy, float coat)
        {
            if (action == "ignore") return -0.38f;
            if (bid == "meal" && action == "feed") return satiation < 40 ? 1.45f : satiation < 75 ? 0.62f : -0.22f;
            if (bid == "play" && action == "play") return energy > 22 ? 1.22f : 0.3f;
            if (bid == "brush" && action == "groom") return coat < 55 ? 1.28f : 0.74f;
            if (bid == "nap" && action == "rest") return energy < 48 ? 1.36f : 0.12f;
            if (bid == "trick" && action == "praise") return 1.05f;
            if (bid == "wander" && action == "outing") return 1.16f;
            if (action == "feed" && satiation > 86) return -0.45f;
            return -0.28f;
        }

        public static readonly Dictionary<string, string> CareToBid = new()
        {
            ["feed"] = "meal", ["play"] = "play", ["groom"] = "brush", ["rest"] = "nap",
        };
    }

    /// Port of RoutineModel: a 24-hour histogram of what the keeper actually does.
    [Serializable]
    public sealed class RoutineModel
    {
        public static readonly string[] Labels = { "feed", "play", "groom", "rest" };
        public float[][] Counts = { new float[24], new float[24], new float[24], new float[24] };

        public int Total
        {
            get { float s = 0; foreach (var r in Counts) foreach (var v in r) s += v; return (int)Math.Round(s); }
        }

        public void Observe(string action, int hour)
        {
            int i = Array.IndexOf(Labels, action);
            if (i >= 0) Counts[i][Math.Clamp(hour, 0, 23)] += 1;
        }

        public string Anticipate(int hour)
        {
            if (Total < 4) return null;
            int h = Math.Clamp(hour, 0, 23);
            int best = 0;
            float bestCount = Counts[0][h], hourSum = 0;
            for (int i = 0; i < Counts.Length; i++)
            {
                hourSum += Counts[i][h];
                if (Counts[i][h] > bestCount) { best = i; bestCount = Counts[i][h]; }
            }
            if (bestCount < 2) return null;
            float smoothed = (bestCount + 0.4f) / (hourSum + 1.6f);
            return smoothed < 0.4f ? null : Labels[best];
        }
    }

    /// Port of MoveMind: learns which spar move works against which rival.
    public static class MoveMind
    {
        public const float Alpha = 0.3f, Gamma = 0.75f;

        public static string KeyFor(KinElement foe, float staminaFraction, string lastFoeKind)
        {
            int bin = staminaFraction < 0.34f ? 0 : staminaFraction < 0.67f ? 1 : 2;
            return $"{foe.ToString().ToLowerInvariant()}|{bin}|{lastFoeKind}";
        }

        /// Backoff state: just the rival's element, so lessons carry across stamina levels.
        public static string CoarseKey(string key) => QCore.Coarse(key, 0);

        public static void Learn(Dictionary<string, float[]> table, string stateKey, int action, float reward, string nextKey, MindMemory mem = null) =>
            QCore.Learn(table, 3, stateKey, action, reward, nextKey, Alpha, Gamma, mem,
                mem != null ? CoarseKey(stateKey) : null, mem != null ? CoarseKey(nextKey) : null);

        public static int Suggest(Dictionary<string, float[]> table, string stateKey, MindMemory mem = null)
        {
            var row = mem != null ? QCore.Values(table, 3, stateKey, CoarseKey(stateKey), mem) : QTable.Row(table, stateKey, 3);
            bool allZero = true;
            foreach (var v in row) if (Math.Abs(v) > 0.001f) allZero = false;
            return allZero ? 0 : QTable.ArgMax(row);
        }
    }

    /// Port of SpatialMind (lib/ml/spatial_mind.dart): where the kin wants to go on the map,
    /// with a curiosity bonus for unvisited state-action pairs.
    public static class SpatialMind
    {
        public static readonly string[] Goals =
        {
            "GoTo_FoodBowl", "Forage_BerryBush", "Visit_AnimalFriend", "Follow_Keeper",
            "Play_At_Shed", "Rest_At_House", "Explore_New_Tile", "Perform_Trick",
        };
        public const float Alpha = 0.28f, Gamma = 0.8f, CuriosityScale = 0.55f;

        public static int IndexOf(string goal) => Math.Max(0, Array.IndexOf(Goals, goal));
        public static int Bin(float v) => v < 34 ? 0 : v < 67 ? 1 : 2;

        public static string KeyFor(DayPhase phase, float hunger, float energy, float social, string zone, string nearby) =>
            $"{phase.ToString().ToLowerInvariant()}|{Bin(hunger)}|{Bin(energy)}|{Bin(social)}|{zone}|{nearby}";

        public static float Intrinsic(int count) => CuriosityScale / (float)Math.Sqrt(count + 1);

        /// Backoff state: hunger, energy and zone.
        public static string CoarseKey(string key) => QCore.Coarse(key, 1, 2, 4);

        public static void Learn(Dictionary<string, float[]> table, string stateKey, int action, float reward, string nextKey, int visits, MindMemory mem = null) =>
            QCore.Learn(table, Goals.Length, stateKey, action, reward + Intrinsic(visits), nextKey, Alpha, Gamma, mem,
                mem != null ? CoarseKey(stateKey) : null, mem != null ? CoarseKey(nextKey) : null);

        public static int Choose(Dictionary<string, float[]> table, string stateKey, Dictionary<string, int> counts,
            float hunger, float energy, float social, Random rng, int steps, MindMemory mem = null)
        {
            float epsilon = Math.Clamp(0.35f * (float)Math.Pow(0.985, steps), 0.08f, 0.35f);
            if (rng.NextDouble() < epsilon * 0.4f) return rng.Next(Goals.Length);
            var learned = QCore.Values(table, Goals.Length, stateKey, CoarseKey(stateKey), mem);
            var scores = new float[Goals.Length];
            for (int i = 0; i < Goals.Length; i++)
            {
                counts.TryGetValue($"{stateKey}#{i}", out int c);
                float drive = learned[i] + Intrinsic(c);
                if (Goals[i] == "GoTo_FoodBowl") drive += (100 - hunger) / 80f;
                if (Goals[i] == "Rest_At_House") drive += (100 - energy) / 90f;
                if (Goals[i] == "Visit_AnimalFriend") drive += (100 - social) / 120f;
                scores[i] = drive;
            }
            return QCore.Softmax(scores, 0.1f + epsilon * 0.5f, rng);
        }

        public static string ThoughtFor(string goal) => goal switch
        {
            "GoTo_FoodBowl" or "Forage_BerryBush" => "berry",
            "Visit_AnimalFriend" or "Follow_Keeper" => "heart",
            "Play_At_Shed" => "ball",
            "Rest_At_House" => "zzz",
            "Perform_Trick" => "note",
            _ => "?",
        };
    }
}
