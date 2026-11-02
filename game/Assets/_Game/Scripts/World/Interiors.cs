using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    public sealed class InteriorRoom
    {
        public string Kind;
        public Transform Root;
        public Vector3 Entry;
        public Vector3 Bed;
        public Vector3 Stove;
        public Vector3 Bench;
        /// Shop counter or lab desk: where the keeper talks to whoever runs the place.
        public Vector3 Counter;
        public Bounds Walk;
        public Bounds Cam;
    }

    /// Furnished diorama rooms the keeper walks into. Built far off the map so the
    /// overworld stays put; we teleport in and out.
    public static class Interiors
    {
        static readonly Vector3 Far = new(0, -100, 0);

        public static Dictionary<string, InteriorRoom> BuildAll()
        {
            float x0 = GlenMap.Width + 30;
            return new Dictionary<string, InteriorRoom>
            {
                ["house"] = Build("house", new Vector3(x0, 0, 22), new Color(0.97f, 0.9f, 0.78f), new Color(0.86f, 0.33f, 0.28f)),
                ["shed"] = Build("shed", new Vector3(x0 + 16, 0, 22), new Color(0.8f, 0.62f, 0.42f), new Color(0.36f, 0.5f, 0.72f)),
                ["cottage"] = Build("cottage", new Vector3(x0 + 32, 0, 22), new Color(0.96f, 0.86f, 0.66f), new Color(0.78f, 0.38f, 0.22f)),
                ["shop"] = Build("shop", new Vector3(x0 + 48, 0, 22), new Color(0.9f, 0.95f, 1f), new Color(0.25f, 0.45f, 0.82f)),
                ["lab"] = Build("lab", new Vector3(x0 + 64, 0, 22), new Color(0.95f, 0.97f, 0.97f), new Color(0.36f, 0.62f, 0.5f)),
            };
        }

        static InteriorRoom Build(string kind, Vector3 origin, Color wall, Color accent)
        {
            var root = new GameObject("Interior_" + kind).transform;
            root.position = origin;
            bool big = kind is "house" or "shop" or "lab";
            float w = big ? 9f : 7f, d = big ? 7f : 5.6f, h = 2.8f;
            var rng = new System.Random(kind.GetHashCode());

            GameObject Box(string n, Vector3 pos, Vector3 scale, Color col, float outline = 0.8f, Color? glow = null)
            {
                var go = GlenBuilder.Make(n, root, MeshKit.Box(), Mats.Toon(col, outline, emission: glow));
                go.transform.localPosition = pos;
                go.transform.localScale = scale;
                return go;
            }
            GameObject Cyl(string n, Vector3 pos, Vector3 scale, Color col, float outline = 0.8f, Color? glow = null)
            {
                var go = GlenBuilder.Make(n, root, MeshKit.Cylinder(14), Mats.Toon(col, outline, emission: glow));
                go.transform.localPosition = pos;
                go.transform.localScale = scale;
                return go;
            }
            GameObject Ball(string n, Vector3 pos, Vector3 scale, Color col, float outline = 0.8f, Color? glow = null)
            {
                var go = GlenBuilder.Make(n, root, MeshKit.Blob(1), Mats.Toon(col, outline, emission: glow));
                go.transform.localPosition = pos;
                go.transform.localScale = scale;
                return go;
            }
            Color Shade(Color c, float k) => new(c.r * k, c.g * k, c.b * k, 1);
            Light PointLight(Vector3 pos, Color col, float range, float intensity)
            {
                var l = new GameObject("Light").AddComponent<Light>();
                l.transform.SetParent(root, false);
                l.transform.localPosition = pos;
                l.type = LightType.Point;
                l.color = col;
                l.range = range;
                l.intensity = intensity;
                return l;
            }

            // ---- Shell: plank floor, wainscot walls, beams, windows ------------------------
            Color wood = kind == "lab" ? new Color(0.82f, 0.8f, 0.76f) : new Color(0.72f, 0.54f, 0.36f);
            int planks = Mathf.RoundToInt(w / 0.5f);
            for (int i = 0; i < planks; i++)
                Box("Plank", new Vector3(-w / 2 + 0.25f + i * 0.5f, -0.04f, 0), new Vector3(0.48f, 0.08f, d), Shade(wood, i % 2 == 0 ? 1f : 0.92f), 0.1f);
            Color lower = kind == "lab" ? new Color(0.62f, 0.78f, 0.74f) : Shade(accent, 0.8f);
            foreach (var (pos, size) in new[]
            {
                (new Vector3(0, 0, d / 2), new Vector3(w, 0, 0.12f)),
                (new Vector3(-w / 2, 0, 0), new Vector3(0.12f, 0, d)),
                (new Vector3(w / 2, 0, 0), new Vector3(0.12f, 0, d)),
            })
            {
                Box("Wall", pos + Vector3.up * h / 2, new Vector3(size.x, h, size.z), wall);
                Box("Wainscot", pos + Vector3.up * 0.45f, new Vector3(size.x + 0.02f, 0.9f, size.z + 0.04f), lower, 0.4f);
                Box("Trim", pos + Vector3.up * 0.92f, new Vector3(size.x + 0.03f, 0.06f, size.z + 0.06f), Shade(wood, 0.8f), 0.2f);
            }
            Box("Ceiling", new Vector3(0, h, 0), new Vector3(w, 0.1f, d), Shade(wall, 1.03f), 0f);
            for (int i = -1; i <= 1; i++)
                Box("Beam", new Vector3(i * w / 3, h - 0.12f, 0), new Vector3(0.18f, 0.18f, d), Shade(wood, 0.7f), 0.3f);
            foreach (float wx in new[] { -w * 0.22f, w * 0.22f })
            {
                Box("WindowFrame", new Vector3(wx, 1.65f, d / 2 - 0.07f), new Vector3(1.1f, 0.9f, 0.05f), Shade(wood, 0.85f), 0.3f);
                Box("WindowPane", new Vector3(wx, 1.65f, d / 2 - 0.1f), new Vector3(0.95f, 0.75f, 0.03f), new Color(0.72f, 0.88f, 1f), 0f, new Color(0.35f, 0.5f, 0.65f));
                Box("Mullion", new Vector3(wx, 1.65f, d / 2 - 0.12f), new Vector3(0.05f, 0.75f, 0.02f), Shade(wood, 0.85f), 0f);
                Box("CurtainL", new Vector3(wx - 0.58f, 1.6f, d / 2 - 0.14f), new Vector3(0.18f, 1.05f, 0.04f), accent, 0.3f);
                Box("CurtainR", new Vector3(wx + 0.58f, 1.6f, d / 2 - 0.14f), new Vector3(0.18f, 1.05f, 0.04f), accent, 0.3f);
            }
            Box("Doorway", new Vector3(0, 0.95f, -d / 2 + 0.04f), new Vector3(1.15f, 1.9f, 0.08f), new Color(0.2f, 0.16f, 0.14f), 0.4f);
            Box("Doormat", new Vector3(0, 0.015f, -d / 2 + 0.6f), new Vector3(1.1f, 0.03f, 0.6f), Shade(accent, 0.7f), 0.2f);
            PointLight(new Vector3(0, 2.3f, 0), new Color(1f, 0.88f, 0.68f), 10, 1.3f);

            void Plant(Vector3 p, float s = 1f)
            {
                Cyl("Pot", p + Vector3.up * 0.18f * s, new Vector3(0.36f, 0.36f, 0.36f) * s, new Color(0.78f, 0.45f, 0.3f));
                for (int i = 0; i < 4; i++)
                    Ball("Leaves", p + new Vector3((float)rng.NextDouble() * 0.2f - 0.1f, 0.5f * s + i * 0.1f * s, (float)rng.NextDouble() * 0.2f - 0.1f),
                        Vector3.one * (0.34f - i * 0.04f) * s, new Color(0.36f, 0.64f, 0.34f) * (0.9f + i * 0.05f));
            }
            void Bookshelf(Vector3 p, float width)
            {
                Box("Shelf", p + Vector3.up * 0.9f, new Vector3(width, 1.8f, 0.4f), Shade(wood, 0.75f));
                Color[] books = { new(0.8f, 0.3f, 0.3f), new(0.3f, 0.5f, 0.8f), new(0.9f, 0.75f, 0.3f), new(0.4f, 0.65f, 0.4f), new(0.6f, 0.4f, 0.7f) };
                for (int row = 0; row < 3; row++)
                {
                    float y = 0.35f + row * 0.55f, x = -width / 2 + 0.12f;
                    while (x < width / 2 - 0.12f)
                    {
                        float bw = 0.08f + (float)rng.NextDouble() * 0.06f, bh = 0.3f + (float)rng.NextDouble() * 0.12f;
                        Box("Book", p + new Vector3(x + bw / 2, y + bh / 2, -0.06f), new Vector3(bw, bh, 0.26f), books[rng.Next(books.Length)], 0.2f);
                        x += bw + 0.01f;
                    }
                }
            }
            void Table(Vector3 p, bool stools)
            {
                Cyl("TableTop", p + Vector3.up * 0.72f, new Vector3(1.1f, 0.06f, 1.1f), Shade(wood, 1.05f));
                Cyl("TableLeg", p + Vector3.up * 0.36f, new Vector3(0.12f, 0.7f, 0.12f), Shade(wood, 0.8f));
                Ball("FruitBowl", p + Vector3.up * 0.8f, new Vector3(0.3f, 0.1f, 0.3f), new Color(0.95f, 0.92f, 0.86f));
                Ball("Fruit", p + new Vector3(0.05f, 0.86f, 0), Vector3.one * 0.1f, new Color(0.95f, 0.45f, 0.35f));
                Ball("Fruit", p + new Vector3(-0.06f, 0.86f, 0.04f), Vector3.one * 0.1f, new Color(0.98f, 0.8f, 0.3f));
                if (!stools) return;
                foreach (float sx in new[] { -0.8f, 0.8f })
                    Cyl("Stool", p + new Vector3(sx, 0.25f, 0), new Vector3(0.4f, 0.5f, 0.4f), Shade(wood, 0.9f));
            }
            void Frame(Vector3 p, Color art)
            {
                Box("Frame", p, new Vector3(0.7f, 0.55f, 0.04f), Shade(wood, 0.6f), 0.3f);
                Box("Art", p + new Vector3(0, 0, -0.03f), new Vector3(0.58f, 0.43f, 0.02f), art, 0f);
                Ball("ArtSun", p + new Vector3(0.12f, 0.08f, -0.05f), new Vector3(0.12f, 0.12f, 0.02f), new Color(1f, 0.85f, 0.4f), 0f);
            }
            void Rug(Vector3 p, float r, Color c)
            {
                Cyl("Rug", p + Vector3.up * 0.01f, new Vector3(r, 0.02f, r * 0.7f), c, 0.2f);
                Cyl("RugInner", p + Vector3.up * 0.02f, new Vector3(r * 0.7f, 0.02f, r * 0.5f), Shade(c, 1.2f), 0f);
            }
            Light Hearth(Vector3 p)
            {
                Box("Fireplace", p + Vector3.up * 0.6f, new Vector3(1.5f, 1.2f, 0.5f), new Color(0.62f, 0.6f, 0.58f));
                Box("Mantel", p + new Vector3(0, 1.22f, -0.05f), new Vector3(1.7f, 0.1f, 0.6f), Shade(wood, 0.8f));
                Box("Firebox", p + new Vector3(0, 0.42f, -0.2f), new Vector3(0.9f, 0.62f, 0.14f), new Color(0.15f, 0.1f, 0.08f), 0f);
                Ball("Flame", p + new Vector3(0, 0.38f, -0.24f), new Vector3(0.4f, 0.32f, 0.12f), new Color(1f, 0.6f, 0.2f), 0f, new Color(1.6f, 0.7f, 0.15f));
                Ball("Candle", p + new Vector3(0.55f, 1.35f, -0.05f), new Vector3(0.06f, 0.12f, 0.06f), new Color(1f, 0.95f, 0.85f), 0f, new Color(0.6f, 0.45f, 0.2f));
                var l = PointLight(p + new Vector3(0, 0.6f, -0.8f), new Color(1f, 0.62f, 0.3f), 5, 1.6f);
                l.gameObject.AddComponent<Flicker>();
                return l;
            }

            Vector3 bed = Far, stove = Far, bench = Far, counter = Far;
            switch (kind)
            {
                case "house":
                case "cottage":
                {
                    float s = kind == "house" ? 1f : 0.85f;
                    // Bed corner.
                    var bp = new Vector3(-w / 2 + 1.2f, 0, d / 2 - 1.4f);
                    Box("BedFrame", bp + Vector3.up * 0.2f, new Vector3(1.3f, 0.3f, 2.1f) * s, Shade(wood, 0.85f));
                    Box("Headboard", bp + new Vector3(0, 0.55f, 1.02f * s), new Vector3(1.3f * s, 0.8f, 0.1f), Shade(wood, 0.75f));
                    Box("Mattress", bp + Vector3.up * 0.4f, new Vector3(1.2f, 0.16f, 2f) * s, new Color(0.96f, 0.95f, 0.92f), 0.4f);
                    Box("Blanket", bp + new Vector3(0, 0.5f, -0.25f * s), new Vector3(1.24f, 0.06f, 1.4f) * s, accent, 0.4f);
                    Box("Pillow", bp + new Vector3(0, 0.55f, 0.75f * s), new Vector3(0.7f, 0.14f, 0.36f) * s, Color.white, 0.3f);
                    Box("Nightstand", bp + new Vector3(0.95f * s, 0.3f, 0.75f * s), new Vector3(0.5f, 0.6f, 0.45f), Shade(wood, 0.95f));
                    Cyl("LampBase", bp + new Vector3(0.95f * s, 0.7f, 0.75f * s), new Vector3(0.12f, 0.2f, 0.12f), new Color(0.9f, 0.85f, 0.7f));
                    Cyl("LampShade", bp + new Vector3(0.95f * s, 0.92f, 0.75f * s), new Vector3(0.32f, 0.22f, 0.32f), new Color(1f, 0.92f, 0.72f), 0.3f, new Color(0.5f, 0.38f, 0.15f));
                    PointLight(bp + new Vector3(0.95f * s, 1.1f, 0.5f), new Color(1f, 0.8f, 0.5f), 3.5f, 0.8f);
                    bed = origin + bp;
                    // Hearth and kitchen along the back.
                    Hearth(new Vector3(0, 0, d / 2 - 0.3f));
                    var kp = new Vector3(w / 2 - 1.3f, 0, d / 2 - 0.5f);
                    Box("Counter", kp + Vector3.up * 0.45f, new Vector3(1.9f, 0.9f, 0.7f), Shade(wood, 0.95f));
                    Box("Worktop", kp + Vector3.up * 0.92f, new Vector3(2f, 0.06f, 0.76f), new Color(0.9f, 0.88f, 0.84f), 0.3f);
                    Box("Stove", kp + new Vector3(-0.5f, 0.97f, 0), new Vector3(0.6f, 0.06f, 0.5f), new Color(0.25f, 0.25f, 0.28f));
                    Cyl("Pot", kp + new Vector3(-0.5f, 1.1f, 0), new Vector3(0.32f, 0.22f, 0.32f), new Color(0.75f, 0.35f, 0.25f));
                    Ball("Kettle", kp + new Vector3(0.45f, 1.06f, 0), new Vector3(0.24f, 0.2f, 0.24f), new Color(0.4f, 0.6f, 0.72f));
                    Box("WallShelf", kp + new Vector3(0, 1.75f, 0.2f), new Vector3(1.6f, 0.06f, 0.28f), Shade(wood, 0.8f));
                    for (int i = 0; i < 4; i++)
                        Cyl("Jar", kp + new Vector3(-0.6f + i * 0.4f, 1.9f, 0.2f), new Vector3(0.16f, 0.22f, 0.16f), Color.HSVToRGB(i * 0.2f, 0.4f, 0.95f), 0.3f);
                    stove = origin + kp;
                    // Living area.
                    Rug(new Vector3(0.4f, 0, -0.3f), 2.6f * s, Shade(accent, 0.95f));
                    Table(new Vector3(w / 2 - 1.6f, 0, -0.6f), true);
                    bench = origin + new Vector3(w / 2 - 1.6f, 0, -0.6f);
                    if (kind == "house") Bookshelf(new Vector3(-w / 2 + 0.3f, 0, -0.6f), 1.4f);
                    Box("Armchair", new Vector3(-0.9f, 0.3f, 0.2f), new Vector3(0.8f, 0.5f, 0.75f), Shade(accent, 0.75f), 0.5f);
                    Box("ArmchairBack", new Vector3(-0.9f, 0.7f, 0.52f), new Vector3(0.8f, 0.6f, 0.15f), Shade(accent, 0.7f), 0.5f);
                    Box("KinBasket", new Vector3(0.9f, 0.12f, 0.6f), new Vector3(0.9f, 0.2f, 0.7f), new Color(0.82f, 0.66f, 0.42f), 0.4f);
                    Ball("Cushion", new Vector3(0.9f, 0.24f, 0.6f), new Vector3(0.7f, 0.12f, 0.5f), new Color(0.98f, 0.82f, 0.85f), 0.3f);
                    Frame(new Vector3(-w / 2 + 0.08f, 1.7f, -1.4f) + Vector3.right * 0.01f, new Color(0.5f, 0.75f, 0.9f));
                    Frame(new Vector3(w * 0.22f + 1.1f, 1.75f, d / 2 - 0.1f), new Color(0.55f, 0.82f, 0.5f));
                    Plant(new Vector3(-w / 2 + 0.45f, 0, -d / 2 + 0.6f), 1.1f);
                    Plant(new Vector3(w / 2 - 0.45f, 0, -d / 2 + 0.6f));
                    break;
                }
                case "shed":
                {
                    Rug(new Vector3(0, 0, 0.2f), 2.8f, new Color(0.5f, 0.58f, 0.44f));
                    Cyl("RingLine", new Vector3(0, 0.03f, 0.2f), new Vector3(2.2f, 0.01f, 1.5f), new Color(0.95f, 0.92f, 0.82f), 0f);
                    var wb = new Vector3(w / 2 - 1.3f, 0, d / 2 - 0.5f);
                    Box("Workbench", wb + Vector3.up * 0.45f, new Vector3(2f, 0.1f, 0.7f), Shade(wood, 0.9f));
                    Box("BenchLegs", wb + Vector3.up * 0.2f, new Vector3(1.8f, 0.4f, 0.6f), Shade(wood, 0.7f));
                    Box("Pegboard", wb + new Vector3(0, 1.45f, 0.22f), new Vector3(1.9f, 1f, 0.04f), new Color(0.82f, 0.7f, 0.5f), 0.3f);
                    for (int i = 0; i < 5; i++)
                        Box("Tool", wb + new Vector3(-0.75f + i * 0.37f, 1.45f, 0.18f), new Vector3(0.06f, 0.5f + (i % 2) * 0.2f, 0.04f), i % 2 == 0 ? new Color(0.5f, 0.5f, 0.55f) : Shade(wood, 0.6f), 0.3f);
                    bench = origin + new Vector3(0, 0, 0.2f);
                    for (int i = 0; i < 3; i++)
                        Box("Crate", new Vector3(-w / 2 + 0.6f + (i == 2 ? 0.3f : i * 0.75f), 0.3f + (i == 2 ? 0.6f : 0), d / 2 - 0.6f), Vector3.one * 0.62f, Shade(wood, 0.85f + i * 0.05f));
                    Box("HayBale", new Vector3(-w / 2 + 0.7f, 0.3f, -0.6f), new Vector3(0.9f, 0.6f, 0.6f), new Color(0.92f, 0.8f, 0.42f), 0.4f);
                    Cyl("DummyPole", new Vector3(w / 2 - 0.8f, 0.6f, -0.8f), new Vector3(0.12f, 1.2f, 0.12f), Shade(wood, 0.7f));
                    Ball("DummyBody", new Vector3(w / 2 - 0.8f, 1.05f, -0.8f), new Vector3(0.5f, 0.7f, 0.5f), new Color(0.85f, 0.75f, 0.55f), 0.5f);
                    Cyl("Lantern", new Vector3(0, h - 0.5f, 0.2f), new Vector3(0.22f, 0.3f, 0.22f), new Color(1f, 0.85f, 0.5f), 0.3f, new Color(1f, 0.7f, 0.3f));
                    PointLight(new Vector3(0, h - 0.7f, 0.2f), new Color(1f, 0.75f, 0.45f), 6, 1.2f).gameObject.AddComponent<Flicker>();
                    break;
                }
                case "shop":
                {
                    var cp = new Vector3(0, 0, d / 2 - 1.5f);
                    Box("Counter", cp + Vector3.up * 0.5f, new Vector3(3.2f, 1f, 0.7f), Shade(accent, 0.9f));
                    Box("CounterTop", cp + Vector3.up * 1.02f, new Vector3(3.3f, 0.06f, 0.8f), new Color(0.95f, 0.93f, 0.88f), 0.3f);
                    Box("Register", cp + new Vector3(1f, 1.15f, 0), new Vector3(0.45f, 0.25f, 0.35f), new Color(0.3f, 0.32f, 0.36f));
                    Box("RegisterScreen", cp + new Vector3(1f, 1.32f, -0.12f), new Vector3(0.3f, 0.12f, 0.02f), new Color(0.5f, 1f, 0.7f), 0f, new Color(0.2f, 0.6f, 0.35f));
                    var clerk = ChibiCharacter.Create(root, "npc_clerk", accent, new Color(0.25f, 0.18f, 0.14f), new Color(1f, 0.84f, 0.72f), false, Color.white);
                    clerk.transform.localPosition = cp + new Vector3(-0.4f, 0, 0.75f);
                    clerk.transform.localRotation = Quaternion.LookRotation(Vector3.back);
                    counter = origin + cp + new Vector3(0, 0, -0.8f);
                    Color[] goods = { new(0.95f, 0.4f, 0.35f), new(0.4f, 0.7f, 0.95f), new(0.95f, 0.8f, 0.3f), new(0.5f, 0.85f, 0.45f), new(0.85f, 0.55f, 0.9f) };
                    foreach (float sx in new[] { -w / 2 + 0.3f, w / 2 - 0.3f })
                    for (int z = 0; z < 2; z++)
                    {
                        var sp = new Vector3(sx, 0, -1.6f + z * 2.1f);
                        Box("ShopShelf", sp + Vector3.up * 0.95f, new Vector3(0.45f, 1.9f, 1.8f), Shade(wood, 0.8f));
                        for (int row = 0; row < 3; row++)
                        for (int i = 0; i < 4; i++)
                            Box("Goods", sp + new Vector3(-Mathf.Sign(sx) * 0.12f, 0.45f + row * 0.55f, -0.65f + i * 0.43f), new Vector3(0.28f, 0.3f, 0.3f), goods[(row + i + z) % goods.Length], 0.3f);
                    }
                    Table(new Vector3(-1.4f, 0, -0.9f), false);
                    Table(new Vector3(1.4f, 0, -0.9f), false);
                    Box("Sign", new Vector3(0, 2.2f, d / 2 - 0.1f), new Vector3(2.4f, 0.4f, 0.05f), accent, 0.3f, Shade(accent, 0.3f));
                    Plant(new Vector3(-w / 2 + 0.5f, 0, -d / 2 + 0.6f));
                    Plant(new Vector3(w / 2 - 0.5f, 0, -d / 2 + 0.6f));
                    break;
                }
                case "lab":
                {
                    var screen = new Vector3(0, 1.7f, d / 2 - 0.1f);
                    Box("KindexScreen", screen, new Vector3(3f, 1.4f, 0.06f), new Color(0.2f, 0.3f, 0.35f), 0.4f);
                    Box("KindexGlow", screen + new Vector3(0, 0, -0.04f), new Vector3(2.8f, 1.2f, 0.02f), new Color(0.55f, 0.95f, 0.85f), 0f, new Color(0.25f, 0.6f, 0.55f));
                    for (int i = 0; i < 3; i++)
                        Ball("Silhouette", screen + new Vector3(-0.9f + i * 0.9f, -0.1f, -0.07f), new Vector3(0.45f, 0.55f, 0.02f), Catalog.ElementColor(Catalog.All[i].Element), 0f);
                    var desk = new Vector3(0, 0, d / 2 - 1.6f);
                    Box("Desk", desk + Vector3.up * 0.42f, new Vector3(2.6f, 0.84f, 0.8f), new Color(0.88f, 0.9f, 0.9f));
                    Box("Monitor", desk + new Vector3(-0.6f, 1.12f, 0.15f), new Vector3(0.7f, 0.45f, 0.06f), new Color(0.25f, 0.28f, 0.32f));
                    Box("MonitorGlow", desk + new Vector3(-0.6f, 1.12f, 0.11f), new Vector3(0.6f, 0.36f, 0.02f), new Color(0.6f, 0.9f, 1f), 0f, new Color(0.3f, 0.5f, 0.6f));
                    var prof = ChibiCharacter.Create(root, "npc_prof", new Color(0.95f, 0.95f, 0.95f), new Color(0.55f, 0.55f, 0.6f), new Color(1f, 0.84f, 0.72f), false, new Color(0.4f, 0.55f, 0.5f));
                    prof.transform.localPosition = desk + new Vector3(0.6f, 0, 0.75f);
                    prof.transform.localRotation = Quaternion.LookRotation(Vector3.back);
                    counter = origin + desk + new Vector3(0, 0, -0.9f);
                    var heal = new Vector3(w / 2 - 1.2f, 0, 0.6f);
                    Cyl("HealBase", heal + Vector3.up * 0.3f, new Vector3(1.2f, 0.6f, 1.2f), new Color(0.85f, 0.88f, 0.9f));
                    Cyl("HealPad", heal + Vector3.up * 0.62f, new Vector3(1f, 0.04f, 1f), new Color(0.6f, 1f, 0.8f), 0f, new Color(0.3f, 0.8f, 0.5f));
                    PointLight(heal + Vector3.up * 1f, new Color(0.6f, 1f, 0.8f), 3, 1f);
                    bench = origin + heal;
                    Bookshelf(new Vector3(-w / 2 + 0.3f, 0, 0.2f), 1.8f);
                    Box("SpecimenTable", new Vector3(-1.4f, 0.42f, -0.9f), new Vector3(1.4f, 0.84f, 0.8f), new Color(0.88f, 0.9f, 0.9f));
                    for (int i = 0; i < 3; i++)
                        Cyl("Jar", new Vector3(-1.85f + i * 0.45f, 0.98f, -0.9f), new Vector3(0.2f, 0.28f, 0.2f), new Color(0.7f, 0.9f, 0.95f), 0.3f, i == 1 ? new Color(0.2f, 0.4f, 0.2f) : (Color?)null);
                    Plant(new Vector3(w / 2 - 0.5f, 0, -d / 2 + 0.6f), 1.2f);
                    Plant(new Vector3(-w / 2 + 0.5f, 0, -d / 2 + 0.6f));
                    break;
                }
            }

            var walk = new Bounds(origin + Vector3.up * 0.5f, new Vector3(w - 0.8f, 2, d - 0.8f));
            var cam = new Bounds(origin + Vector3.up * 0.6f, new Vector3(w + 2, 4, d + 2));
            var entry = origin + new Vector3(0, 0, -d / 2 + 0.9f);
            return new InteriorRoom { Kind = kind, Root = root, Entry = entry, Bed = bed, Stove = stove, Bench = bench, Counter = counter, Walk = walk, Cam = cam };
        }
    }

    /// Soft firelight flicker.
    public sealed class Flicker : MonoBehaviour
    {
        Light l;
        float baseI, seed;

        void Start()
        {
            l = GetComponent<Light>();
            baseI = l.intensity;
            seed = Random.value * 10f;
        }

        void Update() => l.intensity = baseI * (0.85f + Mathf.PerlinNoise(seed, Time.time * 3f) * 0.3f);
    }
}
