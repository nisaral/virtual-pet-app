using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// Small procedural mesh library. Everything is built once and shared, so the
    /// SRP Batcher can draw hundreds of trees and fence posts cheaply.
    public static class MeshKit
    {
        static readonly Dictionary<string, Mesh> Cache = new();

        static Mesh Cached(string key, System.Func<Mesh> build)
        {
            if (!Cache.TryGetValue(key, out var m) || m == null)
            {
                m = build();
                m.name = key;
                Cache[key] = m;
            }
            return m;
        }

        public static Mesh Box() => Cached("box", () =>
        {
            var b = new Builder();
            b.Box(Vector3.zero, Vector3.one, Color.white);
            return b.Build();
        });

        /// Unit sphere with smooth normals, optional lumpy noise for "hand-made" shapes.
        public static Mesh Blob(int subdiv = 2, float lump = 0f, int seed = 0) => Cached($"blob{subdiv}_{lump}_{seed}", () =>
        {
            var m = Icosphere(subdiv);
            if (lump > 0)
            {
                var v = m.vertices;
                var rng = new System.Random(seed);
                float ox = (float)rng.NextDouble() * 10, oy = (float)rng.NextDouble() * 10;
                for (int i = 0; i < v.Length; i++)
                {
                    var n = v[i].normalized;
                    float k = Mathf.PerlinNoise(n.x * 1.8f + ox, n.z * 1.8f + n.y + oy);
                    v[i] = n * (1f + (k - 0.5f) * lump);
                }
                m.vertices = v;
                m.RecalculateNormals();
                // Keep normals spherical so the toon terminator stays smooth and clean.
                var nn = new Vector3[v.Length];
                for (int i = 0; i < v.Length; i++) nn[i] = Vector3.Lerp(v[i].normalized, m.normals[i], 0.35f).normalized;
                m.normals = nn;
                m.RecalculateBounds();
            }
            return m;
        });

        public static Mesh Cylinder(int sides = 10, float topScale = 1f) => Cached($"cyl{sides}_{topScale}", () =>
        {
            var b = new Builder();
            b.Cylinder(Vector3.zero, 0.5f, 0.5f * topScale, 1f, sides, Color.white);
            return b.Build();
        });

        /// Triangular prism roof: ridge along local X, eaves at z = ±0.5, height 1.
        public static Mesh Roof() => Cached("roof", () =>
        {
            var b = new Builder();
            Vector3 a0 = new(-0.5f, 0, -0.5f), a1 = new(0.5f, 0, -0.5f), r0 = new(-0.5f, 1, 0), r1 = new(0.5f, 1, 0);
            Vector3 c0 = new(-0.5f, 0, 0.5f), c1 = new(0.5f, 0, 0.5f);
            b.Quad(a0, r0, r1, a1, Color.white);
            b.Quad(c1, r1, r0, c0, Color.white);
            b.Tri(a0, c0, r0, Color.white * 0.9f);
            b.Tri(a1, r1, c1, Color.white * 0.9f);
            return b.Build();
        });

        public static Mesh Quad() => Cached("quad", () =>
        {
            var b = new Builder();
            b.Quad(new Vector3(-0.5f, -0.5f, 0), new Vector3(-0.5f, 0.5f, 0), new Vector3(0.5f, 0.5f, 0), new Vector3(0.5f, -0.5f, 0), Color.white);
            return b.Build();
        });

        static Mesh Icosphere(int subdiv)
        {
            float t = (1f + Mathf.Sqrt(5f)) / 2f;
            var verts = new List<Vector3>
            {
                new(-1, t, 0), new(1, t, 0), new(-1, -t, 0), new(1, -t, 0),
                new(0, -1, t), new(0, 1, t), new(0, -1, -t), new(0, 1, -t),
                new(t, 0, -1), new(t, 0, 1), new(-t, 0, -1), new(-t, 0, 1),
            };
            var faces = new List<int>
            {
                0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11, 1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
                3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9, 4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1,
            };
            for (int i = 0; i < verts.Count; i++) verts[i] = verts[i].normalized;
            for (int s = 0; s < subdiv; s++)
            {
                var mid = new Dictionary<long, int>();
                var next = new List<int>();
                int Mid(int a, int b)
                {
                    long key = a < b ? ((long)a << 32) | (uint)b : ((long)b << 32) | (uint)a;
                    if (mid.TryGetValue(key, out int idx)) return idx;
                    verts.Add(((verts[a] + verts[b]) * 0.5f).normalized);
                    mid[key] = verts.Count - 1;
                    return verts.Count - 1;
                }
                for (int i = 0; i < faces.Count; i += 3)
                {
                    int a = faces[i], b = faces[i + 1], c = faces[i + 2];
                    int ab = Mid(a, b), bc = Mid(b, c), ca = Mid(c, a);
                    next.AddRange(new[] { a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca });
                }
                faces = next;
            }
            var mesh = new Mesh();
            mesh.SetVertices(verts);
            mesh.SetNormals(verts);
            var uv = new Vector2[verts.Count];
            for (int i = 0; i < uv.Length; i++) uv[i] = new Vector2(0.5f + Mathf.Atan2(verts[i].z, verts[i].x) / (2 * Mathf.PI), verts[i].y * 0.5f + 0.5f);
            mesh.uv = uv;
            var cols = new Color[verts.Count];
            for (int i = 0; i < cols.Length; i++) cols[i] = Color.white;
            mesh.colors = cols;
            // Unity is left-handed; the classic icosahedron table winds the other way.
            faces.Reverse();
            mesh.SetTriangles(faces, 0);
            mesh.RecalculateBounds();
            return mesh;
        }

        /// Accumulates flat-shaded geometry with vertex colours.
        public sealed class Builder
        {
            readonly List<Vector3> v = new();
            readonly List<Vector3> n = new();
            readonly List<Color> c = new();
            readonly List<Vector2> uv = new();
            readonly List<int> t = new();

            public int VertexCount => v.Count;

            public void Quad(Vector3 a, Vector3 b, Vector3 cc, Vector3 d, Color col) => Quad(a, b, cc, d, col, col, col, col);

            /// a→b→c→d clockwise when seen from the front.
            public void Quad(Vector3 a, Vector3 b, Vector3 cc, Vector3 d, Color ca, Color cb, Color ccol, Color cd)
            {
                var normal = Vector3.Cross(b - a, d - a).normalized;
                int i = v.Count;
                v.Add(a); v.Add(b); v.Add(cc); v.Add(d);
                n.Add(normal); n.Add(normal); n.Add(normal); n.Add(normal);
                c.Add(ca); c.Add(cb); c.Add(ccol); c.Add(cd);
                uv.Add(new Vector2(0, 0)); uv.Add(new Vector2(0, 1)); uv.Add(new Vector2(1, 1)); uv.Add(new Vector2(1, 0));
                t.Add(i); t.Add(i + 1); t.Add(i + 2);
                t.Add(i); t.Add(i + 2); t.Add(i + 3);
            }

            public void Tri(Vector3 a, Vector3 b, Vector3 cc, Color col) => Tri(a, b, cc, col, col, col);

            public void Tri(Vector3 a, Vector3 b, Vector3 cc, Color ca, Color cb, Color ccol)
            {
                var normal = Vector3.Cross(b - a, cc - a).normalized;
                int i = v.Count;
                v.Add(a); v.Add(b); v.Add(cc);
                n.Add(normal); n.Add(normal); n.Add(normal);
                c.Add(ca); c.Add(cb); c.Add(ccol);
                uv.Add(Vector2.zero); uv.Add(Vector2.up); uv.Add(Vector2.one);
                t.Add(i); t.Add(i + 1); t.Add(i + 2);
            }

            public void Box(Vector3 center, Vector3 size, Color col)
            {
                Vector3 h = size * 0.5f;
                Vector3 P(float x, float y, float z) => center + new Vector3(x * h.x, y * h.y, z * h.z);
                Quad(P(-1, -1, -1), P(-1, 1, -1), P(1, 1, -1), P(1, -1, -1), col);       // front (-z)
                Quad(P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1), P(-1, -1, 1), col * 0.92f);    // back
                Quad(P(-1, -1, 1), P(-1, 1, 1), P(-1, 1, -1), P(-1, -1, -1), col * 0.96f); // left
                Quad(P(1, -1, -1), P(1, 1, -1), P(1, 1, 1), P(1, -1, 1), col * 0.96f);     // right
                Quad(P(-1, 1, -1), P(-1, 1, 1), P(1, 1, 1), P(1, 1, -1), col);             // top
                Quad(P(-1, -1, 1), P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), col * 0.8f);  // bottom
            }

            public void Cylinder(Vector3 baseCenter, float r0, float r1, float height, int sides, Color col)
            {
                int start = v.Count;
                for (int s = 0; s <= sides; s++)
                {
                    float a = s / (float)sides * Mathf.PI * 2;
                    var dir = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                    v.Add(baseCenter + dir * r0);
                    v.Add(baseCenter + dir * r1 + Vector3.up * height);
                    var slope = new Vector3(dir.x * height, r0 - r1, dir.z * height).normalized;
                    n.Add(slope); n.Add(slope);
                    c.Add(col); c.Add(col);
                    uv.Add(new Vector2(s / (float)sides, 0)); uv.Add(new Vector2(s / (float)sides, 1));
                }
                for (int s = 0; s < sides; s++)
                {
                    int i = start + s * 2;
                    t.Add(i); t.Add(i + 1); t.Add(i + 3);
                    t.Add(i); t.Add(i + 3); t.Add(i + 2);
                }
                if (r1 > 0.001f)
                {
                    int center = v.Count;
                    v.Add(baseCenter + Vector3.up * height); n.Add(Vector3.up); c.Add(col); uv.Add(Vector2.one * 0.5f);
                    for (int s = 0; s <= sides; s++)
                    {
                        float a = s / (float)sides * Mathf.PI * 2;
                        v.Add(baseCenter + new Vector3(Mathf.Cos(a) * r1, height, Mathf.Sin(a) * r1));
                        n.Add(Vector3.up); c.Add(col); uv.Add(Vector2.zero);
                    }
                    for (int s = 0; s < sides; s++) { t.Add(center); t.Add(center + s + 2); t.Add(center + s + 1); }
                }
            }

            public Mesh Build()
            {
                var m = new Mesh { indexFormat = v.Count > 65000 ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16 };
                m.SetVertices(v);
                m.SetNormals(n);
                m.SetColors(c);
                m.SetUVs(0, uv);
                m.SetTriangles(t, 0);
                m.RecalculateBounds();
                return m;
            }
        }
    }

    /// Toon material factory + converter for imported glTF materials.
    public static class Mats
    {
        static Shader toon, water, particle;
        static readonly Dictionary<string, Material> Cache = new();

        public static Shader ToonShader => toon ??= Shader.Find("LuminaVale/Toon");
        public static Shader WaterShader => water ??= Shader.Find("LuminaVale/ToonWater");
        public static Shader ParticleShader => particle ??= Shader.Find("LuminaVale/SoftParticle");

        public static Material Toon(Color color, float outline = 1.6f, bool vertexColor = false, float wind = 0f, Color? emission = null, Color? shade = null)
        {
            string key = $"{color}_{outline}_{vertexColor}_{wind}_{emission}_{shade}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(ToonShader) { name = "Toon_" + ColorUtility.ToHtmlStringRGB(color), enableInstancing = true };
            m.SetColor("_BaseColor", color);
            m.SetFloat("_OutlineWidth", outline);
            m.SetFloat("_UseVertexColor", vertexColor ? 1 : 0);
            m.SetFloat("_WindStrength", wind);
            m.SetColor("_OutlineColor", Color.Lerp(new Color(0.16f, 0.1f, 0.14f), color * 0.35f, 0.35f));
            if (shade.HasValue) m.SetColor("_ShadeColor", shade.Value);
            if (emission.HasValue) m.SetColor("_EmissionColor", emission.Value);
            Cache[key] = m;
            return m;
        }

        public static Material Particle(bool additive, int shape)
        {
            string key = $"particle_{additive}_{shape}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(ParticleShader) { name = key };
            m.SetFloat("_Shape", shape);
            m.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
            m.SetFloat("_DstBlend", additive ? (float)UnityEngine.Rendering.BlendMode.One : (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            Cache[key] = m;
            return m;
        }

        public static Material Water()
        {
            if (Cache.TryGetValue("water", out var m) && m != null) return m;
            m = new Material(WaterShader) { name = "Water" };
            Cache["water"] = m;
            return m;
        }

        static readonly string[] ColorProps = { "baseColorFactor", "_BaseColor", "_Color" };
        static readonly string[] TexProps = { "baseColorTexture", "_BaseMap", "_MainTex" };

        /// Swap every material under root for a toon copy that keeps colour and texture.
        public static void ToonifyHierarchy(GameObject root, float outline = 1.8f)
        {
            foreach (var r in root.GetComponentsInChildren<Renderer>(true))
            {
                var src = r.sharedMaterials;
                var dst = new Material[src.Length];
                for (int i = 0; i < src.Length; i++)
                {
                    var s = src[i];
                    var m = new Material(ToonShader) { name = (s ? s.name : "mat") + "_Toon" };
                    Color col = Color.white;
                    Texture tex = null;
                    if (s)
                    {
                        foreach (var p in ColorProps) if (s.HasProperty(p)) { col = s.GetColor(p); break; }
                        foreach (var p in TexProps) if (s.HasProperty(p) && s.GetTexture(p)) { tex = s.GetTexture(p); break; }
                    }
                    m.SetColor("_BaseColor", col);
                    if (tex) m.SetTexture("_BaseMap", tex);
                    m.SetFloat("_OutlineWidth", outline);
                    m.SetColor("_OutlineColor", Color.Lerp(new Color(0.16f, 0.1f, 0.14f), col * 0.3f, 0.35f));
                    // Very dark parts (eyes, mouths) shouldn't get a fat outline.
                    if (col.maxColorComponent < 0.2f) m.SetFloat("_OutlineWidth", 0.4f);
                    // Bright emissive-ish materials (flames) glow a little through bloom.
                    if (col.r > 0.95f && col.g > 0.65f && col.b < 0.3f) m.SetColor("_EmissionColor", col * 0.6f);
                    // Blender house glass is named Window so night emission can find it.
                    if (s && s.name.IndexOf("Window", System.StringComparison.OrdinalIgnoreCase) >= 0)
                        m.name = "Window_Toon";
                    dst[i] = m;
                }
                r.sharedMaterials = dst;
            }
        }
    }
}
