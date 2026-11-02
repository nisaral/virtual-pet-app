using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// Where wild kin live and who turns up where. Each region has its own mix of species
    /// and how grown-up they tend to be, so far-off places feel wilder.
    public static class WildLife
    {
        public const int MaxDens = 72;

        /// Tall-grass cells spread across the vale, at least 7 tiles apart.
        public static List<Vector2Int> Dens(int seed = 23)
        {
            var cells = new List<Vector2Int>();
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
                if (GlenMap.At(x, y) == Tile.TallGrass) cells.Add(new Vector2Int(x, y));
            var rng = new System.Random(seed);
            for (int i = cells.Count - 1; i > 0; i--)
            {
                int j = rng.Next(i + 1);
                (cells[i], cells[j]) = (cells[j], cells[i]);
            }
            var dens = new List<Vector2Int>();
            foreach (var c in cells)
            {
                if (dens.Count >= MaxDens) break;
                bool clear = true;
                foreach (var d in dens) if ((d - c).sqrMagnitude < 49) { clear = false; break; }
                if (clear) dens.Add(c);
            }
            return dens;
        }

        /// Species weights (Bloom, Tide, Ember) and stage odds (stage 1, stage 2) by zone.
        static (float b, float t, float e, float s1, float s2) Mix(string zone) => zone switch
        {
            "frost" => (0.45f, 0.45f, 0.1f, 0.45f, 0.15f),
            "dunes" => (0.15f, 0.1f, 0.75f, 0.25f, 0.05f),
            "oasis" => (0.2f, 0.4f, 0.4f, 0.3f, 0.08f),
            "bay" => (0.15f, 0.75f, 0.1f, 0.25f, 0.05f),
            "isle" => (0.1f, 0.6f, 0.3f, 0.5f, 0.2f),
            "wildwood" or "thicket" => (0.5f, 0.25f, 0.25f, 0.3f, 0.08f),
            "crag" => (0.3f, 0.2f, 0.5f, 0.45f, 0.3f),
            "aurora" => (0.3f, 0.6f, 0.1f, 0.45f, 0.25f),
            "marsh" => (0.25f, 0.65f, 0.1f, 0.3f, 0.1f),
            "blooms" => (0.75f, 0.1f, 0.15f, 0.25f, 0.08f),
            "southfield" => (0.45f, 0.3f, 0.25f, 0.3f, 0.1f),
            "canyon" => (0.1f, 0.1f, 0.8f, 0.4f, 0.2f),
            "coral" => (0.15f, 0.7f, 0.15f, 0.5f, 0.25f),
            _ => (0.6f, 0.2f, 0.2f, 0.05f, 0f),
        };

        public static (SpeciesId species, int stage) Pick(string zone, System.Random rng)
        {
            var m = Mix(zone);
            double r = rng.NextDouble() * (m.b + m.t + m.e);
            var species = r < m.b ? SpeciesId.Pipkin : r < m.b + m.t ? SpeciesId.Marrow : SpeciesId.Solbit;
            double s = rng.NextDouble();
            int stage = s < m.s2 ? 2 : s < m.s2 + m.s1 ? 1 : 0;
            return (species, stage);
        }

        public static string Rustle(SpeciesId species, int stage) => species switch
        {
            SpeciesId.Pipkin => stage == 2 ? "antlers rise out of the grass, slow and proud" : "leafy ears twitch above the grass",
            SpeciesId.Marrow => stage == 2 ? "a long wet tail coils through the stems" : "something damp blinks at you from the stems",
            _ => stage == 2 ? "the grass smokes where a mane brushes it" : "a warm little tuft bobs between the blades",
        };
    }
}
