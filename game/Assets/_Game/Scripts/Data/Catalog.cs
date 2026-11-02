using System;
using System.Linq;
using UnityEngine;

namespace LuminaVale
{
    public enum KinElement { Bloom, Tide, Ember }
    public enum SpeciesId { Pipkin, Marrow, Solbit }
    public enum DayPhase { Dawn, Day, Dusk, Night }
    public enum Mood { Radiant, Glad, Calm, Weary, Sulking, Asleep }
    public enum KinPose { Idle, Walk, Hop, Eat, Groom, Sleep, Cheer, Sulk }

    public sealed class MoveDef
    {
        public string Id, Name, Line, Kind;
        public KinElement Element;
        public int Power;
        public bool IsGuard => Kind == "guard";
        public bool IsRally => Kind == "rally";
    }

    public sealed class FoodDef
    {
        public string Id, Name, Blurb;
        public KinElement? Taste;
    }

    public sealed class SpeciesDef
    {
        public SpeciesId Id;
        public string Name, Nature, FavoriteFood, Blurb;
        public KinElement Element;
        public string[] StageTitles;
        public MoveDef[] Moves;
        /// Resources paths for stage 0..2; the last entry is the legacy placeholder GLB.
        public string[] Models;
        public Color Tint;
        public string TitleFor(int stage) => StageTitles[Math.Clamp(stage, 0, StageTitles.Length - 1)];
    }

    /// Port of SpeciesCatalog and the free helpers in lib/vale/models.dart.
    public static class Catalog
    {
        public static readonly FoodDef[] Foods =
        {
            new FoodDef { Id = "sunberry", Name = "Sunberry", Taste = KinElement.Bloom, Blurb = "Tart, warm, and a little leafy." },
            new FoodDef { Id = "kelpbit", Name = "Kelp bit", Taste = KinElement.Tide, Blurb = "Soft and salty, like a tide pool." },
            new FoodDef { Id = "spicecrumb", Name = "Spice crumb", Taste = KinElement.Ember, Blurb = "A small kick of hearth spice." },
            new FoodDef { Id = "milkdrop", Name = "Milk drop", Taste = null, Blurb = "Gentle. Almost everyone leans in." },
        };

        static MoveDef M(string id, string name, string line, KinElement e, string kind, int power) =>
            new MoveDef { Id = id, Name = name, Line = line, Element = e, Kind = kind, Power = power };

        public static readonly SpeciesDef[] All =
        {
            new SpeciesDef
            {
                Id = SpeciesId.Pipkin, Name = "Fawnlet", Element = KinElement.Bloom, Nature = "hearthful", FavoriteFood = "sunberry",
                StageTitles = new[] { "Fawnlet", "Thicketfawn", "Grovestag" },
                Blurb = "A bloom kin. Quiet, leafy, and quick to learn the hour you come home.",
                Models = new[] { "Models/pipkin_0", "Models/pipkin_1", "Models/pipkin_2", "Models/sproutkit" },
                Tint = new Color(0.55f, 0.82f, 0.45f),
                Moves = new[]
                {
                    M("leaf_puff", "Leaf Puff", "A soft burst of leaves.", KinElement.Bloom, "strike", 8),
                    M("root_guard", "Root Guard", "Roots knit into a little shield.", KinElement.Bloom, "guard", 0),
                    M("pollen_cheer", "Pollen Cheer", "Warm pollen, and a second wind.", KinElement.Bloom, "rally", 5),
                },
            },
            new SpeciesDef
            {
                Id = SpeciesId.Marrow, Name = "Axolet", Element = KinElement.Tide, Nature = "dawnbound", FavoriteFood = "kelpbit",
                StageTitles = new[] { "Axolet", "Ripplemander", "Tidewyrm" },
                Blurb = "A tide kin. Round, playful, and happiest when a game has a rhythm.",
                Models = new[] { "Models/marrow_0", "Models/marrow_1", "Models/marrow_2", "Models/aquapup" },
                Tint = new Color(0.4f, 0.68f, 0.92f),
                Moves = new[]
                {
                    M("bubble_tap", "Bubble Tap", "A bubble pops right on the nose.", KinElement.Tide, "strike", 8),
                    M("shell_brace", "Shell Brace", "The shell turns outward.", KinElement.Tide, "guard", 0),
                    M("tide_song", "Tide Song", "A small wave, then a deep breath.", KinElement.Tide, "rally", 5),
                },
            },
            new SpeciesDef
            {
                Id = SpeciesId.Solbit, Name = "Cindercub", Element = KinElement.Ember, Nature = "duskwit", FavoriteFood = "spicecrumb",
                StageTitles = new[] { "Cindercub", "Blazemane", "Solarion" },
                Blurb = "An ember kin. Bright, nosy, and fond of showing off one good trick.",
                Models = new[] { "Models/solbit_0", "Models/solbit_1", "Models/solbit_2", "Models/embercub" },
                Tint = new Color(0.95f, 0.5f, 0.24f),
                Moves = new[]
                {
                    M("spark_hop", "Spark Hop", "A hop that leaves a spark.", KinElement.Ember, "strike", 8),
                    M("warm_guard", "Warm Guard", "Heat shimmers into a guard.", KinElement.Ember, "guard", 0),
                    M("sun_burst", "Sun Burst", "A flare, and the chest lifts.", KinElement.Ember, "rally", 6),
                },
            },
        };

        public static SpeciesDef Of(SpeciesId id) => All.First(s => s.Id == id);
        public static FoodDef Food(string id) => Foods.First(f => f.Id == id);

        public static DayPhase? DebugPhaseOverride;

        public static DayPhase PhaseAt(DateTime time)
        {
            if (DebugPhaseOverride.HasValue) return DebugPhaseOverride.Value;
            int h = time.Hour;
            if (h >= 5 && h < 8) return DayPhase.Dawn;
            if (h >= 8 && h < 17) return DayPhase.Day;
            if (h >= 17 && h < 20) return DayPhase.Dusk;
            return DayPhase.Night;
        }

        public static float TypeMod(KinElement attack, KinElement defense)
        {
            if (attack == KinElement.Ember && defense == KinElement.Bloom) return 1.45f;
            if (attack == KinElement.Bloom && defense == KinElement.Tide) return 1.45f;
            if (attack == KinElement.Tide && defense == KinElement.Ember) return 1.45f;
            if (attack == KinElement.Bloom && defense == KinElement.Ember) return 0.7f;
            if (attack == KinElement.Tide && defense == KinElement.Bloom) return 0.7f;
            if (attack == KinElement.Ember && defense == KinElement.Tide) return 0.7f;
            return 1f;
        }

        public static float ClampStat(float v) => v < 0 ? 0 : (v > 100 ? 100 : v);
        public static float SoftFloor(float v) => ClampStat(v < 8 ? 8 : v);

        public static string StatWord(float v) => v < 25 ? "Low" : v < 50 ? "Fair" : v < 75 ? "Good" : "Full";

        public static string NatureLabel(string nature) => nature switch
        {
            "hearthful" => "Hearthful",
            "dawnbound" => "Dawnbound",
            "duskwit" => "Duskwit",
            _ => "Brightforage",
        };

        public static Color ElementColor(KinElement e) => e switch
        {
            KinElement.Bloom => new Color(0.45f, 0.85f, 0.4f),
            KinElement.Tide => new Color(0.35f, 0.7f, 1f),
            _ => new Color(1f, 0.55f, 0.2f),
        };
    }
}
