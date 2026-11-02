using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace LuminaVale
{
    public static class PointerInput
    {
        public static bool Held
        {
            get
            {
#if ENABLE_INPUT_SYSTEM
                return Pointer.current != null && Pointer.current.press.isPressed;
#else
                return Input.GetMouseButton(0);
#endif
            }
        }

        public static bool Down
        {
            get
            {
#if ENABLE_INPUT_SYSTEM
                return Pointer.current != null && Pointer.current.press.wasPressedThisFrame;
#else
                return Input.GetMouseButtonDown(0);
#endif
            }
        }

        public static Vector2 Position
        {
            get
            {
#if ENABLE_INPUT_SYSTEM
                return Pointer.current != null ? Pointer.current.position.ReadValue() : Vector2.zero;
#else
                return Input.mousePosition;
#endif
            }
        }

        public static bool OverUI => EventSystem.current && EventSystem.current.IsPointerOverGameObject();
    }

    /// Brushing: close-up camera, drag across the kin. Steady, medium-speed strokes score best.
    public sealed class BrushGame : MonoBehaviour
    {
        public GameUI UI;
        public GridCamera Cam;
        public KinAgent Kin;
        public Action<float> Done;

        SphereCollider hitbox;
        Vector2 last;
        bool stroking;
        float strokeLen, strokeTime, timeLeft;
        readonly List<float> strokes = new();
        float brushSfx;

        public void Begin()
        {
            enabled = true;
            strokes.Clear();
            timeLeft = 14f;
            Kin.Hold();
            Kin.Face(Cam.transform.position);
            hitbox = Kin.gameObject.AddComponent<SphereCollider>();
            hitbox.center = Vector3.up * Kin.Visual.Height * 0.5f;
            hitbox.radius = Kin.Visual.Height * 0.6f;
            var focus = Kin.transform.position + Vector3.up * Kin.Visual.Height * 0.55f;
            Cam.Push(focus, 30, 4.2f, 30);
            GameInput.Locked = true;
            UI.ShowHud(false);
            UI.Meter("Brush with long, steady strokes", 0);
        }

        void Update()
        {
            if (hitbox == null) { enabled = false; return; }
            timeLeft -= Time.deltaTime;
            var pos = PointerInput.Position;
            RaycastHit hit = default;
            bool onKin = PointerInput.Held && Physics.Raycast(Cam.Cam.ScreenPointToRay(pos), out hit, 50f) && hit.collider == hitbox;
            if (onKin)
            {
                if (!stroking) { stroking = true; strokeLen = 0; strokeTime = 0; last = pos; }
                float d = (pos - last).magnitude / Screen.height;
                strokeLen += d;
                strokeTime += Time.deltaTime;
                last = pos;
                brushSfx -= Time.deltaTime;
                if (d > 0.004f && brushSfx <= 0)
                {
                    brushSfx = 0.12f;
                    ProcAudio.I?.Play("brush", 0.6f, UnityEngine.Random.Range(0.9f, 1.15f));
                    Fx.Burst(hit.point, new Color(1f, 1f, 1f, 0.8f), 3, 0.8f, 0.1f, true, 1, 0.4f, 0);
                    Kin.Visual.SetPose(KinPose.Groom);
                }
            }
            else if (stroking)
            {
                stroking = false;
                if (strokeLen > 0.08f)
                {
                    float speed = strokeLen / Mathf.Max(0.05f, strokeTime); // screen-heights per second
                    float q = Mathf.Clamp01(1f - Mathf.Abs(speed - 1.1f) / 1.4f) * Mathf.Clamp01(strokeLen / 0.3f);
                    strokes.Add(q);
                    Kin.Visual.Squash(0.12f);
                    if (q > 0.6f) { Fx.Hearts(Kin.transform.position); ProcAudio.I?.Chirp(GameManager.I.Kin.Species, 1.2f); }
                }
            }
            float progress = Mathf.Clamp01(strokes.Count / 8f);
            UI.Meter(strokes.Count == 0 ? "Brush with long, steady strokes" : $"Brushing… {strokes.Count}/8", progress);
            if (strokes.Count >= 8 || timeLeft <= 0) Finish();
        }

        void Finish()
        {
            enabled = false;
            Destroy(hitbox);
            hitbox = null;
            float q = 0;
            foreach (var s in strokes) q += s;
            q = strokes.Count == 0 ? 0.1f : q / Mathf.Max(5, strokes.Count);
            UI.Meter(null, 0);
            UI.ShowHud(true);
            Cam.Release();
            GameInput.Locked = false;
            Kin.Visual.SetPose(KinPose.Cheer);
            Fx.Sparkle(Kin.transform.position, new Color(1f, 0.95f, 0.7f));
            ProcAudio.I?.Play("sparkle");
            Kin.Release();
            Done?.Invoke(q);
        }
    }

    /// Glyph duet at the rune stones: watch the runes light up, repeat them. Port of the
    /// pattern game, now played on four real stones.
    public sealed class GlyphDuet : MonoBehaviour
    {
        public GameUI UI;
        public GridCamera Cam;
        public GlenWorld World;
        public KinAgent Kin;
        public Action<float> Done;

        readonly List<int> seq = new();
        readonly string[] ids = { "rune0", "rune1", "rune2", "rune3" };
        readonly float[] pitches = { 1f, 1.26f, 1.5f, 1.68f };
        int round, input;
        bool listening;
        readonly System.Random rng = new();
        readonly List<Collider> colliders = new();

        public void Begin()
        {
            enabled = true;
            round = 0;
            seq.Clear();
            colliders.Clear();
            foreach (var id in ids)
            {
                var r = World.Runes[id];
                if (!r.gameObject.TryGetComponent<BoxCollider>(out var c)) c = r.gameObject.AddComponent<BoxCollider>();
                c.size = new Vector3(3.5f, 4f, 8f); // generous tap target around the small glyph
                colliders.Add(c);
            }
            var center = Vector3.zero;
            foreach (var id in ids) center += World.Runes[id].transform.position;
            center /= ids.Length;
            Cam.Push(center + Vector3.back * 0.3f, 48, 8.5f, 30);
            GameInput.Locked = true;
            UI.ShowHud(false);
            int baseLen = 3 + Mathf.FloorToInt(GameManager.I.Kin.PatternSkill / 12f);
            for (int i = 0; i < baseLen; i++) seq.Add(rng.Next(4));
            StartCoroutine(PlaySequence());
        }

        IEnumerator PlaySequence()
        {
            listening = false;
            UI.Meter($"Watch the runes… (round {round + 1}/3)", round / 3f);
            yield return new WaitForSeconds(0.8f);
            foreach (int i in seq)
            {
                yield return Light(i, 0.45f);
                yield return new WaitForSeconds(0.15f);
            }
            input = 0;
            listening = true;
            UI.Meter($"Your turn! Tap the runes (round {round + 1}/3)", round / 3f);
        }

        IEnumerator Light(int i, float seconds)
        {
            var r = World.Runes[ids[i]];
            var mat = r.material;
            mat.SetColor("_EmissionColor", new Color(0.5f, 1.2f, 1.6f));
            ProcAudio.I?.Play("rune", 0.8f, pitches[i]);
            Fx.Sparkle(r.transform.position - Vector3.up * 0.3f, new Color(0.6f, 0.95f, 1f));
            yield return new WaitForSeconds(seconds);
            mat.SetColor("_EmissionColor", Color.black);
        }

        void Update()
        {
            if (!listening || !PointerInput.Down || PointerInput.OverUI) return;
            if (!Physics.Raycast(Cam.Cam.ScreenPointToRay(PointerInput.Position), out var hit, 80f)) return;
            int tapped = colliders.IndexOf(hit.collider);
            if (tapped < 0) return;
            StartCoroutine(Light(tapped, 0.25f));
            if (tapped != seq[input])
            {
                ProcAudio.I?.Play("rune_bad");
                Cam.Shake(0.4f);
                Finish(round / 3f);
                return;
            }
            input++;
            if (input < seq.Count) return;
            round++;
            Kin.Visual.Hop(0.4f);
            ProcAudio.I?.Chirp(GameManager.I.Kin.Species, 1.2f);
            if (round >= 3) { Finish(1f); return; }
            seq.Add(rng.Next(4));
            StartCoroutine(PlaySequence());
        }

        void Finish(float score)
        {
            listening = false;
            enabled = false;
            UI.Meter(null, 0);
            UI.ShowHud(true);
            Cam.Release();
            GameInput.Locked = false;
            if (score >= 1f) { ProcAudio.I?.Play("fanfare"); Fx.Sparkle(Kin.transform.position, new Color(0.6f, 0.95f, 1f)); }
            Done?.Invoke(score);
        }
    }

    /// Gleam hunt in the meadow: catch drifting motes before time runs out. The kin
    /// joins in and chases the nearest one.
    public sealed class GleamHunt : MonoBehaviour
    {
        public GameUI UI;
        public KeeperController Keeper;
        public KinAgent Kin;
        public Action<float, int> Done;

        readonly List<Transform> motes = new();
        float timeLeft;
        int caught;
        const int Total = 10;
        float kinRepath;

        public void Begin()
        {
            enabled = true;
            caught = 0;
            timeLeft = 35f;
            var cells = new List<Vector2Int>();
            for (int y = 0; y < GlenMap.Height; y++)
            for (int x = 0; x < GlenMap.Width; x++)
                if (GlenMap.At(x, y) == Tile.TallGrass && (new Vector2Int(x, y) - Keeper.Cell).sqrMagnitude < 18 * 18) cells.Add(new Vector2Int(x, y));
            var rng = new System.Random();
            for (int i = 0; i < Total && cells.Count > 0; i++)
            {
                var c = cells[rng.Next(cells.Count)];
                var mote = GlenBuilder.Make("Mote", transform, MeshKit.Blob(1), Mats.Toon(new Color(1f, 0.95f, 0.6f), 0.8f, emission: new Color(1.2f, 1f, 0.4f)));
                mote.transform.position = GlenMap.ToWorld(c) + Vector3.up * 0.6f;
                mote.transform.localScale = Vector3.one * 0.22f;
                motes.Add(mote.transform);
            }
            Kin.Hold();
            UI.Toast("Catch the drifting gleam motes in the tall grass!");
        }

        void Update()
        {
            timeLeft -= Time.deltaTime;
            for (int i = motes.Count - 1; i >= 0; i--)
            {
                var m = motes[i];
                m.position += new Vector3(Mathf.Sin(Time.time * 1.3f + i) * 0.4f, Mathf.Sin(Time.time * 3f + i) * 0.3f, Mathf.Cos(Time.time * 1.1f + i * 2) * 0.4f) * Time.deltaTime;
                float dk = Vector3.Distance(Flat(m.position), Flat(Keeper.transform.position));
                float dp = Vector3.Distance(Flat(m.position), Flat(Kin.transform.position));
                if (dk < 0.75f || dp < 0.6f)
                {
                    caught++;
                    ProcAudio.I?.Play("pickup", 0.8f, 1 + caught * 0.05f);
                    Fx.Sparkle(m.position - Vector3.up * 0.4f, new Color(1f, 0.92f, 0.5f));
                    if (dp < 0.6f) Kin.Visual.Hop(0.4f);
                    Destroy(m.gameObject);
                    motes.RemoveAt(i);
                }
            }
            kinRepath -= Time.deltaTime;
            if (kinRepath <= 0 && motes.Count > 0)
            {
                kinRepath = 1.2f;
                Transform best = null;
                float bd = float.MaxValue;
                foreach (var m in motes)
                {
                    float d = Vector3.Distance(m.position, Kin.transform.position);
                    if (d < bd) { bd = d; best = m; }
                }
                if (best) Kin.WalkTo(GlenMap.ToCell(best.position));
            }
            UI.Meter($"Gleam motes {caught}/{Total}   {Mathf.CeilToInt(timeLeft)}s", caught / (float)Total);
            if (motes.Count == 0 || timeLeft <= 0) Finish();
        }

        static Vector3 Flat(Vector3 v) => new(v.x, 0, v.z);

        void Finish()
        {
            enabled = false;
            foreach (var m in motes) if (m) Destroy(m.gameObject);
            motes.Clear();
            UI.Meter(null, 0);
            Kin.Release();
            Done?.Invoke(caught / (float)Total, caught);
        }
    }

    /// The rite: the kin glows, light swallows it, the new form is revealed.
    public static class Evolution
    {
        public static IEnumerator Play(GameUI ui, GridCamera cam, KinAgent kin, Action finished)
        {
            var gm = GameManager.I;
            string before = gm.Kin.Def.TitleFor(gm.Kin.Stage);
            GameInput.Locked = true;
            kin.Hold();
            ui.ShowHud(false);
            var focus = kin.transform.position + Vector3.up * 0.6f;
            cam.Push(focus, 20, 5f, 32);
            ProcAudio.I?.Music("night");
            yield return new WaitForSeconds(0.8f);
            bool waiting = true;
            ui.Say("", $"{gm.Kin.Name} is glowing…", () => waiting = false);
            while (waiting) yield return null;

            ProcAudio.I?.Play("evolve");
            var glow = GlenBuilder.Make("EvolveGlow", kin.transform, MeshKit.Blob(2), Mats.Toon(Color.white, 0f, emission: new Color(2.2f, 2.1f, 1.8f)));
            glow.transform.localPosition = Vector3.up * kin.Visual.Height * 0.5f;
            for (float t = 0; t < 2.4f; t += Time.deltaTime)
            {
                float pulse = 0.3f + t / 2.4f * kin.Visual.Height * 1.1f + Mathf.Sin(t * 18) * 0.05f;
                glow.transform.localScale = Vector3.one * pulse;
                kin.Visual.transform.localScale = Vector3.one * (1 + Mathf.Sin(t * 12) * 0.06f * t);
                if (UnityEngine.Random.value < 0.25f) Fx.Sparkle(kin.transform.position, new Color(1f, 0.95f, 0.75f));
                cam.Shake(0.15f);
                yield return null;
            }
            ui.FlashWhite(1);
            gm.Evolve();
            kin.Rebuild();
            kin.Visual.transform.localScale = Vector3.one;
            UnityEngine.Object.Destroy(glow);
            yield return ui.Fade(0, 1.2f);
            kin.Visual.SetPose(KinPose.Cheer);
            Fx.Burst(kin.transform.position + Vector3.up * 0.6f, new Color(1f, 0.9f, 0.6f), 40, 4f, 0.22f, true, 1, 1.2f, 0);
            ProcAudio.I?.Play("fanfare");
            ProcAudio.I?.Chirp(gm.Kin.Species, 0.85f);
            waiting = true;
            ui.Say("", $"{before} became {gm.Kin.Def.TitleFor(gm.Kin.Stage)}!", () => waiting = false);
            while (waiting) yield return null;
            cam.Release();
            ui.ShowHud(true);
            kin.Release();
            GameInput.Locked = false;
            finished?.Invoke();
        }
    }
}
