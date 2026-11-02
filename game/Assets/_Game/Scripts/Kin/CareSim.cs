using System;
using System.Collections.Generic;

namespace LuminaVale
{
    public sealed class CareOutcome
    {
        public Kin Kin;
        public string Memory = "";
        public string Reaction = "";
        public Dictionary<string, int> Bag = new();
        public int GleamGain;
        public bool Rejected;
        public bool Overfed;
    }

    /// Port of lib/vale/care_sim.dart. Pure functions: no Unity types, easy to unit test.
    public static class CareSim
    {
        public static void ApplyOffline(SaveData save, TimeSpan elapsed)
        {
            double hours = elapsed.TotalMinutes / 60.0;
            if (hours < 0.35) { save.LastSeen = DateTime.Now; return; }
            float capped = (float)Math.Min(hours, 16.0);
            var kin = Decay(save.Kin, capped);
            if (hours >= 8)
            {
                kin.DaysTogether += hours >= 16 ? 2 : 1;
                if (kin.Energy < 70) kin.Energy = 70;
                kin.Asleep = false;
            }
            kin.PendingBid = null;
            kin.BidAt = null;
            save.Kin = kin;
            save.LastSeen = DateTime.Now;
            Remember(save, $"While you were away, {kin.Name} {LowestNeed(kin)}.");
        }

        public static void PassHours(SaveData save, int hours)
        {
            var kin = Decay(save.Kin, hours);
            string line;
            if (hours >= 8)
            {
                kin.DaysTogether += 1;
                kin.Energy = 86;
                kin.Asleep = false;
                kin.Joy = Catalog.ClampStat(kin.Joy + 4);
                line = $"The glen slept. {kin.Name} dreamed and woke softer.";
            }
            else
            {
                kin.Asleep = false;
                line = $"A few quiet hours passed. {kin.Name} kept the glen.";
            }
            kin.PendingBid = null;
            kin.BidAt = null;
            kin.LastCare = "rest";
            save.Kin = kin;
            save.LastSeen = DateTime.Now;
            Remember(save, line);
        }

        public static CareOutcome Feed(Kin kin, string foodId, Dictionary<string, int> bag)
        {
            bag.TryGetValue(foodId, out int have);
            if (have <= 0)
                return new CareOutcome { Kin = kin, Reaction = "The pouch has no more of that.", Bag = bag, Rejected = true };
            var nextBag = new Dictionary<string, int>(bag) { [foodId] = have - 1 };
            float before = kin.Satiation;
            var love = new Dictionary<string, float>(kin.FoodLove);
            float bias = love.TryGetValue(foodId, out var b) ? b : 0.3f;
            bool loved = bias >= 0.55f;
            bool overfed = before > 84;
            float satiation = kin.Satiation + (loved ? 24 : 16);
            float joy = kin.Joy + (loved ? 8 : 3);
            float bond = kin.Bond + (loved ? 2.4f : 1.1f);
            if (overfed) { joy -= 7; bond -= 0.4f; }
            float bump = (before < 55 ? 0.1f : 0.02f) + (loved ? 0.04f : 0) + (overfed ? -0.12f : 0);
            love[foodId] = Math.Clamp(bias + bump, 0.05f, 1.35f);
            var food = Catalog.Food(foodId);
            var next = Cared(kin, satiation: satiation, joy: joy, bond: bond, xp: 10, foodLove: love, lastCare: "feed");
            string n = food.Name.ToLowerInvariant();
            string reaction = overfed
                ? $"{kin.Name} noses the {n} away. The bowl was already enough."
                : loved ? $"{kin.Name} lights up for {n}." : $"{kin.Name} eats the {n} politely.";
            return new CareOutcome { Kin = next, Memory = reaction, Reaction = reaction, Bag = nextBag, Overfed = overfed };
        }

        public static CareOutcome Groom(Kin kin, float quality)
        {
            float q = Math.Clamp(quality, 0f, 1f);
            var next = Cared(kin, coat: kin.Coat + 12 + 18 * q, joy: kin.Joy + 4 + 8 * q, bond: kin.Bond + 1.3f + 2.2f * q,
                xp: 8 + (int)Math.Round(q * 8), lastCare: "groom");
            string reaction = q > 0.72f
                ? $"{kin.Name} goes loose under the brush. That was the right rhythm."
                : $"{kin.Name} accepts the brushing, eyes half shut.";
            return new CareOutcome { Kin = next, Memory = reaction, Reaction = reaction };
        }

        public static CareOutcome Rest(Kin kin)
        {
            bool tired = kin.Energy < 50;
            var next = Cared(kin, energy: kin.Energy + (tired ? 30 : 14), joy: kin.Joy + (tired ? 6 : 1),
                bond: kin.Bond + (tired ? 1.4f : 0.4f), xp: 6, lastCare: "rest");
            next.Asleep = true;
            string reaction = tired
                ? $"{kin.Name} folds down and is asleep between breaths."
                : $"{kin.Name} rests because you asked, not because sleep was due.";
            return new CareOutcome { Kin = next, Memory = reaction, Reaction = reaction };
        }

        public static CareOutcome Praise(Kin kin)
        {
            var next = Cared(kin, joy: kin.Joy + 5, bond: kin.Bond + 1.6f, xp: 4, lastCare: "praise");
            string reaction = $"{kin.Name} does the trick again, smaller, just for you.";
            return new CareOutcome { Kin = next, Memory = reaction, Reaction = reaction, GleamGain = 1 };
        }

        public static CareOutcome Nuzzle(Kin kin)
        {
            var next = kin.Clone();
            next.Joy = Catalog.ClampStat(kin.Joy + 2.2f);
            next.Bond = Catalog.ClampStat(kin.Bond + 0.8f);
            return new CareOutcome { Kin = next, Reaction = $"{kin.Name} presses in, then looks up." };
        }

        public static CareOutcome Play(Kin kin, string gameId, float score)
        {
            float s = Math.Clamp(score, 0f, 1f);
            var love = new Dictionary<string, float>(kin.GameLove);
            float prev = love.TryGetValue(gameId, out var p) ? p : 0.3f;
            love[gameId] = Math.Clamp(prev * 0.82f + s * 0.35f, 0.05f, 1.4f);
            float skill = kin.PatternSkill;
            if (gameId == "pattern") skill = Math.Clamp(skill + s * 6, 0, 40);
            var next = Cared(kin, joy: kin.Joy + 6 + 14 * s, energy: kin.Energy - (8 + 6 * s), bond: kin.Bond + 1.4f + 3.2f * s,
                xp: 12 + (int)Math.Round(s * 16), gameLove: love, patternSkill: skill, lastCare: "play");
            string name = gameId switch { "pattern" => "the glyph duet", "spar" => "the spar", _ => "ribbon fall" };
            string reaction = s > 0.66f
                ? $"{kin.Name} is still buzzing from {name}."
                : $"{kin.Name} finishes {name}, a little winded and glad.";
            return new CareOutcome { Kin = next, Memory = reaction, Reaction = reaction, GleamGain = 4 + (int)Math.Round(s * 8) };
        }

        public static Kin Evolve(Kin kin)
        {
            if (kin.Stage >= 2) return kin;
            var next = kin.Clone();
            next.Stage++;
            next.Bond = Catalog.ClampStat(kin.Bond + 6);
            next.Joy = Catalog.ClampStat(kin.Joy + 10);
            next.Xp += 20;
            return next;
        }

        public static Kin Decay(Kin kin, float hours)
        {
            var k = kin.Clone();
            k.Satiation = Catalog.SoftFloor(kin.Satiation - 4.4f * hours);
            k.Energy = Catalog.SoftFloor(kin.Energy - 2.6f * hours);
            k.Coat = Catalog.SoftFloor(kin.Coat - 1.7f * hours);
            k.Joy = Catalog.SoftFloor(kin.Joy - 1.4f * hours);
            return k;
        }

        static Kin Cared(Kin kin, float? satiation = null, float? energy = null, float? coat = null, float? joy = null,
            float? bond = null, int xp = 0, Dictionary<string, float> foodLove = null, Dictionary<string, float> gameLove = null,
            float? patternSkill = null, string lastCare = null)
        {
            var k = kin.Clone();
            k.Satiation = Catalog.ClampStat(satiation ?? kin.Satiation);
            k.Energy = Catalog.SoftFloor(energy ?? kin.Energy);
            k.Coat = Catalog.ClampStat(coat ?? kin.Coat);
            k.Joy = Catalog.ClampStat(joy ?? kin.Joy);
            k.Bond = Catalog.ClampStat(bond ?? kin.Bond);
            k.Xp += xp;
            k.CareCount++;
            if (foodLove != null) k.FoodLove = foodLove;
            if (gameLove != null) k.GameLove = gameLove;
            if (patternSkill.HasValue) k.PatternSkill = patternSkill.Value;
            if (lastCare != null) k.LastCare = lastCare;
            k.Asleep = false;
            k.PendingBid = null;
            k.BidAt = null;
            return k;
        }

        static string LowestNeed(Kin kin)
        {
            var needs = new (string line, float value)[]
            {
                ("waited by an empty bowl", 100 - kin.Satiation),
                ("napped more than usual", 100 - kin.Energy),
                ("got a little dusty", 100 - kin.Coat),
                ("kept looking at the path", 100 - kin.Joy),
            };
            string best = "kept the glen";
            float score = 20;
            foreach (var (line, value) in needs)
            {
                if (value > score) { score = value; best = line; }
            }
            return best;
        }

        public static void Remember(SaveData save, string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            save.Memories.Insert(0, new MemoryNote { At = DateTime.Now, Text = text });
            if (save.Memories.Count > 36) save.Memories.RemoveRange(36, save.Memories.Count - 36);
        }
    }
}
