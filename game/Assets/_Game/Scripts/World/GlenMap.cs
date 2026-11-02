using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    public enum Tile { Grass, TallGrass, Flowers, Path, Water, Bridge, High, Ledge, Stairs, Tree, Rock, Fence, Sand, Blocked, Snow, Ice, Crop, DeepWater, Dune }

    public sealed class Building
    {
        public string Id, Kind, Name;
        public RectInt Rect;           // footprint in tiles
        public Vector2Int Door;        // tile in front of the door the keeper stands on
        public Color Wall, Roof;
        public bool Enterable = true;
        /// Which interior to use; defaults to Kind.
        public string Room;
        public string RoomId => Room ?? Kind;
    }

    public sealed class Spot
    {
        public string Id, Kind;
        public Vector2Int Cell;
    }

    /// The Glen, laid out by hand on a 1 m grid. Row 0 is the north edge (top of the
    /// screen). Legend:
    ///   T tree   . grass   , tall grass   o flowers   = path   ~ water   B bridge
    ///   ^ high ground   v ledge (hop down south)   s stairs   r rock   f fence   : sand
    ///   # building footprint (see Buildings)
    public static class GlenMap
    {
        public static readonly string[] Rows =
        {
            "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
            "TTT..o....,,,,,...TTTT^^^^^^^^^^^TTT",
            "TT.......,,,,,,,...TT^^^^^^^^^^^^^TT",
            "T..T......,,,,,,....T^^^^^^^^^^^^^TT",
            "T......o...,,,,......^^^^^^^^^^^^^TT",
            "T..........=========s^^^^^^^^^^^^^TT",
            "T..........=.........vvvvvvvvvvvvvTT",
            "T.ffffffff.=.......................T",
            "T.f......f.=......r....,,,,,.......T",
            "T.f......f.=...........,,,,,,......T",
            "T.f......f.=...........,,,,,,..o...T",
            "T.ffff.fff.=......................TT",
            "T..........=.....:::::::::........TT",
            "T....o.....=....::~~~~~~~::.......TT",
            "T..........=...::~~~~~~~~~::...r...T",
            "T===============BBBBBBBBBBB=.......T",
            "T..........=...::~~~~~~~~~::.......T",
            "T..........=....::~~~~~~~::........T",
            "T..........=.....:::::::::.........T",
            "T..........=.......................T",
            "T...#######=.........#####.........T",
            "T...#######=.........#####...o.....T",
            "T...#######=.........#####.........T",
            "T...#######=.........#####.....,,,,T",
            "T...#######=...........=.......,,,,T",
            "T........=====================.,,,,T",
            "T..o.....=.......######.......=....T",
            "T........=.......######.......=..o.T",
            "TT.......=.......######.......=...TT",
            "TTTTTTTTT=TTTTTTTTTTTTTTTTTTTTTTTTTT",
        };

        /// Homestead ASCII is stamped into a larger Vale: dunes and an oasis west, Frostveil
        /// north, Tidewake Bay and Gull Isle east, the Wildwood south.
        public const int Ox = 64, Oy = 60, East = 60, South = 64;
        public static int InnerW => Rows[0].Length;
        public static int InnerH => Rows.Length;
        public static int Width => Ox + InnerW + East;
        public static int Height => Oy + InnerH + South;
        public static Vector2Int Oasis => new(Ox - 14, Oy + 24);
        public static Vector2Int Isle => new(Ox + InnerW + 18, Oy + 15);
        public static Vector2Int Wildwood => new(Ox + 18, Oy + InnerH + 16);
        public static Vector2Int Coral => new(Ox + InnerW + 42, Oy + 22);
        public static Vector2Int Aurora => new(Ox + InnerW + 34, Oy - 30);
        public static RectInt Town => new(Ox + 2, Oy + InnerH + 30, 34, 20);
        public const int TownStreet = Oy + 30 + 40;
        static Vector2Int V(int x, int y) => new(x + Ox, y + Oy);

        public static readonly Building[] Buildings =
        {
            new Building { Id = "homestead", Kind = "house", Name = "Homestead", Rect = new RectInt(4 + Ox, 20 + Oy, 7, 5), Door = new Vector2Int(7 + Ox, 25 + Oy),
                Wall = new Color(0.97f, 0.9f, 0.78f), Roof = new Color(0.86f, 0.33f, 0.28f) },
            new Building { Id = "shed", Kind = "shed", Name = "Tool shed", Rect = new RectInt(21 + Ox, 20 + Oy, 5, 4), Door = new Vector2Int(23 + Ox, 24 + Oy),
                Wall = new Color(0.8f, 0.58f, 0.36f), Roof = new Color(0.36f, 0.5f, 0.72f) },
            new Building { Id = "pavilion", Kind = "pavilion", Name = "Care pavilion", Rect = new RectInt(17 + Ox, 26 + Oy, 6, 3), Door = new Vector2Int(19 + Ox, 25 + Oy),
                Wall = new Color(0.98f, 0.94f, 0.86f), Roof = new Color(0.92f, 0.7f, 0.32f), Enterable = false },
            new Building { Id = "dunehut", Kind = "cottage", Name = "Sunbake hut", Rect = new RectInt(Ox - 16, Oy + 9, 5, 4), Door = new Vector2Int(Ox - 14, Oy + 13),
                Wall = new Color(0.96f, 0.82f, 0.58f), Roof = new Color(0.78f, 0.38f, 0.22f) },
            new Building { Id = "frostcabin", Kind = "cottage", Name = "Frost cabin", Rect = new RectInt(Ox + 4, Oy - 16, 5, 4), Door = new Vector2Int(Ox + 6, Oy - 12),
                Wall = new Color(0.82f, 0.88f, 0.94f), Roof = new Color(0.42f, 0.52f, 0.7f) },
            new Building { Id = "bayhut", Kind = "cottage", Name = "Tide shack", Rect = new RectInt(Ox + InnerW + 1, Oy + 11, 5, 4), Door = new Vector2Int(Ox + InnerW + 3, Oy + 15),
                Wall = new Color(0.72f, 0.62f, 0.48f), Roof = new Color(0.28f, 0.46f, 0.62f) },
            new Building { Id = "rangerhut", Kind = "cottage", Name = "Ranger lodge", Rect = new RectInt(Ox + 26, Oy + InnerH + 9, 5, 4), Door = new Vector2Int(Ox + 28, Oy + InnerH + 13),
                Wall = new Color(0.66f, 0.5f, 0.36f), Roof = new Color(0.3f, 0.5f, 0.32f) },
            new Building { Id = "mart", Kind = "cottage", Room = "shop", Name = "Kin Mart", Rect = new RectInt(Ox + 5, TownStreet - 5, 5, 4), Door = new Vector2Int(Ox + 7, TownStreet - 1),
                Wall = new Color(0.62f, 0.78f, 0.95f), Roof = new Color(0.25f, 0.45f, 0.82f) },
            new Building { Id = "inn", Kind = "house", Name = "Brookside Inn", Rect = new RectInt(Ox + 14, TownStreet - 6, 7, 5), Door = new Vector2Int(Ox + 17, TownStreet - 1),
                Wall = new Color(0.98f, 0.88f, 0.8f), Roof = new Color(0.72f, 0.28f, 0.36f) },
            new Building { Id = "lab", Kind = "house", Room = "lab", Name = "Ranger lab", Rect = new RectInt(Ox + 25, TownStreet - 6, 7, 5), Door = new Vector2Int(Ox + 28, TownStreet - 1),
                Wall = new Color(0.94f, 0.96f, 0.98f), Roof = new Color(0.36f, 0.62f, 0.5f) },
            new Building { Id = "townhouse0", Kind = "cottage", Name = "Pell's house", Rect = new RectInt(Ox + 8, TownStreet + 3, 5, 4), Door = new Vector2Int(Ox + 10, TownStreet + 7),
                Wall = new Color(0.96f, 0.86f, 0.66f), Roof = new Color(0.55f, 0.36f, 0.6f) },
            new Building { Id = "townhouse1", Kind = "cottage", Name = "Ivo's house", Rect = new RectInt(Ox + 22, TownStreet + 3, 5, 4), Door = new Vector2Int(Ox + 24, TownStreet + 7),
                Wall = new Color(0.88f, 0.92f, 0.78f), Roof = new Color(0.82f, 0.52f, 0.24f) },
            new Building { Id = "marshhut", Kind = "cottage", Name = "Stilt hut", Rect = new RectInt(Ox - 30, TownStreet - 5, 5, 4), Door = new Vector2Int(Ox - 28, TownStreet - 1),
                Wall = new Color(0.6f, 0.56f, 0.42f), Roof = new Color(0.36f, 0.42f, 0.3f) },
            new Building { Id = "auroralodge", Kind = "cottage", Name = "Aurora lodge", Rect = new RectInt(Ox + InnerW + 20, Oy - 28, 5, 4), Door = new Vector2Int(Ox + InnerW + 22, Oy - 24),
                Wall = new Color(0.78f, 0.82f, 0.96f), Roof = new Color(0.4f, 0.32f, 0.62f) },
            new Building { Id = "canyonpost", Kind = "cottage", Name = "Canyon post", Rect = new RectInt(Ox - 46, Oy + 9, 5, 4), Door = new Vector2Int(Ox - 44, Oy + 13),
                Wall = new Color(0.9f, 0.62f, 0.44f), Roof = new Color(0.6f, 0.3f, 0.2f) },
            new Building { Id = "oasistent", Kind = "cottage", Name = "Oasis tent", Rect = new RectInt(Ox - 22, Oy + 19, 4, 3), Door = new Vector2Int(Ox - 20, Oy + 22),
                Wall = new Color(0.98f, 0.9f, 0.74f), Roof = new Color(0.82f, 0.3f, 0.36f) },
        };

        public static readonly Spot[] Spots =
        {
            new Spot { Id = "bowl", Kind = "bowl", Cell = V(19, 27) },
            new Spot { Id = "rune0", Kind = "rune", Cell = V(24, 2) },
            new Spot { Id = "rune1", Kind = "rune", Cell = V(29, 2) },
            new Spot { Id = "rune2", Kind = "rune", Cell = V(24, 4) },
            new Spot { Id = "rune3", Kind = "rune", Cell = V(29, 4) },
            new Spot { Id = "bush0", Kind = "berrybush", Cell = V(5, 3) },
            new Spot { Id = "bush1", Kind = "berrybush", Cell = V(14, 9) },
            new Spot { Id = "bush2", Kind = "berrybush", Cell = V(31, 12) },
            new Spot { Id = "lamp0", Kind = "lamp", Cell = V(12, 19) },
            new Spot { Id = "lamp1", Kind = "lamp", Cell = V(10, 26) },
            new Spot { Id = "lamp2", Kind = "lamp", Cell = V(28, 24) },
            new Spot { Id = "lamp3", Kind = "lamp", Cell = V(12, 6) },
            new Spot { Id = "sign0", Kind = "sign", Cell = V(10, 14) },
            new Spot { Id = "mailbox", Kind = "mailbox", Cell = V(5, 25) },
            new Spot { Id = "meadow", Kind = "meadow", Cell = V(25, 9) },
            new Spot { Id = "keeperStart", Kind = "start", Cell = V(8, 26) },
            new Spot { Id = "arenaEntry", Kind = "arena", Cell = V(23, 24) },
            new Spot { Id = "farm0", Kind = "farm", Cell = V(4, 9) },
            new Spot { Id = "farm1", Kind = "farm", Cell = V(5, 9) },
            new Spot { Id = "farm2", Kind = "farm", Cell = V(4, 10) },
            new Spot { Id = "farm3", Kind = "farm", Cell = V(5, 10) },
            new Spot { Id = "gateDesert", Kind = "gate", Cell = new Vector2Int(Ox - 1, Oy + 15) },
            new Spot { Id = "gateBay", Kind = "gate", Cell = new Vector2Int(Ox + InnerW, Oy + 15) },
            new Spot { Id = "gateFrost", Kind = "gate", Cell = new Vector2Int(Ox + 10, Oy - 1) },
            new Spot { Id = "gateWild", Kind = "gate", Cell = new Vector2Int(Ox + 8, Oy + 30) },
            new Spot { Id = "bush3", Kind = "berrybush", Cell = new Vector2Int(Ox + 14, Oy + 35) },
            new Spot { Id = "bush4", Kind = "berrybush", Cell = new Vector2Int(Ox - 10, Oy + 26) },
            new Spot { Id = "lamp4", Kind = "lamp", Cell = new Vector2Int(Ox + 10, Oy + 32) },
            new Spot { Id = "sign1", Kind = "sign", Cell = new Vector2Int(Ox + 12, TownStreet + 1) },
            new Spot { Id = "lamp5", Kind = "lamp", Cell = new Vector2Int(Ox + 4, TownStreet + 1) },
            new Spot { Id = "lamp6", Kind = "lamp", Cell = new Vector2Int(Ox + 20, TownStreet + 1) },
            new Spot { Id = "lamp7", Kind = "lamp", Cell = new Vector2Int(Ox + 32, TownStreet + 1) },
            new Spot { Id = "bush5", Kind = "berrybush", Cell = new Vector2Int(Ox + InnerW + 24, TownStreet - 3) },
            new Spot { Id = "bush6", Kind = "berrybush", Cell = new Vector2Int(Ox - 20, Oy - 12) },
            new Spot { Id = "lookout", Kind = "lookout", Cell = new Vector2Int(Ox + InnerW + 4, Oy + 15) },
        };

        public static Spot SpotById(string id) => System.Array.Find(Spots, s => s.Id == id);

        static Tile[,] tiles;

        public static Tile At(int x, int y)
        {
            if (tiles == null) Parse();
            if (x < 0 || y < 0 || x >= Width || y >= Height) return Tile.Tree;
            return tiles[x, y];
        }

        static void Parse()
        {
            int W = Width, H = Height;
            tiles = new Tile[W, H];
            for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                bool edge = x < 2 || y < 2 || x >= W - 2 || y >= H - 2;
                tiles[x, y] = edge ? Tile.Tree : Wild(x, y);
            }

            for (int y = 0; y < InnerH; y++)
            for (int x = 0; x < InnerW; x++)
            {
                char ch = x < Rows[y].Length ? Rows[y][x] : 'T';
                tiles[x + Ox, y + Oy] = ch switch
                {
                    '.' => Tile.Grass, ',' => Tile.TallGrass, 'o' => Tile.Flowers, '=' => Tile.Path,
                    '~' => Tile.Water, 'B' => Tile.Bridge, '^' => Tile.High, 'v' => Tile.Ledge,
                    's' => Tile.Stairs, 'r' => Tile.Rock, 'f' => Tile.Fence, ':' => Tile.Sand,
                    '#' => Tile.Blocked, _ => Tile.Tree,
                };
            }

            void Road(int x0, int y0, int x1, int y1)
            {
                int x = x0, y = y0;
                while (x != x1 || y != y1)
                {
                    if (x > 1 && y > 1 && x < W - 2 && y < H - 2) tiles[x, y] = Tile.Path;
                    if (x != x1) x += x1 > x ? 1 : -1;
                    else y += y1 > y ? 1 : -1;
                }
            }
            Road(3, Oy + 15, Ox + 1, Oy + 15);
            Road(Ox + InnerW - 1, Oy + 15, W - 4, Oy + 15);
            Road(Ox + 10, 3, Ox + 10, Oy + 1);
            Road(Ox + 9, Oy + InnerH - 1, Ox + 9, Oy + InnerH + 10);
            Road(Ox + 9, Oy + InnerH + 10, Ox + 24, Oy + InnerH + 14);
            Road(Ox + 24, Oy + InnerH + 14, Ox + 24, TownStreet);
            Road(Ox - 44, TownStreet, Ox + InnerW + 40, TownStreet);
            Road(Ox + 18, TownStreet, Ox + 18, H - 4);
            Road(Ox - 44, TownStreet, Ox - 44, Oy + 13);
            Road(Ox + 10, Oy - 22, Aurora.x - 6, Oy - 22);
            Road(Ox + 10, Oy - 34, Ox - 40, Oy - 34);
            Road(Isle.x, Isle.y, Coral.x, Coral.y);
            Road(Ox - 8, Oy + 15, Oasis.x + 4, Oasis.y);
            Road(Ox - 4, Oy + 15, Ox - 4, Oy - 2);

            // Keep the ground around every door, gate and region landing open.
            void Clear(Vector2Int c, int r)
            {
                for (int dy = -r; dy <= r; dy++)
                for (int dx = -r; dx <= r; dx++)
                {
                    int x = c.x + dx, y = c.y + dy;
                    if (x <= 1 || y <= 1 || x >= W - 2 || y >= H - 2) continue;
                    if (x >= Ox && x < Ox + InnerW && y >= Oy && y < Oy + InnerH) continue;
                    if (tiles[x, y] is Tile.Tree or Tile.Rock or Tile.Water or Tile.DeepWater)
                        tiles[x, y] = y < Oy ? Tile.Snow : x < Ox || x >= Ox + InnerW ? Tile.Sand : Tile.Grass;
                }
            }
            foreach (var b in Buildings)
                if (b.Rect.x < Ox || b.Rect.y < Oy || b.Rect.x >= Ox + InnerW || b.Rect.y >= Oy + InnerH)
                {
                    Clear(b.Door, 2);
                    Clear(new Vector2Int((int)b.Rect.center.x, (int)b.Rect.center.y), 4);
                }
            foreach (var r in Regions) Clear(r.Cell, 2);
            foreach (var c in ExtraClearings) Clear(c, 1);
            foreach (var s in Spots) if (s.Kind is "gate" or "berrybush" or "lamp") Clear(s.Cell, 1);

            foreach (var s in Spots)
            {
                if (s.Kind == "farm") tiles[s.Cell.x, s.Cell.y] = Tile.Crop;
                else if (s.Kind is "bowl" or "rune" or "berrybush" or "lamp" or "sign" or "mailbox")
                    tiles[s.Cell.x, s.Cell.y] = Tile.Blocked;
            }
            foreach (var b in Buildings)
            {
                if (b.Id is "homestead" or "shed" or "pavilion") continue;
                for (int y = b.Rect.y; y < b.Rect.yMax; y++)
                for (int x = b.Rect.x; x < b.Rect.xMax; x++)
                    if (x > 1 && y > 1 && x < W - 2 && y < H - 2) tiles[x, y] = Tile.Blocked;
                if (Walkable(b.Door.x, b.Door.y) == false) tiles[b.Door.x, b.Door.y] = Tile.Path;
            }
        }

        static float Noise(int x, int y, float scale, float seed) => Mathf.PerlinNoise(x * scale + seed, y * scale + seed * 0.37f);

        /// Procedural terrain for everything outside the hand-made homestead.
        static Tile Wild(int x, int y)
        {
            float n = Noise(x, y, 0.13f, 11.3f), g = Noise(x, y, 0.21f, 47.9f);
            float Dist(Vector2Int c) => Mathf.Sqrt((x - c.x) * (x - c.x) + (y - c.y) * (y - c.y));
            if (y < Oy && x < Ox - 22)
            {
                // Crag Peaks: boulder fields and hardy grass between snowy rocks.
                if (n > 0.6f) return Tile.Rock;
                if (n > 0.55f) return Tile.Tree;
                if (g < 0.36f) return Tile.TallGrass;
                return (x * 7 + y) % 13 == 0 ? Tile.Ice : Tile.Snow;
            }
            if (y < Oy && x > Ox + InnerW + 16)
            {
                // Aurora Lake: a great frozen lake ringed with pines.
                float lake = Dist(Aurora) + n * 3f;
                if (lake < 9f) return Tile.Ice;
                if (lake < 11f) return Tile.Snow;
                if (n > 0.62f) return Tile.Tree;
                if (g < 0.34f) return Tile.TallGrass;
                return Tile.Snow;
            }
            if (y < Oy)
            {
                // Frostveil: snowfields, pine stands, frozen tarns and frost-moss meadows.
                if (n > 0.7f) return Tile.Tree;
                if (Noise(x, y, 0.09f, 3.1f) > 0.72f) return Tile.Ice;
                if (g < 0.3f) return Tile.TallGrass;
                return (x + y) % 11 == 0 ? Tile.Ice : Tile.Snow;
            }
            if (x >= Ox + InnerW && y < Oy + InnerH)
            {
                // Tidewake Bay: a dune-grass beach, shallows, deep water and Gull Isle.
                int bx = x - Ox - InnerW;
                float isle = Dist(Isle) + n * 2f;
                if (isle < 3.2f) return g < 0.55f ? Tile.TallGrass : Tile.Sand;
                if (isle < 5f) return Tile.Sand;
                float coral = Dist(Coral) + n * 2.5f;
                if (coral < 4.5f) return g < 0.5f ? Tile.TallGrass : Tile.Flowers;
                if (coral < 6.5f) return Tile.Sand;
                if (bx < 5) return g < 0.32f ? Tile.TallGrass : n > 0.74f ? Tile.Rock : Tile.Sand;
                return bx < 10 ? Tile.Water : Tile.DeepWater;
            }
            if (y >= Oy + InnerH && Town.Contains(new Vector2Int(x, y)))
                return (x + y * 5) % 23 == 0 ? Tile.Flowers : Tile.Grass;
            if (y >= Oy + InnerH && x < Ox - 8)
            {
                // Mistmarsh: reedy pools, deep grass and the odd gnarled tree.
                if (Noise(x, y, 0.18f, 21.7f) > 0.64f) return Tile.Water;
                if (n > 0.7f) return Tile.Tree;
                if (g < 0.52f) return Tile.TallGrass;
                return Tile.Grass;
            }
            if (y >= Oy + InnerH && x > Ox + InnerW + 8)
            {
                // Bloom Meadows: open flower fields and grass.
                if (n > 0.72f) return Tile.Tree;
                if (g > 0.58f) return Tile.Flowers;
                if (g < 0.4f) return Tile.TallGrass;
                return Tile.Grass;
            }
            if (y >= Oy + InnerH + 50)
            {
                // Southfield: rolling plains of tall grass below the town.
                if (n > 0.68f) return Tile.Tree;
                return g < 0.55f ? Tile.TallGrass : Tile.Grass;
            }
            if (y >= Oy + InnerH)
            {
                // The Wildwood: old oaks, tall-grass clearings, a mossy pond.
                if (Dist(Wildwood) + n * 2 < 3.5f) return Tile.Water;
                if (n > 0.6f) return Tile.Tree;
                if (g < 0.42f) return Tile.TallGrass;
                if (g > 0.78f) return Tile.Flowers;
                return n > 0.56f && (x + y) % 5 == 0 ? Tile.Rock : Tile.Grass;
            }
            if (x < Ox - 32)
            {
                // Redrock Canyon: rock spires, dunes and scrub grass.
                if (n > 0.58f) return Tile.Rock;
                if (g < 0.3f) return Tile.TallGrass;
                return n > 0.5f ? Tile.Dune : Tile.Sand;
            }
            if (x < Ox)
            {
                // Sunbake Dunes and the Mirage Oasis.
                float o = Dist(Oasis) + n * 1.5f;
                if (o < 3f) return Tile.Water;
                if (o < 6f) return g < 0.6f ? Tile.TallGrass : Tile.Grass;
                if (n > 0.76f) return Tile.Rock;
                if (g < 0.24f) return Tile.TallGrass;
                return (x + y * 3) % 9 == 0 || n > 0.66f ? Tile.Dune : Tile.Sand;
            }
            return Tile.Grass;
        }

        public static int HeightAt(int x, int y)
        {
            var t = At(x, y);
            return t is Tile.High or Tile.Ledge ? 1 : 0;
        }

        public static float SurfaceY(int x, int y)
        {
            var t = At(x, y);
            if (t == Tile.Stairs) return 0.5f;
            if (t is Tile.Water or Tile.DeepWater) return t == Tile.DeepWater ? -0.85f : -0.55f;
            return HeightAt(x, y);
        }

        public static bool Walkable(int x, int y)
        {
            var t = At(x, y);
            return t is Tile.Grass or Tile.TallGrass or Tile.Flowers or Tile.Path or Tile.Bridge or Tile.High or Tile.Ledge or Tile.Stairs or Tile.Sand or Tile.Snow or Tile.Ice or Tile.Crop or Tile.Dune;
        }

        public static bool IsWet(Tile t) => t is Tile.Water or Tile.Bridge or Tile.DeepWater;

        /// Continuous ground height, so stairs ramp smoothly under walking characters.
        public static float SurfaceAt(Vector3 w)
        {
            var c = ToCell(w);
            if (At(c.x, c.y) != Tile.Stairs) return SurfaceY(c.x, c.y) < 0 ? 0 : SurfaceY(c.x, c.y);
            float fx = w.x - c.x;
            float fz = w.z - (Height - 1 - c.y);
            if (HeightAt(c.x + 1, c.y) == 1) return fx;
            if (HeightAt(c.x - 1, c.y) == 1) return 1 - fx;
            if (HeightAt(c.x, c.y - 1) == 1) return fz;
            return 1 - fz;
        }

        /// The 2.5D movement rule: same height, through stairs, or hopping south off a ledge.
        public static bool CanStep(Vector2Int from, Vector2Int to)
        {
            if (!Walkable(to.x, to.y)) return false;
            int hf = HeightAt(from.x, from.y), ht = HeightAt(to.x, to.y);
            if (hf == ht) return true;
            var tf = At(from.x, from.y);
            var tt = At(to.x, to.y);
            if (tf == Tile.Stairs || tt == Tile.Stairs) return true;
            return IsLedgeHop(from, to);
        }

        public static bool IsLedgeHop(Vector2Int from, Vector2Int to) =>
            At(from.x, from.y) == Tile.Ledge && to.y == from.y + 1 && to.x == from.x && HeightAt(to.x, to.y) == 0;

        /// World position of a cell centre. +X east, +Z north.
        public static Vector3 ToWorld(Vector2Int c) => new(c.x + 0.5f, SurfaceY(c.x, c.y), Height - 1 - c.y + 0.5f);

        public static Vector2Int ToCell(Vector3 w) => new(Mathf.FloorToInt(w.x), Height - 1 - Mathf.FloorToInt(w.z));

        public static string ZoneAt(Vector2Int c)
        {
            foreach (var b in Buildings)
                if (Vector2Int.Distance(c, b.Door) < 3.5f) return b.Id;
            var t = At(c.x, c.y);
            if (t is Tile.High or Tile.Ledge) return "runes";
            if (c.y < Oy) return c.x < Ox - 22 ? "crag" : c.x > Ox + InnerW + 16 ? "aurora" : "frost";
            if (c.y >= Oy + InnerH && Town.Contains(c)) return "town";
            if (c.y >= Oy + InnerH && c.x < Ox - 8) return "marsh";
            if (c.y >= Oy + InnerH && c.x > Ox + InnerW + 8) return "blooms";
            if (c.x >= Ox + InnerW && c.y < Oy + InnerH) return Vector2Int.Distance(c, Isle) < 6 ? "isle" : Vector2Int.Distance(c, Coral) < 8 ? "coral" : "bay";
            if (c.y >= Oy + InnerH + 50) return "southfield";
            if (c.y >= Oy + InnerH) return t == Tile.TallGrass ? "thicket" : "wildwood";
            if (c.x < Ox - 32) return "canyon";
            if (c.x < Ox) return Vector2Int.Distance(c, Oasis) < 7 ? "oasis" : "dunes";
            if (t is Tile.DeepWater) return "bay";
            if (t is Tile.Snow or Tile.Ice) return "frost";
            if (t is Tile.Dune) return "dunes";
            if (t is Tile.Sand or Tile.Bridge) return c.x < Ox ? "dunes" : "pond";
            if (t == Tile.Crop) return "farm";
            if (t == Tile.TallGrass) return "meadow";
            return "glen";
        }

        public static readonly (string Id, string Title, string Blurb, Vector2Int Cell)[] Regions =
        {
            ("glen", "The Glen", "Home, the garden, and the care pavilion.", V(8, 26)),
            ("wildwood", "The Wildwood", "Old oaks and deep grass. Wild kin everywhere.", new Vector2Int(Ox + 10, Oy + 38)),
            ("dunes", "Sunbake Dunes", "Warm sand and spice shrubs. Slow walks.", new Vector2Int(Ox - 12, Oy + 15)),
            ("oasis", "Mirage Oasis", "Cool water and sun-drunk Cindercubs.", new Vector2Int(Ox - 9, Oy + 24)),
            ("bay", "Tidewake Bay", "Kelp shallows. Whales pass at dusk.", new Vector2Int(Ox + 39, Oy + 15)),
            ("isle", "Gull Isle", "A grassy islet at the end of the pier.", new Vector2Int(Ox + 50, Oy + 15)),
            ("frost", "Frostveil", "Quiet snow. Soft moss under ice.", new Vector2Int(Ox + 10, Oy - 8)),
            ("town", "Brookside Town", "The Kin Mart, the inn and the Ranger lab.", new Vector2Int(Ox + 18, TownStreet + 1)),
            ("blooms", "Bloom Meadows", "Endless flowers. Bloom kin bask here.", new Vector2Int(Ox + InnerW + 24, TownStreet + 1)),
            ("marsh", "Mistmarsh", "Reedy pools and shy Tide kin.", new Vector2Int(Ox - 26, TownStreet + 1)),
            ("southfield", "Southfield", "Tall grass to the horizon.", new Vector2Int(Ox + 19, Oy + InnerH + 54)),
            ("canyon", "Redrock Canyon", "Red spires, hot wind, fierce Ember kin.", new Vector2Int(Ox - 43, Oy + 15)),
            ("coral", "Coral Isle", "A flowered reef islet far out in the bay.", new Vector2Int(Coral.x - 1, Coral.y - 6)),
            ("crag", "Crag Peaks", "Boulders, snow and the toughest wild kin.", new Vector2Int(Ox - 38, Oy - 34)),
            ("aurora", "Aurora Lake", "A frozen lake under the night lights.", new Vector2Int(Aurora.x - 8, Oy - 22)),
        };

        /// Where folk stand outside the homestead; kept free of trees and water.
        public static readonly Vector2Int[] ExtraClearings =
        {
            new(Ox - 11, Oy + 12), new(Ox - 10, Oy + 16), new(Ox + 8, Oy - 7), new(Ox + 12, Oy - 10),
            new(Ox + 4, Oy - 20), new(Ox + 14, Oy + 36), new(Ox + 28, Oy + 50),
            new(Ox - 18, Oy + 23), new(Ox + 39, Oy + 16), new(Ox + 41, Oy + 14),
            new(Ox + 38, Oy + 4), new(Ox + 4, Oy + 48), new(Ox + 52, Oy + 16),
            new(Ox + 14, TownStreet + 2), new(Ox + 30, TownStreet + 3), new(Ox - 24, TownStreet + 2), new(Ox - 42, Oy + 17),
            new(Ox + InnerW + 26, TownStreet + 2), new(Ox - 36, Oy - 32), new(Aurora.x - 8, Oy - 20), new(Coral.x, Coral.y - 2),
            new(Ox + 16, Oy + InnerH + 56), new(Ox + 4, TownStreet + 2),
        };

        // ---- A* -----------------------------------------------------------------------

        static readonly Vector2Int[] Dirs = { Vector2Int.up, Vector2Int.down, Vector2Int.left, Vector2Int.right };

        public static List<Vector2Int> FindPath(Vector2Int start, Vector2Int goal, int maxNodes = 9000)
        {
            var result = new List<Vector2Int>();
            if (start == goal) return result;
            if (!Walkable(goal.x, goal.y)) goal = NearestWalkable(goal);
            var open = new SortedSet<(int f, int id)>();
            var g = new Dictionary<Vector2Int, int> { [start] = 0 };
            var came = new Dictionary<Vector2Int, Vector2Int>();
            var ids = new Dictionary<int, Vector2Int>();
            int nextId = 0;
            int H(Vector2Int c) => Mathf.Abs(c.x - goal.x) + Mathf.Abs(c.y - goal.y);
            ids[nextId] = start;
            open.Add((H(start), nextId++));
            int expanded = 0;
            while (open.Count > 0 && expanded++ < maxNodes)
            {
                var top = open.Min;
                open.Remove(top);
                var cur = ids[top.id];
                if (cur == goal)
                {
                    while (cur != start) { result.Add(cur); cur = came[cur]; }
                    result.Reverse();
                    return result;
                }
                foreach (var d in Dirs)
                {
                    var nb = cur + d;
                    if (!CanStep(cur, nb)) continue;
                    int cost = g[cur] + (At(nb.x, nb.y) == Tile.Path ? 1 : 2);
                    if (g.TryGetValue(nb, out int old) && old <= cost) continue;
                    g[nb] = cost;
                    came[nb] = cur;
                    ids[nextId] = nb;
                    open.Add((cost + H(nb) * 2, nextId++));
                }
            }
            return result;
        }

        public static Vector2Int NearestWalkable(Vector2Int c)
        {
            for (int r = 1; r < 6; r++)
            for (int dx = -r; dx <= r; dx++)
            for (int dy = -r; dy <= r; dy++)
            {
                var n = new Vector2Int(c.x + dx, c.y + dy);
                if (Walkable(n.x, n.y)) return n;
            }
            return c;
        }
    }
}
