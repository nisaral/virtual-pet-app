using System;
using System.Collections.Generic;

namespace LuminaVale
{
    /// Port of `Kin` from lib/vale/models.dart. Mutable here; CareSim returns clones
    /// so callers can still compare before/after.
    [Serializable]
    public sealed class Kin
    {
        public string Name = "Fawnlet";
        public SpeciesId Species = SpeciesId.Pipkin;
        public string Nature = "hearthful";
        public int Stage;
        public float Bond = 14, Satiation = 74, Energy = 82, Coat = 78, Joy = 72;
        public int Xp, CareCount, DaysTogether;
        public DateTime Born = DateTime.Now;
        public Dictionary<string, float> FoodLove = new();
        public Dictionary<string, float> GameLove = new();
        public bool Asleep;
        public string LastCare = "none";
        public string PendingBid;
        public DateTime? BidAt;
        public string BidStateKey = "";
        public float PatternSkill;

        [Newtonsoft.Json.JsonIgnore]
        public SpeciesDef Def => Catalog.Of(Species);

        public Mood MoodAt(DateTime now)
        {
            if (Asleep) return Mood.Asleep;
            if (Satiation < 28 || Coat < 24) return Mood.Sulking;
            if (Energy < 24) return Mood.Weary;
            float ease = (Joy + Satiation + Energy + Coat) / 4f;
            if (ease > 76 && Bond > 28) return Mood.Radiant;
            if (ease > 55) return Mood.Glad;
            return Mood.Calm;
        }

        public Kin Clone()
        {
            var k = (Kin)MemberwiseClone();
            k.FoodLove = new Dictionary<string, float>(FoodLove);
            k.GameLove = new Dictionary<string, float>(GameLove);
            return k;
        }

        public static Kin Fresh(string name, SpeciesId species)
        {
            var def = Catalog.Of(species);
            var kin = new Kin { Name = name, Species = species, Nature = def.Nature, Born = DateTime.Now };
            foreach (var food in Catalog.Foods)
            {
                kin.FoodLove[food.Id] = food.Id == def.FavoriteFood ? 0.82f : food.Taste == null ? 0.58f : 0.28f;
            }
            kin.GameLove["pattern"] = 0.34f;
            kin.GameLove["ribbons"] = 0.34f;
            kin.GameLove["spar"] = 0.34f;
            return kin;
        }
    }

    [Serializable]
    public sealed class MemoryNote
    {
        public DateTime At;
        public string Text;
    }
}
