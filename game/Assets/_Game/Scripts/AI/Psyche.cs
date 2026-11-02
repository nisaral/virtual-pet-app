using System;
using System.Collections.Generic;

namespace LuminaVale
{
    public enum Emotion { Joy, Trust, Contentment, Excitement, Pride, Loneliness, Frustration, Anxiety, Boredom }

    /// Learns the typical gap between two kinds of event (feeding, visits) as a running mean
    /// and variance, so "on time", "late" and "erratic" are judged against *your* habits.
    [Serializable]
    public sealed class Rhythm
    {
        public double MeanHours = 4, VarHours = 4;
        public DateTime? Last;
        public int Count;

        /// Returns how surprising this gap was: 0 = exactly as expected, + = later, - = earlier (in std devs).
        public float Observe(DateTime now)
        {
            if (Last == null) { Last = now; Count = 1; return 0; }
            double gap = Math.Max(0.01, (now - Last.Value).TotalHours);
            Last = now;
            double z = (gap - MeanHours) / Math.Sqrt(Math.Max(0.25, VarHours));
            double a = Count < 6 ? 0.35 : 0.12;   // learns fast at first, then settles
            double d = gap - MeanHours;
            MeanHours += a * d;
            VarHours = (1 - a) * (VarHours + a * d * d);
            Count++;
            return (float)Math.Clamp(z, -3, 3);
        }

        /// How overdue the next event is right now, in std devs (0 while still on time).
        public float Overdue(DateTime now)
        {
            if (Last == null) return 0;
            double gap = (now - Last.Value).TotalHours;
            return (float)Math.Max(0, (gap - MeanHours) / Math.Sqrt(Math.Max(0.25, VarHours)));
        }

        /// 0..1, how consistent the keeper is (low variance relative to the mean).
        public float Regularity => Count < 3 ? 0.5f : (float)Math.Clamp(1 - Math.Sqrt(VarHours) / Math.Max(0.5, MeanHours), 0, 1);
    }

    /// One domain of growth. Credit is earned from positive reward, weighted by how much the
    /// kin is *learning* there (its prediction error falling), so grinding the same easy thing
    /// earns less and less, while genuinely new experience grows it.
    [Serializable]
    public sealed class CreditBank
    {
        public float Credit;
        public float ErrFast = 1, ErrSlow = 1;   // EMAs of |reward prediction error|
        public float Expected;                   // learned average reward in this domain
        public int Events;

        public float Competence => Math.Clamp(1 - ErrFast, 0, 1);

        public float Learn(float reward)
        {
            float err = reward - Expected;
            Expected += 0.15f * err;
            float a = Math.Abs(err);
            ErrFast += 0.3f * (a - ErrFast);
            ErrSlow += 0.05f * (a - ErrSlow);
            float progress = Math.Max(0, ErrSlow - ErrFast);              // learning progress
            float surprise = Math.Min(1, a);                                // still something to learn
            float novelty = 1f / (1 + Events * 0.1f);                       // habituation
            float gain = Math.Max(0, reward) * (0.3f + 2.5f * progress + 0.7f * surprise) * (0.25f + 0.75f * novelty);
            Credit += gain;
            Events++;
            return gain;
        }
    }

    /// The kin's inner life. Nine emotions driven by appraisal of what happens, each decaying
    /// toward a temperament that itself drifts with long-term experience. The change in
    /// emotional valence is the reward signal for every learner (bids, roaming, battle), and
    /// growth comes from credit earned across five reward domains instead of XP levels.
    [Serializable]
    public sealed class Psyche
    {
        public const int Count = 9;
        public float[] E = { 0.55f, 0.3f, 0.5f, 0.4f, 0.2f, 0.2f, 0.1f, 0.2f, 0.25f };
        public float[] Temperament = { 0.5f, 0.3f, 0.5f, 0.4f, 0.2f, 0.15f, 0.1f, 0.15f, 0.2f };
        public Rhythm Feeding = new();
        public Rhythm Visits = new();
        public Dictionary<string, CreditBank> Banks = new()
        {
            ["care"] = new CreditBank(), ["play"] = new CreditBank(), ["battle"] = new CreditBank(),
            ["explore"] = new CreditBank(), ["wellbeing"] = new CreditBank(),
        };
        public Dictionary<string, float> MoveSkill = new();      // learned per-move effectiveness
        public Dictionary<string, int> RecentActs = new();       // habituation counters
        public float WellbeingClock;
        public int Wins, Losses;

        // Valence weights: how each emotion counts toward "feeling good".
        static readonly float[] Valence = { 1.0f, 0.8f, 0.7f, 0.4f, 0.5f, -0.8f, -0.9f, -0.8f, -0.4f };
        // Hours for an emotion to fall halfway back to temperament.
        static readonly float[] HalfLife = { 2f, 30f, 4f, 0.8f, 6f, 8f, 1.5f, 3f, 3f };

        public static readonly Emotion[] All = (Emotion[])Enum.GetValues(typeof(Emotion));

        public float this[Emotion e]
        {
            get => E[(int)e];
            set => E[(int)e] = Math.Clamp(value, 0, 1);
        }

        public float ValenceNow
        {
            get { float v = 0; for (int i = 0; i < Count; i++) v += Valence[i] * E[i]; return v; }
        }

        public Emotion Dominant
        {
            get
            {
                // Strongest deviation above temperament: the feeling that is "loud" right now.
                int best = 0;
                float bestScore = float.MinValue;
                for (int i = 0; i < Count; i++)
                {
                    float s = E[i] - Temperament[i] * 0.6f;
                    if (s > bestScore) { bestScore = s; best = i; }
                }
                return (Emotion)best;
            }
        }

        // ---- Growth --------------------------------------------------------------------

        static readonly Dictionary<string, float> BankWeight = new()
        {
            ["care"] = 1.0f, ["play"] = 0.8f, ["battle"] = 0.8f, ["explore"] = 0.6f, ["wellbeing"] = 1.2f,
        };

        public float Growth
        {
            get { float g = 0; foreach (var kv in Banks) g += kv.Value.Credit * BankWeight[kv.Key]; return g; }
        }

        public static readonly float[] StageThreshold = { 6f, 18f };

        /// Evolution needs enough growth *and* a settled, trusting kin; a frightened or
        /// neglected kin does not grow up, however much it has done.
        public bool ReadyFor(int stage)
        {
            if (stage >= 2) return false;
            return Growth >= StageThreshold[stage]
                && this[Emotion.Trust] >= (stage == 0 ? 0.4f : 0.55f)
                && ValenceNow > 0.35f
                && this[Emotion.Anxiety] < 0.55f;
        }

        public float GrowthToNext(int stage) => stage >= 2 ? 1 : Math.Clamp(Growth / StageThreshold[stage], 0, 1);

        /// Replaces the old level for anything that scales with experience (battle stamina).
        public float Experience => (float)Math.Sqrt(Growth);

        // ---- Time ---------------------------------------------------------------------

        public void Tick(float hours, Kin kin, DateTime now)
        {
            if (hours <= 0) return;
            for (int i = 0; i < Count; i++)
            {
                float k = 1 - (float)Math.Pow(0.5, hours / HalfLife[i]);
                E[i] += (Temperament[i] - E[i]) * k;
            }
            // Needs leak into feelings.
            float hunger = (100 - kin.Satiation) / 100f;
            this[Emotion.Anxiety] += hours * (Math.Max(0, hunger - 0.5f) * 0.6f + Feeding.Overdue(now) * 0.05f);
            this[Emotion.Contentment] -= hours * Math.Max(0, hunger - 0.4f) * 0.4f;
            this[Emotion.Loneliness] += hours * (0.03f + Visits.Overdue(now) * 0.04f);
            this[Emotion.Boredom] += hours * 0.05f;
            if (kin.Energy < 25) this[Emotion.Frustration] += hours * 0.08f;

            // Temperament drifts toward lived experience: about a week to reshape a personality.
            float drift = 1 - (float)Math.Pow(0.5, hours / 72f);
            for (int i = 0; i < Count; i++) Temperament[i] += (E[i] * 0.8f + 0.1f - Temperament[i]) * drift;

            // Wellbeing pays out slowly while the kin feels good.
            WellbeingClock += hours;
            if (WellbeingClock >= 0.25f)
            {
                Banks["wellbeing"].Learn(Math.Max(-1, ValenceNow - 0.4f) * WellbeingClock * 2);
                WellbeingClock = 0;
            }
        }

        // ---- Appraisal ----------------------------------------------------------------

        /// Apply deltas, return the reward = change in valence (what every learner optimises).
        float Feel(params (Emotion e, float d)[] deltas)
        {
            float before = ValenceNow;
            foreach (var (e, d) in deltas) this[e] += d;
            return ValenceNow - before;
        }

        float Habituation(string act)
        {
            RecentActs.TryGetValue(act, out int n);
            RecentActs[act] = n + 1;
            // Decay the other counters so variety resets boredom.
            var keys = new List<string>(RecentActs.Keys);
            foreach (var k in keys) if (k != act) RecentActs[k] = Math.Max(0, RecentActs[k] - 1);
            return 1f / (1 + n * 0.35f);
        }

        public float OnVisit(DateTime now)
        {
            float z = Visits.Observe(now);
            // Welcomes are bigger after a long gap, but long gaps also leave some hurt.
            return Feel((Emotion.Loneliness, -0.35f), (Emotion.Joy, 0.12f + Math.Max(0, z) * 0.04f),
                (Emotion.Trust, z > 2 ? -0.03f : 0.02f), (Emotion.Anxiety, z > 2 ? 0.05f : -0.05f));
        }

        public float OnFeed(Kin before, bool loved, bool overfed, DateTime now)
        {
            float z = Feeding.Observe(now);
            float hunger = (100 - before.Satiation) / 100f;
            float onTime = (float)Math.Exp(-z * z * 0.5f);      // 1 when the meal came when expected
            float novelty = Habituation("feed");
            float r = Feel(
                (Emotion.Contentment, overfed ? -0.05f : 0.12f + hunger * 0.25f),
                (Emotion.Joy, (loved ? 0.14f : 0.04f) * novelty),
                (Emotion.Trust, overfed ? -0.01f : 0.03f + 0.06f * onTime * Feeding.Regularity),
                (Emotion.Anxiety, -0.1f - 0.2f * hunger + (z > 1.5f ? 0.04f : 0)),
                (Emotion.Frustration, overfed ? 0.12f : -0.04f),
                (Emotion.Loneliness, -0.05f));
            Banks["care"].Learn(r * 4);
            return r;
        }

        public float OnGroom(float quality)
        {
            float n = Habituation("groom");
            float r = Feel((Emotion.Contentment, 0.1f + 0.12f * quality), (Emotion.Trust, 0.03f + 0.04f * quality),
                (Emotion.Joy, 0.05f * n), (Emotion.Loneliness, -0.12f), (Emotion.Anxiety, -0.06f),
                (Emotion.Frustration, quality < 0.25f ? 0.06f : -0.04f));
            Banks["care"].Learn(r * 4);
            return r;
        }

        public float OnPraise(bool deserved)
        {
            float n = Habituation("praise");
            float r = Feel((Emotion.Pride, deserved ? 0.2f : 0.05f * n), (Emotion.Joy, 0.08f * n),
                (Emotion.Trust, deserved ? 0.05f : 0.01f), (Emotion.Boredom, deserved ? -0.05f : 0.03f));
            Banks["care"].Learn(r * 4);
            return r;
        }

        public float OnNuzzle() => Feel((Emotion.Loneliness, -0.15f), (Emotion.Trust, 0.015f), (Emotion.Contentment, 0.04f));

        public float OnRest(bool tired) => Feel((Emotion.Contentment, tired ? 0.15f : 0.03f), (Emotion.Anxiety, -0.05f), (Emotion.Frustration, tired ? -0.1f : 0.03f));

        public float OnPlay(string game, float score)
        {
            float n = Habituation("play:" + game);
            float r = Feel((Emotion.Joy, (0.08f + 0.18f * score) * n), (Emotion.Excitement, 0.12f + 0.15f * score),
                (Emotion.Boredom, -0.25f * n), (Emotion.Pride, score > 0.7f ? 0.1f : 0), (Emotion.Frustration, score < 0.2f ? 0.08f : -0.05f),
                (Emotion.Loneliness, -0.1f));
            Banks["play"].Learn(r * 4);
            return r;
        }

        public float OnBidAnswered(float responseReward) =>
            Feel((Emotion.Trust, responseReward > 0 ? 0.05f * responseReward : 0), (Emotion.Joy, Math.Max(0, responseReward) * 0.05f),
                (Emotion.Frustration, responseReward < 0 ? 0.05f : -0.03f));

        public float OnBidIgnored() => Feel((Emotion.Frustration, 0.12f), (Emotion.Trust, -0.04f), (Emotion.Loneliness, 0.08f), (Emotion.Joy, -0.05f));

        public float OnExplore(string goal, float spatialReward, bool novel)
        {
            float r = Feel((Emotion.Excitement, novel ? 0.06f : 0.01f), (Emotion.Boredom, novel ? -0.08f : 0),
                (Emotion.Contentment, spatialReward > 0.4f ? 0.03f : 0), (Emotion.Joy, goal == "Visit_AnimalFriend" ? 0.05f : 0));
            Banks["explore"].Learn(spatialReward + (novel ? 0.3f : 0));
            return r;
        }

        public float OnBattle(bool won, float margin)
        {
            if (won) Wins++; else Losses++;
            float resilience = this[Emotion.Trust];
            float r = won
                ? Feel((Emotion.Pride, 0.2f + margin * 0.1f), (Emotion.Excitement, 0.2f), (Emotion.Joy, 0.1f), (Emotion.Anxiety, -0.08f))
                : Feel((Emotion.Frustration, 0.18f * (1 - resilience * 0.6f)), (Emotion.Anxiety, 0.12f * (1 - resilience)), (Emotion.Pride, -0.08f), (Emotion.Excitement, 0.05f));
            Banks["battle"].Learn((won ? 1 : 0.15f) + margin * 0.5f);
            return r;
        }

        // ---- Battle behaviour ----------------------------------------------------------

        /// Chance the kin follows your command rather than its own learned move.
        public float Obedience => Math.Clamp(0.25f + this[Emotion.Trust] * 0.7f + this[Emotion.Pride] * 0.1f - this[Emotion.Frustration] * 0.35f, 0.15f, 0.98f);

        /// Damage multiplier from mood: excitement and pride sharpen it, anxiety blunts it.
        public float BattleSpirit => Math.Clamp(1f + this[Emotion.Excitement] * 0.15f + this[Emotion.Pride] * 0.15f - this[Emotion.Anxiety] * 0.25f, 0.7f, 1.3f);

        public float Skill(string moveId) => MoveSkill.TryGetValue(moveId, out var v) ? v : 1f;

        /// Moves get better the more they actually work for this kin.
        public void LearnMove(string moveId, float reward)
        {
            float s = Skill(moveId);
            MoveSkill[moveId] = Math.Clamp(s + 0.06f * reward, 0.8f, 1.35f);
        }

        public static string Word(Emotion e) => e switch
        {
            Emotion.Joy => "joyful", Emotion.Trust => "trusting", Emotion.Contentment => "content",
            Emotion.Excitement => "excited", Emotion.Pride => "proud", Emotion.Loneliness => "lonely",
            Emotion.Frustration => "frustrated", Emotion.Anxiety => "anxious", _ => "bored",
        };

        public static UnityEngine.Color Colour(Emotion e) => e switch
        {
            Emotion.Joy => new(1f, 0.8f, 0.3f), Emotion.Trust => new(0.45f, 0.75f, 0.55f), Emotion.Contentment => new(0.6f, 0.85f, 0.45f),
            Emotion.Excitement => new(1f, 0.55f, 0.3f), Emotion.Pride => new(0.85f, 0.55f, 0.95f), Emotion.Loneliness => new(0.5f, 0.6f, 0.9f),
            Emotion.Frustration => new(0.95f, 0.35f, 0.35f), Emotion.Anxiety => new(0.7f, 0.5f, 0.75f), _ => new(0.65f, 0.65f, 0.65f),
        };
    }
}
