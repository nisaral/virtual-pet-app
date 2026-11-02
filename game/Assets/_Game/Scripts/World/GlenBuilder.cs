using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// Things other systems need to reach after the Glen is built.
    public sealed class GlenWorld : MonoBehaviour
    {
        public readonly List<Light> Lamps = new();
        public readonly List<Material> WindowMats = new();
        public readonly Dictionary<string, Renderer> Runes = new();
        public readonly Dictionary<string, GameObject> Berries = new();
        public readonly Dictionary<string, GameObject> Crops = new();
        public Dictionary<string, InteriorRoom> Rooms;
        public Transform BowlFood;
        public Transform ChimneyTop;
        public Bounds Bounds;
    }

    /// Builds the Glen from GlenMap. Each prop first looks for an artist-made prefab in
    /// Resources/Kit/<name> (exported by tools/blender/build_kit.py) and falls back to
    /// the procedural version below, so the game always runs and art can be swapped in
    /// piece by piece.
    public static class GlenBuilder
    {
        // Palette: warm, slightly desaturated greens and creams so creatures pop.
        public static readonly Color Snow = new(0.92f, 0.95f, 0.98f);
        public static readonly Color Ice = new(0.72f, 0.88f, 0.96f);
        public static readonly Color Dune = new(0.93f, 0.74f, 0.42f);
        public static readonly Color Crop = new(0.45f, 0.72f, 0.28f);
        public static readonly Color Grass = new(0.55f, 0.80f, 0.40f);
        public static readonly Color GrassDark = new(0.40f, 0.68f, 0.32f);
        public static readonly Color Forest = new(0.33f, 0.56f, 0.30f);
        public static readonly Color PathCol = new(0.93f, 0.83f, 0.62f);
        public static readonly Color SandCol = new(0.97f, 0.9f, 0.7f);
        public static readonly Color Cliff = new(0.74f, 0.62f, 0.5f);
        public static readonly Color CliffDark = new(0.55f, 0.44f, 0.38f);
        public static readonly Color PondBed = new(0.36f, 0.6f, 0.58f);
        public static readonly Color Bark = new(0.52f, 0.36f, 0.24f);
        public static readonly Color Leaf = new(0.36f, 0.66f, 0.34f);
        public static readonly Color LeafLight = new(0.5f, 0.78f, 0.38f);
        public static readonly Color Pine = new(0.24f, 0.5f, 0.38f);
        public static readonly Color Blossom = new(0.98f, 0.72f, 0.8f);
        public static readonly Color Stone = new(0.72f, 0.72f, 0.7f);
        public static readonly Color Wood = new(0.78f, 0.56f, 0.36f);

        static System.Random rng;
        static float R(float a, float b) => a + (float)rng.NextDouble() * (b - a);

        public static GlenWorld Build()
        {
            rng = new System.Random(7);
            var root = new GameObject("Glen");
            var world = root.AddComponent<GlenWorld>();
            BuildGround(root.transform);
            BuildWater(root.transform);
            BuildBackdrop(root.transform);
            BuildFoliage(root.transform);
            BuildTrees(root.transform);
            BuildFences(root.transform);
            foreach (var b in GlenMap.Buildings) BuildBuilding(root.transform, b, world);
            foreach (var s in GlenMap.Spots) BuildSpot(root.transform, s, world);
            ValeLife.Spawn(root.transform);
            world.Rooms = Interiors.BuildAll();
            root.gameObject.AddComponent<WorldLod>();
            world.Bounds = new Bounds(new Vector3(GlenMap.Width / 2f, 0, GlenMap.Height / 2f), new Vector3(GlenMap.Width, 4, GlenMap.Height));
            return world;
        }

        // ---- Terrain -------------------------------------------------------------------

        static Color TileColor(int x, int y)
        {
            var t = GlenMap.At(x, y);
            return t switch
            {
                Tile.Path or Tile.Stairs => PathCol,
                Tile.Sand or Tile.Dune => t == Tile.Dune ? Dune : SandCol,
                Tile.TallGrass => GrassDark,
                Tile.Tree => Forest,
                Tile.Water or Tile.Bridge or Tile.DeepWater => PondBed,
                Tile.Snow => Snow,
                Tile.Ice => Ice,
                Tile.Crop => Crop,
                Tile.High or Tile.Ledge => new Color(0.6f, 0.83f, 0.44f),
                Tile.Blocked => new Color(0.86f, 0.8f, 0.64f),
                _ => Grass,
            };
        }

        static float TopY(int x, int y)
        {
            var t = GlenMap.At(x, y);
            if (GlenMap.IsWet(t)) return -0.55f;
            return GlenMap.HeightAt(x, y);
        }

        /// Colour at a tile corner: average of the touching tiles at the same height.
        /// This gives soft "painted" transitions between grass, path and sand for free.
        static Color CornerColor(int cx, int cy, float y)
        {
            Color sum = Color.black;
            int n = 0;
            for (int dx = -1; dx <= 0; dx++)
            for (int dy = -1; dy <= 0; dy++)
            {
                int tx = cx + dx, ty = cy + dy;
                if (Mathf.Abs(TopY(tx, ty) - y) > 0.01f) continue;
                sum += TileColor(tx, ty);
                n++;
            }
            var c = n == 0 ? Grass : sum / n;
            float k = 0.94f + Mathf.PerlinNoise(cx * 0.31f, cy * 0.31f) * 0.12f;
            return new Color(c.r * k, c.g * k, c.b * k, 1);
        }

        static void BuildGround(Transform parent)
        {
            int W = GlenMap.Width, H = GlenMap.Height;
            const int chunk = 12;
            for (int cy = 0; cy < H; cy += chunk)
            for (int cx = 0; cx < W; cx += chunk)
            {
            var b = new MeshKit.Builder();
            int xMax = Mathf.Min(W, cx + chunk), yMax = Mathf.Min(H, cy + chunk);
            for (int y = cy; y < yMax; y++)
            for (int x = cx; x < xMax; x++)
            {
                var t = GlenMap.At(x, y);
                float top = TopY(x, y);
                float x0 = x, x1 = x + 1, z1 = H - y, z0 = H - y - 1;
                if (t == Tile.Stairs) { BuildStairs(b, x, y); continue; }

                // Corners: (x, y) is NW in grid space = (x0, z1) in world.
                Color nw = CornerColor(x, y, top), ne = CornerColor(x + 1, y, top);
                Color sw = CornerColor(x, y + 1, top), se = CornerColor(x + 1, y + 1, top);
                Color mid = TileColor(x, y);
                var c = new Vector3(x + 0.5f, top, z0 + 0.5f);
                Vector3 pNW = new(x0, top, z1), pNE = new(x1, top, z1), pSW = new(x0, top, z0), pSE = new(x1, top, z0);
                b.Tri(pSW, pNW, c, sw, nw, mid);
                b.Tri(pNW, pNE, c, nw, ne, mid);
                b.Tri(pNE, pSE, c, ne, se, mid);
                b.Tri(pSE, pSW, c, se, sw, mid);

                // Cliff and bank walls wherever this tile is higher than a neighbour.
                Wall(b, x, y, x, y - 1, new Vector3(x1, 0, z1), new Vector3(x0, 0, z1));   // north edge
                Wall(b, x, y, x, y + 1, new Vector3(x0, 0, z0), new Vector3(x1, 0, z0));   // south edge
                Wall(b, x, y, x - 1, y, new Vector3(x0, 0, z1), new Vector3(x0, 0, z0));   // west edge
                Wall(b, x, y, x + 1, y, new Vector3(x1, 0, z0), new Vector3(x1, 0, z1));   // east edge
            }
            var mesh = b.Build();
            mesh.name = $"Ground_{cx}_{cy}";
            var go = Make(mesh.name, parent, mesh, Mats.Toon(Color.white, 0f, vertexColor: true, shade: new Color(0.7f, 0.68f, 0.82f)));
            go.AddComponent<MeshCollider>().sharedMesh = mesh;
            }
        }

        static void Wall(MeshKit.Builder b, int x, int y, int nx, int ny, Vector3 from, Vector3 to)
        {
            float top = TopY(x, y), low = TopY(nx, ny);
            var nt = GlenMap.At(nx, ny);
            if (top - low < 0.05f) return;
            if (nt == Tile.Stairs || GlenMap.At(x, y) == Tile.Stairs) return;
            bool bank = low < -0.1f;
            Color topC = bank ? SandCol * 0.9f : Cliff;
            Color lowC = bank ? PondBed * 0.85f : CliffDark;
            topC.a = lowC.a = 1;
            // from→to runs so the face points toward the lower neighbour.
            Vector3 a = new(from.x, low, from.z), d = new(to.x, low, to.z);
            Vector3 bTop = new(from.x, top, from.z), cTop = new(to.x, top, to.z);
            // Two bands: rocky face plus a grassy lip at the top edge, like a painted diorama.
            float lip = bank ? 0.08f : 0.16f;
            Vector3 bLip = bTop - Vector3.up * lip, cLip = cTop - Vector3.up * lip;
            b.Quad(a, bLip, cLip, d, lowC, topC, topC, lowC);
            var lipC = bank ? SandCol : new Color(0.5f, 0.76f, 0.38f);
            b.Quad(bLip, bTop, cTop, cLip, lipC);
        }

        static void BuildStairs(MeshKit.Builder b, int x, int y)
        {
            int H = GlenMap.Height;
            // Ascend toward the high neighbour.
            Vector3 dir = GlenMap.HeightAt(x + 1, y) == 1 ? Vector3.right : GlenMap.HeightAt(x - 1, y) == 1 ? Vector3.left :
                GlenMap.HeightAt(x, y - 1) == 1 ? Vector3.forward : Vector3.back;
            var center = new Vector3(x + 0.5f, 0, H - y - 0.5f);
            const int steps = 4;
            for (int i = 0; i < steps; i++)
            {
                float h = (i + 1) / (float)steps;
                var stepCenter = center + dir * (-0.5f + (i + 0.5f) / steps) + Vector3.up * (h / 2f);
                var size = new Vector3(Mathf.Abs(dir.x) > 0 ? 1f / steps : 1f, h, Mathf.Abs(dir.z) > 0 ? 1f / steps : 1f);
                b.Box(stepCenter, size, i % 2 == 0 ? Cliff : CliffDark * 1.15f);
            }
        }

        static void BuildWater(Transform parent)
        {
            int minX = 999, maxX = -1, minY = 999, maxY = -1;
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
            {
                if (!GlenMap.IsWet(GlenMap.At(x, y))) continue;
                minX = Mathf.Min(minX, x); maxX = Mathf.Max(maxX, x);
                minY = Mathf.Min(minY, y); maxY = Mathf.Max(maxY, y);
            }
            if (maxX < 0) return;
            int H = GlenMap.Height;
            var waterMat = Mats.Water();
            // Only over wet tiles (plus a one-tile lip under the banks), chunked for culling,
            // and subdivided so the vertex swell reads.
            const int chunk = 16;
            for (int cy = minY - 1; cy <= maxY + 1; cy += chunk)
            for (int cx = minX - 1; cx <= maxX + 1; cx += chunk)
            {
                var b = new MeshKit.Builder();
                int quads = 0;
                for (int y = cy; y < cy + chunk; y++)
                for (int x = cx; x < cx + chunk; x++)
                {
                    bool near = false;
                    for (int dy = -1; dy <= 1 && !near; dy++)
                    for (int dx = -1; dx <= 1 && !near; dx++)
                        near = GlenMap.IsWet(GlenMap.At(x + dx, y + dy));
                    if (!near) continue;
                    float z0 = H - y - 1;
                    for (float sx = 0; sx < 1; sx += 0.5f)
                    for (float sz = 0; sz < 1; sz += 0.5f)
                    {
                        float qx = x + sx, qz = z0 + sz;
                        b.Quad(new Vector3(qx, -0.1f, qz), new Vector3(qx, -0.1f, qz + 0.5f), new Vector3(qx + 0.5f, -0.1f, qz + 0.5f), new Vector3(qx + 0.5f, -0.1f, qz), Color.white);
                    }
                    quads++;
                }
                if (quads == 0) continue;
                var water = new GameObject($"Water_{cx}_{cy}");
                water.transform.SetParent(parent);
                water.AddComponent<MeshFilter>().sharedMesh = b.Build();
                water.AddComponent<MeshRenderer>().sharedMaterial = waterMat;
            }

            // Lily pads and the bridge.
            for (int y = minY; y <= maxY; y++)
            for (int x = minX; x <= maxX; x++)
            {
                var t = GlenMap.At(x, y);
                var p = GlenMap.ToWorld(new Vector2Int(x, y));
                if (t == Tile.Water && rng.NextDouble() < 0.12)
                {
                    var pad = Make("LilyPad", parent, MeshKit.Cylinder(12), Mats.Toon(new Color(0.42f, 0.74f, 0.36f), 1f));
                    pad.transform.position = new Vector3(p.x + R(-0.3f, 0.3f), -0.07f, p.z + R(-0.3f, 0.3f));
                    pad.transform.localScale = new Vector3(0.5f, 0.02f, 0.5f) * R(0.7f, 1.2f);
                    if (rng.NextDouble() < 0.4)
                    {
                        var lotus = Make("Lotus", pad.transform, MeshKit.Blob(1), Mats.Toon(Blossom, 1f));
                        lotus.transform.localPosition = new Vector3(0.1f, 2f, 0);
                        lotus.transform.localScale = new Vector3(0.3f, 3f, 0.3f);
                    }
                }
                if (t == Tile.Bridge)
                {
                    var c = new Vector3(x + 0.5f, 0, GlenMap.Height - y - 0.5f);
                    for (int i = 0; i < 3; i++)
                    {
                        var plank = Make("Plank", parent, MeshKit.Box(), Mats.Toon(i == 1 ? Wood : Wood * 0.9f));
                        plank.transform.position = c + new Vector3(-0.33f + i * 0.33f, -0.04f, 0);
                        plank.transform.localScale = new Vector3(0.3f, 0.08f, 1.5f);
                        plank.transform.rotation = Quaternion.Euler(0, R(-2, 2), 0);
                    }
                    foreach (int side in new[] { -1, 1 })
                    {
                        var rail = Make("Rail", parent, MeshKit.Box(), Mats.Toon(Wood * 0.8f));
                        rail.transform.position = c + new Vector3(0, 0.35f, side * 0.72f);
                        rail.transform.localScale = new Vector3(1f, 0.07f, 0.07f);
                        var post = Make("Post", parent, MeshKit.Box(), Mats.Toon(Wood * 0.75f));
                        post.transform.position = c + new Vector3(-0.45f, 0.18f, side * 0.72f);
                        post.transform.localScale = new Vector3(0.09f, 0.45f, 0.09f);
                    }
                }
                if (t == Tile.Sand && rng.NextDouble() < 0.25) Reeds(parent, p);
            }
        }

        static void Reeds(Transform parent, Vector3 p)
        {
            for (int i = 0; i < 3; i++)
            {
                var stem = Make("Reed", parent, MeshKit.Cylinder(5, 0.4f), Mats.Toon(new Color(0.46f, 0.66f, 0.32f), 0.8f, wind: 0.25f));
                stem.transform.position = p + new Vector3(R(-0.35f, 0.35f), 0, R(-0.35f, 0.35f));
                stem.transform.localScale = new Vector3(0.05f, R(0.5f, 0.8f), 0.05f);
                var head = Make("Cattail", stem.transform, MeshKit.Blob(1), Mats.Toon(new Color(0.55f, 0.36f, 0.24f), 0.8f));
                head.transform.localPosition = Vector3.up * 1f;
                head.transform.localScale = new Vector3(1.6f, 0.22f, 1.6f);
            }
        }

        static void BuildBackdrop(Transform parent)
        {
            // A ring of soft hills and tree crowns past the map edge, so the camera never sees void.
            int W = GlenMap.Width, H = GlenMap.Height;
            var floor = Make("OuterFloor", parent, MeshKit.Box(), Mats.Toon(Forest * 0.95f, 0f));
            floor.transform.position = new Vector3(W / 2f, -0.06f, H / 2f);
            floor.transform.localScale = new Vector3(W + 40, 0.1f, H + 40);
            for (int i = 0; i < 28; i++)
            {
                float a = i / 28f * Mathf.PI * 2;
                var p = new Vector3(W / 2f + Mathf.Cos(a) * (W * 0.58f + R(0, 4)), 0, H / 2f + Mathf.Sin(a) * (H * 0.6f + R(0, 4)));
                Tree(parent, p, R(1.3f, 2.0f), rng.NextDouble() < 0.4);
            }
        }

        // ---- Foliage -----------------------------------------------------------------

        static void BuildFoliage(Transform parent)
        {
            Color[] petals = { new(1f, 0.98f, 0.92f), new(1f, 0.8f, 0.4f), new(0.98f, 0.62f, 0.72f), new(0.72f, 0.7f, 1f) };
            var grassMat = Mats.Toon(Color.white, 0.6f, vertexColor: true, wind: 0.35f);
            var flowerMat = Mats.Toon(Color.white, 0.8f, vertexColor: true, wind: 0.2f);
            // Chunked so the distance cull can switch off far-away grass on phones.
            const int chunk = 16;
            for (int cy = 0; cy < GlenMap.Height; cy += chunk)
            for (int cx = 0; cx < GlenMap.Width; cx += chunk)
            {
            var grass = new MeshKit.Builder();
            var flowers = new MeshKit.Builder();
            for (int y = cy; y < Mathf.Min(GlenMap.Height, cy + chunk); y++)
            for (int x = cx; x < Mathf.Min(GlenMap.Width, cx + chunk); x++)
            {
                var t = GlenMap.At(x, y);
                var p = GlenMap.ToWorld(new Vector2Int(x, y));
                if (t == Tile.TallGrass)
                {
                    var tint = y < GlenMap.Oy ? new Color(0.52f, 0.72f, 0.66f) : x < GlenMap.Ox || x >= GlenMap.Ox + GlenMap.InnerW ? new Color(0.62f, 0.68f, 0.32f) : GrassDark;
                    for (int i = 0; i < 4; i++) Tuft(grass, p + new Vector3(R(-0.4f, 0.4f), 0, R(-0.4f, 0.4f)), R(0.45f, 0.7f), tint * R(0.85f, 1.05f));
                }
                else if (t is Tile.Grass or Tile.High && rng.NextDouble() < 0.1)
                    Tuft(grass, p + new Vector3(R(-0.4f, 0.4f), 0, R(-0.4f, 0.4f)), R(0.18f, 0.3f), Grass * 0.9f);
                else if (t == Tile.Snow && rng.NextDouble() < 0.08)
                    Tuft(grass, p + new Vector3(R(-0.3f, 0.3f), 0, R(-0.3f, 0.3f)), R(0.12f, 0.22f), Snow * 0.92f);
                if (t == Tile.Flowers || (t == Tile.Grass && rng.NextDouble() < 0.05))
                {
                    int n = t == Tile.Flowers ? 7 : 2;
                    for (int i = 0; i < n; i++)
                    {
                        var c = petals[rng.Next(petals.Length)];
                        var fp = p + new Vector3(R(-0.42f, 0.42f), R(0.08f, 0.16f), R(-0.42f, 0.42f));
                        flowers.Box(fp, new Vector3(0.11f, 0.06f, 0.11f), c);
                        flowers.Box(fp + Vector3.up * 0.035f, new Vector3(0.05f, 0.03f, 0.05f), new Color(1f, 0.85f, 0.3f));
                        flowers.Box(fp - Vector3.up * 0.06f, new Vector3(0.025f, 0.12f, 0.025f), GrassDark);
                    }
                }
            }
            Make($"TallGrass_{cx}_{cy}", parent, grass.Build(), grassMat);
            Make($"Flowers_{cx}_{cy}", parent, flowers.Build(), flowerMat);
            }
        }

        static void Tuft(MeshKit.Builder b, Vector3 basePos, float height, Color col)
        {
            for (int i = 0; i < 5; i++)
            {
                float a = i / 5f * Mathf.PI * 2 + R(0, 0.6f);
                var dir = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                var side = Vector3.Cross(dir, Vector3.up) * 0.05f;
                var tip = basePos + dir * height * 0.35f + Vector3.up * height * R(0.8f, 1.1f);
                var root = basePos + dir * 0.03f;
                var tipCol = Color.Lerp(col, new Color(0.75f, 0.9f, 0.5f), 0.4f);
                tipCol.a = 1;
                b.Tri(root - side, tip, root + side, col, tipCol, col);
                b.Tri(root + side, tip, root - side, col, tipCol, col); // double-sided
            }
        }

        static void BuildTrees(Transform parent)
        {
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
            {
                var t = GlenMap.At(x, y);
                var p = GlenMap.ToWorld(new Vector2Int(x, y)) + new Vector3(R(-0.2f, 0.2f), 0, R(-0.2f, 0.2f));
                if (t == Tile.Dune && rng.NextDouble() < 0.35) { Cactus(parent, p); continue; }
                if (t == Tile.Rock) { Boulder(parent, p, y < GlenMap.Oy); continue; }
                if (t != Tile.Tree) continue;
                // Skip every other border tree so the big vale stays light on phones.
                if ((x < 3 || y < 3 || x >= GlenMap.Width - 3 || y >= GlenMap.Height - 3) && ((x + y) & 1) == 0) continue;
                // Deep inside a wood the canopy hides most trunks; plant every other one.
                bool deep = GlenMap.At(x + 1, y) == Tile.Tree && GlenMap.At(x - 1, y) == Tile.Tree && GlenMap.At(x, y + 1) == Tile.Tree && GlenMap.At(x, y - 1) == Tile.Tree;
                if (deep && rng.NextDouble() < 0.65) continue;
                double roll = rng.NextDouble();
                Tree(parent, p, R(0.95f, 1.35f), roll < 0.28, blossom: roll > 0.9);
            }
        }

        static void Boulder(Transform parent, Vector3 p, bool snowy)
        {
            var rock = Make("Boulder", parent, MeshKit.Blob(1, 0.35f, rng.Next(99)), Mats.Toon(Stone * R(0.85f, 1.05f), 0.6f));
            rock.transform.position = p + Vector3.up * 0.2f;
            rock.transform.localScale = new Vector3(R(0.7f, 0.95f), R(0.45f, 0.7f), R(0.7f, 0.95f));
            rock.transform.rotation = Quaternion.Euler(0, R(0, 360), 0);
            if (snowy)
            {
                var cap = Make("SnowCap", rock.transform, MeshKit.Blob(1, 0.2f, 3), Mats.Toon(Snow, 0.4f));
                cap.transform.localPosition = Vector3.up * 0.32f;
                cap.transform.localScale = new Vector3(0.85f, 0.35f, 0.85f);
            }
        }

        public static GameObject Tree(Transform parent, Vector3 p, float scale, bool pine, bool blossom = false)
        {
            string kitName = pine ? "tree_pine" : blossom ? "tree_blossom" : "tree_round";
            var kit = Kit(kitName, parent);
            if (kit)
            {
                kit.transform.position = p;
                kit.transform.rotation = Quaternion.Euler(0, R(0, 360), 0);
                kit.transform.localScale = Vector3.one * scale;
                return kit;
            }
            var tree = new GameObject(kitName);
            tree.transform.SetParent(parent);
            tree.transform.position = p;
            tree.transform.localScale = Vector3.one * scale;
            var trunk = Make("Trunk", tree.transform, MeshKit.Cylinder(7, 0.7f), Mats.Toon(Bark));
            trunk.transform.localScale = new Vector3(0.26f, 0.9f, 0.26f);
            if (pine)
            {
                for (int i = 0; i < 3; i++)
                {
                    var tier = Make("Tier", tree.transform, MeshKit.Cylinder(8, 0f), Mats.Toon(Pine * (1 + i * 0.06f), wind: 0.06f));
                    tier.transform.localPosition = Vector3.up * (0.7f + i * 0.5f);
                    tier.transform.localScale = new Vector3(1.3f - i * 0.32f, 0.9f, 1.3f - i * 0.32f);
                }
            }
            else
            {
                var leaf = blossom ? Blossom : Leaf;
                var light = blossom ? new Color(1f, 0.85f, 0.9f) : LeafLight;
                int seed = rng.Next(4);
                var main = Make("Crown", tree.transform, MeshKit.Blob(2, 0.25f, seed), Mats.Toon(leaf, wind: 0.05f));
                main.transform.localPosition = Vector3.up * 1.35f;
                main.transform.localScale = new Vector3(1.25f, 1.05f, 1.25f);
                var top = Make("Crown2", tree.transform, MeshKit.Blob(2, 0.25f, seed + 1), Mats.Toon(light, wind: 0.07f));
                top.transform.localPosition = new Vector3(R(-0.15f, 0.15f), 1.85f, R(-0.15f, 0.15f));
                top.transform.localScale = new Vector3(0.8f, 0.7f, 0.8f);
                var side = Make("Crown3", tree.transform, MeshKit.Blob(2, 0.3f, seed + 2), Mats.Toon(leaf * 0.94f, wind: 0.05f));
                side.transform.localPosition = new Vector3(0.45f, 1.15f, -0.2f);
                side.transform.localScale = new Vector3(0.7f, 0.6f, 0.7f);
            }
            AddBlobShadow(tree.transform, 1.3f);
            return tree;
        }

        static void Cactus(Transform parent, Vector3 p)
        {
            var go = new GameObject("Cactus");
            go.transform.SetParent(parent);
            go.transform.position = p;
            var body = Make("Pad", go.transform, MeshKit.Cylinder(8, 0.8f), Mats.Toon(new Color(0.38f, 0.62f, 0.32f), 1.4f));
            body.transform.localScale = new Vector3(0.22f, R(0.5f, 0.85f), 0.22f);
            var arm = Make("Arm", go.transform, MeshKit.Cylinder(6, 0.8f), Mats.Toon(new Color(0.42f, 0.66f, 0.34f), 1.2f));
            arm.transform.localPosition = new Vector3(0.16f, 0.35f, 0);
            arm.transform.localRotation = Quaternion.Euler(0, 0, 70);
            arm.transform.localScale = new Vector3(0.12f, 0.28f, 0.12f);
        }

        static void BuildFences(Transform parent)
        {
            var mat = Mats.Toon(new Color(0.96f, 0.93f, 0.86f));
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
            {
                if (GlenMap.At(x, y) != Tile.Fence) continue;
                var p = GlenMap.ToWorld(new Vector2Int(x, y));
                var post = Make("FencePost", parent, MeshKit.Box(), mat);
                post.transform.position = p + Vector3.up * 0.3f;
                post.transform.localScale = new Vector3(0.14f, 0.6f, 0.14f);
                if (GlenMap.At(x + 1, y) == Tile.Fence) Rails(parent, p, Vector3.right, mat);
                if (GlenMap.At(x, y + 1) == Tile.Fence) Rails(parent, p, Vector3.back, mat);
            }
            // Vegetable rows inside the fenced garden.
            for (int y = 8 + GlenMap.Oy; y <= 10 + GlenMap.Oy; y++)
            for (int x = 3 + GlenMap.Ox; x <= 8 + GlenMap.Ox; x++)
            {
                var p = GlenMap.ToWorld(new Vector2Int(x, y));
                var soil = Make("Soil", parent, MeshKit.Box(), Mats.Toon(new Color(0.6f, 0.42f, 0.3f), 0.8f));
                soil.transform.position = p + Vector3.up * 0.04f;
                soil.transform.localScale = new Vector3(0.8f, 0.08f, 0.8f);
                if ((x + y) % 2 == 0)
                {
                    var crop = Make("Crop", parent, MeshKit.Blob(1, 0.3f, x), Mats.Toon(LeafLight, wind: 0.2f));
                    crop.transform.position = p + Vector3.up * 0.22f;
                    crop.transform.localScale = new Vector3(0.38f, 0.3f, 0.38f);
                }
            }
        }

        static void Rails(Transform parent, Vector3 p, Vector3 dir, Material mat)
        {
            foreach (float h in new[] { 0.22f, 0.44f })
            {
                var rail = Make("FenceRail", parent, MeshKit.Box(), mat);
                rail.transform.position = p + dir * 0.5f + Vector3.up * h;
                rail.transform.localScale = dir.x != 0 ? new Vector3(1f, 0.08f, 0.06f) : new Vector3(0.06f, 0.08f, 1f);
            }
        }

        // ---- Buildings -----------------------------------------------------------------

        static void BuildBuilding(Transform parent, Building b, GlenWorld world)
        {
            int H = GlenMap.Height;
            var center = new Vector3(b.Rect.x + b.Rect.width / 2f, 0, H - b.Rect.y - b.Rect.height / 2f);
            var kit = Kit(b.Kind, parent);
            if (kit)
            {
                kit.transform.position = center;
                HarvestWindows(kit, world);
                if (b.Kind == "house")
                {
                    var chim = FindNamed(kit.transform, "chimney") ?? FindNamed(kit.transform, "chimcap");
                    if (chim)
                    {
                        var top = new GameObject("ChimneyTop").transform;
                        top.SetParent(chim, false);
                        top.localPosition = Vector3.up * 0.9f;
                        world.ChimneyTop = top;
                    }
                }
                return;
            }
            var root = new GameObject(b.Name);
            root.transform.SetParent(parent);
            root.transform.position = center;
            float w = b.Rect.width - 0.4f, d = b.Rect.height - 0.4f;

            if (b.Kind == "pavilion")
            {
                foreach (var (sx, sz) in new[] { (-1, -1), (1, -1), (-1, 1), (1, 1) })
                {
                    var post = Make("Post", root.transform, MeshKit.Cylinder(8), Mats.Toon(Wood));
                    post.transform.localPosition = new Vector3(sx * (w / 2 - 0.2f), 0, sz * (d / 2 - 0.2f));
                    post.transform.localScale = new Vector3(0.22f, 2.0f, 0.22f);
                }
                var deck = Make("Deck", root.transform, MeshKit.Box(), Mats.Toon(b.Wall * 0.92f));
                deck.transform.localPosition = Vector3.up * 0.08f;
                deck.transform.localScale = new Vector3(w, 0.16f, d);
                var roof = Make("Roof", root.transform, MeshKit.Roof(), Mats.Toon(b.Roof));
                roof.transform.localPosition = Vector3.up * 2.0f;
                roof.transform.localScale = new Vector3(w + 0.6f, 1.1f, d + 0.8f);
                AddBlobShadow(root.transform, w * 0.6f);
                return;
            }

            float wallH = b.Kind == "house" ? 2.1f : 1.7f;
            var walls = Make("Walls", root.transform, MeshKit.Box(), Mats.Toon(b.Wall));
            walls.transform.localPosition = Vector3.up * wallH / 2;
            walls.transform.localScale = new Vector3(w, wallH, d);
            // Timber base band.
            var band = Make("Base", root.transform, MeshKit.Box(), Mats.Toon(Wood * 0.85f));
            band.transform.localPosition = Vector3.up * 0.15f;
            band.transform.localScale = new Vector3(w + 0.08f, 0.3f, d + 0.08f);

            var roofGo = Make("Roof", root.transform, MeshKit.Roof(), Mats.Toon(b.Roof));
            roofGo.transform.localPosition = Vector3.up * wallH;
            roofGo.transform.localScale = new Vector3(w + 0.5f, b.Kind == "house" ? 1.5f : 1.1f, d + 0.6f);

            // Door faces south (toward the camera), at the door column.
            float doorX = b.Door.x + 0.5f - center.x;
            var door = Make("Door", root.transform, MeshKit.Box(), Mats.Toon(new Color(0.48f, 0.3f, 0.2f)));
            door.transform.localPosition = new Vector3(doorX, 0.6f, -d / 2 - 0.02f);
            door.transform.localScale = new Vector3(0.75f, 1.2f, 0.08f);
            var step = Make("Step", root.transform, MeshKit.Box(), Mats.Toon(Stone));
            step.transform.localPosition = new Vector3(doorX, 0.05f, -d / 2 - 0.3f);
            step.transform.localScale = new Vector3(1f, 0.1f, 0.45f);

            // Windows glow at night (DayNightDirector drives WindowMats emission).
            var windowMat = new Material(Mats.Toon(new Color(0.55f, 0.75f, 0.9f))) { name = "Window" };
            world.WindowMats.Add(windowMat);
            for (float wx = -w / 2 + 0.9f; wx < w / 2 - 0.5f; wx += 1.6f)
            {
                if (Mathf.Abs(wx - doorX) < 0.8f) continue;
                var win = Make("Window", root.transform, MeshKit.Box(), windowMat);
                win.transform.localPosition = new Vector3(wx, wallH * 0.58f, -d / 2 - 0.03f);
                win.transform.localScale = new Vector3(0.6f, 0.55f, 0.06f);
                var sill = Make("Sill", root.transform, MeshKit.Box(), Mats.Toon(Color.white));
                sill.transform.localPosition = new Vector3(wx, wallH * 0.58f - 0.32f, -d / 2 - 0.07f);
                sill.transform.localScale = new Vector3(0.74f, 0.08f, 0.14f);
                var box = Make("FlowerBox", root.transform, MeshKit.Blob(1, 0.3f, (int)(wx * 10)), Mats.Toon(Blossom, wind: 0.1f));
                box.transform.localPosition = new Vector3(wx, wallH * 0.58f - 0.26f, -d / 2 - 0.14f);
                box.transform.localScale = new Vector3(0.36f, 0.12f, 0.12f);
            }

            if (b.Kind == "house")
            {
                var chimney = Make("Chimney", root.transform, MeshKit.Box(), Mats.Toon(new Color(0.78f, 0.5f, 0.42f)));
                chimney.transform.localPosition = new Vector3(w / 2 - 1.2f, wallH + 1.1f, 0.6f);
                chimney.transform.localScale = new Vector3(0.5f, 1.4f, 0.5f);
                var top = new GameObject("ChimneyTop").transform;
                top.SetParent(root.transform);
                top.localPosition = new Vector3(w / 2 - 1.2f, wallH + 1.9f, 0.6f);
                world.ChimneyTop = top;
            }
            else
            {
                for (int i = 0; i < 3; i++)
                {
                    var crate = Make("Crate", root.transform, MeshKit.Box(), Mats.Toon(Wood * (0.9f + i * 0.05f)));
                    crate.transform.localPosition = new Vector3(w / 2 + 0.3f, 0.25f + (i == 2 ? 0.5f : 0), -d / 2 + 0.4f + (i == 1 ? 0.55f : 0));
                    crate.transform.localScale = Vector3.one * 0.5f;
                    crate.transform.localRotation = Quaternion.Euler(0, i * 17, 0);
                }
            }
            AddBlobShadow(root.transform, w * 0.62f);
        }

        // ---- Spots ---------------------------------------------------------------------

        static void BuildSpot(Transform parent, Spot s, GlenWorld world)
        {
            var p = GlenMap.ToWorld(s.Cell);
            switch (s.Kind)
            {
                case "bowl":
                {
                    var bowl = Make("Bowl", parent, MeshKit.Cylinder(14, 1.35f), Mats.Toon(new Color(0.42f, 0.62f, 0.9f)));
                    bowl.transform.position = p + Vector3.up * 0.16f;
                    bowl.transform.localScale = new Vector3(0.5f, 0.18f, 0.5f);
                    var food = Make("Food", parent, MeshKit.Blob(1, 0.4f, 3), Mats.Toon(new Color(0.95f, 0.5f, 0.45f), 0.8f));
                    food.transform.position = p + Vector3.up * 0.36f;
                    food.transform.localScale = new Vector3(0.5f, 0.14f, 0.5f);
                    world.BowlFood = food.transform;
                    break;
                }
                case "rune":
                {
                    var stone = Make("RuneStone", parent, MeshKit.Blob(1, 0.2f, s.Cell.x), Mats.Toon(new Color(0.66f, 0.68f, 0.74f)));
                    stone.transform.position = p + Vector3.up * 0.55f;
                    stone.transform.localScale = new Vector3(0.55f, 1.1f, 0.4f);
                    var glyphMat = new Material(Mats.Toon(new Color(0.5f, 0.9f, 1f), 0.5f)) { name = "Glyph" + s.Id };
                    var glyph = Make("Glyph", parent, MeshKit.Box(), glyphMat);
                    glyph.transform.position = p + new Vector3(0, 0.7f, -0.2f);
                    glyph.transform.localScale = new Vector3(0.22f, 0.32f, 0.04f);
                    glyph.transform.rotation = Quaternion.Euler(0, 0, 45);
                    world.Runes[s.Id] = glyph.GetComponent<Renderer>();
                    AddBlobShadow(stone.transform.parent, 0.4f, p);
                    break;
                }
                case "berrybush":
                {
                    var bush = Make("BerryBush", parent, MeshKit.Blob(2, 0.3f, s.Cell.y), Mats.Toon(Leaf * 0.95f, wind: 0.08f));
                    bush.transform.position = p + Vector3.up * 0.4f;
                    bush.transform.localScale = new Vector3(0.9f, 0.7f, 0.9f);
                    var berries = new GameObject("Berries");
                    berries.transform.SetParent(parent);
                    for (int i = 0; i < 6; i++)
                    {
                        var berry = Make("Berry", berries.transform, MeshKit.Blob(1), Mats.Toon(new Color(0.95f, 0.32f, 0.36f), 0.8f));
                        float a = i / 6f * Mathf.PI * 2;
                        berry.transform.position = p + new Vector3(Mathf.Cos(a) * 0.38f, 0.45f + (i % 2) * 0.2f, Mathf.Sin(a) * 0.38f - 0.05f);
                        berry.transform.localScale = Vector3.one * 0.13f;
                    }
                    world.Berries[s.Id] = berries;
                    break;
                }
                case "lamp":
                {
                    var post = Make("LampPost", parent, MeshKit.Cylinder(8), Mats.Toon(new Color(0.3f, 0.3f, 0.36f)));
                    post.transform.position = p;
                    post.transform.localScale = new Vector3(0.1f, 1.6f, 0.1f);
                    var head = Make("Lantern", parent, MeshKit.Box(), Mats.Toon(new Color(1f, 0.92f, 0.6f), 1.2f, emission: new Color(0.9f, 0.7f, 0.3f)));
                    head.transform.position = p + Vector3.up * 1.75f;
                    head.transform.localScale = new Vector3(0.28f, 0.34f, 0.28f);
                    var light = new GameObject("LampLight").AddComponent<Light>();
                    light.transform.SetParent(parent);
                    light.transform.position = p + Vector3.up * 1.7f;
                    light.type = LightType.Point;
                    light.color = new Color(1f, 0.78f, 0.45f);
                    light.range = 4.5f;
                    light.intensity = 0;
                    world.Lamps.Add(light);
                    break;
                }
                case "sign":
                {
                    var post = Make("SignPost", parent, MeshKit.Box(), Mats.Toon(Wood * 0.8f));
                    post.transform.position = p + Vector3.up * 0.4f;
                    post.transform.localScale = new Vector3(0.1f, 0.8f, 0.1f);
                    var board = Make("SignBoard", parent, MeshKit.Box(), Mats.Toon(Wood));
                    board.transform.position = p + new Vector3(0, 0.75f, -0.05f);
                    board.transform.localScale = new Vector3(0.7f, 0.4f, 0.08f);
                    break;
                }
                case "farm":
                {
                    var soil = Make("Plot", parent, MeshKit.Box(), Mats.Toon(new Color(0.55f, 0.38f, 0.26f), 0.6f));
                    soil.transform.position = p + Vector3.up * 0.05f;
                    soil.transform.localScale = new Vector3(0.85f, 0.08f, 0.85f);
                    var sprout = Make("Sprout", parent, MeshKit.Blob(1, 0.3f, s.Cell.x), Mats.Toon(Crop, wind: 0.2f));
                    sprout.transform.position = p + Vector3.up * 0.18f;
                    sprout.transform.localScale = new Vector3(0.35f, 0.22f, 0.35f);
                    world.Crops[s.Id] = sprout;
                    break;
                }
                case "lookout":
                {
                    var pier = Make("Pier", parent, MeshKit.Box(), Mats.Toon(Wood));
                    pier.transform.position = p + Vector3.up * 0.08f;
                    pier.transform.localScale = new Vector3(1.6f, 0.12f, 2.4f);
                    break;
                }
                case "mailbox":
                {
                    var post = Make("MailPost", parent, MeshKit.Box(), Mats.Toon(Wood * 0.8f));
                    post.transform.position = p + Vector3.up * 0.4f;
                    post.transform.localScale = new Vector3(0.1f, 0.8f, 0.1f);
                    var box = Make("Mailbox", parent, MeshKit.Box(), Mats.Toon(new Color(0.88f, 0.36f, 0.32f)));
                    box.transform.position = p + Vector3.up * 0.85f;
                    box.transform.localScale = new Vector3(0.3f, 0.28f, 0.45f);
                    break;
                }
            }
        }

        // ---- Helpers -------------------------------------------------------------------

        public static GameObject Make(string name, Transform parent, Mesh mesh, Material mat)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = mat;
            return go;
        }

        static Mesh shadowMesh;

        /// Soft contact shadow disc under props and characters (the baked-AO look of 3DS-era games).
        public static GameObject AddBlobShadow(Transform parent, float radius, Vector3? at = null)
        {
            if (shadowMesh == null)
            {
                var b = new MeshKit.Builder();
                const int seg = 20;
                var core = new Color(0.08f, 0.05f, 0.12f, 0.34f);
                var edge = new Color(0.08f, 0.05f, 0.12f, 0f);
                for (int i = 0; i < seg; i++)
                {
                    float a0 = i / (float)seg * Mathf.PI * 2, a1 = (i + 1) / (float)seg * Mathf.PI * 2;
                    b.Tri(Vector3.zero, new Vector3(Mathf.Cos(a1), 0, Mathf.Sin(a1)), new Vector3(Mathf.Cos(a0), 0, Mathf.Sin(a0)), core, edge, edge);
                }
                shadowMesh = b.Build();
                shadowMesh.name = "BlobShadow";
            }
            var go = new GameObject("BlobShadow");
            go.transform.SetParent(parent, false);
            if (at.HasValue) go.transform.position = at.Value;
            go.transform.localPosition += Vector3.up * 0.02f;
            go.transform.localScale = new Vector3(radius, 1, radius) * 1.1f;
            go.AddComponent<MeshFilter>().sharedMesh = shadowMesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = Mats.Particle(false, 3);
            return go;
        }

        public static GameObject Kit(string name, Transform parent)
        {
            var prefab = Resources.Load<GameObject>("Kit/" + name);
            if (!prefab) return null;
            var go = Object.Instantiate(prefab, parent);
            Mats.ToonifyHierarchy(go, 1.6f);
            return go;
        }

        static void HarvestWindows(GameObject go, GlenWorld world)
        {
            foreach (var r in go.GetComponentsInChildren<Renderer>(true))
            {
                foreach (var m in r.materials)
                {
                    if (m == null) continue;
                    if (m.name.IndexOf("Window", System.StringComparison.OrdinalIgnoreCase) < 0) continue;
                    world.WindowMats.Add(m);
                }
            }
        }

        static Transform FindNamed(Transform root, string name)
        {
            foreach (var t in root.GetComponentsInChildren<Transform>(true))
                if (t.name.IndexOf(name, System.StringComparison.OrdinalIgnoreCase) >= 0) return t;
            return null;
        }
    }
}
