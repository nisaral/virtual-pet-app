using UnityEngine;

namespace LuminaVale
{
    /// Whales in the bay and a cheap distance cull so the big vale stays smooth on phones.
    public static class ValeLife
    {
        public static void Spawn(Transform parent)
        {
            int n = 0;
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
            {
                if (GlenMap.At(x, y) != Tile.DeepWater) continue;
                if (((x * 13 + y * 7) % 17) != 0 || n >= 4) continue;
                var p = GlenMap.ToWorld(new Vector2Int(x, y));
                Whale.Create(parent, new Vector3(p.x, -0.15f, p.z), n);
                n++;
            }
        }
    }

    public sealed class Whale : MonoBehaviour
    {
        Vector3 home;
        float t, radius, speed;

        public static Whale Create(Transform parent, Vector3 pos, int seed)
        {
            var go = new GameObject("Whale");
            go.transform.SetParent(parent);
            go.transform.position = pos;
            var w = go.AddComponent<Whale>();
            w.home = pos;
            w.radius = 3.5f + seed;
            w.speed = 0.18f + seed * 0.04f;
            w.t = seed * 1.7f;
            var body = GlenBuilder.Make("Body", go.transform, MeshKit.Blob(2, 0.2f, seed), Mats.Toon(new Color(0.45f, 0.58f, 0.7f), 1.6f));
            body.transform.localScale = new Vector3(1.8f, 0.55f, 0.7f);
            var tail = GlenBuilder.Make("Tail", go.transform, MeshKit.Blob(1), Mats.Toon(new Color(0.4f, 0.52f, 0.64f), 1.2f));
            tail.transform.localPosition = new Vector3(-1.1f, 0.05f, 0);
            tail.transform.localScale = new Vector3(0.55f, 0.12f, 0.9f);
            var spout = GlenBuilder.Make("Spout", go.transform, MeshKit.Cylinder(6, 0.2f), Mats.Toon(new Color(0.85f, 0.95f, 1f), 0.4f));
            spout.transform.localPosition = new Vector3(0.4f, 0.4f, 0);
            spout.transform.localScale = new Vector3(0.08f, 0.5f, 0.08f);
            return w;
        }

        void Update()
        {
            t += Time.deltaTime * speed;
            float x = Mathf.Cos(t) * radius;
            float z = Mathf.Sin(t * 0.7f) * radius * 0.6f;
            var p = home + new Vector3(x, Mathf.Sin(t * 2f) * 0.08f, z);
            var dir = p - transform.position;
            transform.position = p;
            if (dir.sqrMagnitude > 0.0001f) transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(dir.normalized, Vector3.up), Time.deltaTime * 2f);
        }
    }

    public sealed class WorldLod : MonoBehaviour
    {
        Transform cam;
        Renderer[] rs;
        float next;

        void Start()
        {
            cam = Camera.main ? Camera.main.transform : null;
            rs = GetComponentsInChildren<Renderer>(true);
        }

        void LateUpdate()
        {
            if (!cam) return;
            if (Time.unscaledTime < next) return;
            next = Time.unscaledTime + 0.28f;
            var c = cam.position;
            for (int i = 0; i < rs.Length; i++)
            {
                var r = rs[i];
                if (!r) continue;
                float d = (r.bounds.center - c).sqrMagnitude;
                bool on = d < 38f * 38f;
                if (r.enabled != on) r.enabled = on;
            }
        }
    }
}
