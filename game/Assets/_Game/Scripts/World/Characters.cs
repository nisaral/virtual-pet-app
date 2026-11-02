using UnityEngine;

namespace LuminaVale
{
    /// Plays named clips on whatever the model shipped with: a legacy Animation
    /// (glTFast "Legacy" import) or an Animator with states named like the clips.
    public sealed class ClipPlayer
    {
        readonly Animation legacy;
        readonly Animator animator;
        string current;

        public ClipPlayer(GameObject root)
        {
            legacy = root.GetComponentInChildren<Animation>();
            animator = root.GetComponentInChildren<Animator>();
            if (legacy)
                foreach (AnimationState s in legacy)
                {
                    s.wrapMode = s.name.Contains("Hop") || s.name.Contains("Eat") || s.name.Contains("Refuse") ? WrapMode.Once : WrapMode.Loop;
                }
        }

        public bool Has(string clip)
        {
            if (legacy && legacy[clip] != null) return true;
            return animator && animator.runtimeAnimatorController && animator.HasState(0, Animator.StringToHash(clip));
        }

        public bool Play(string clip, float fade = 0.18f)
        {
            if (clip == current && IsPlaying) return true;
            if (legacy && legacy[clip] != null)
            {
                legacy.CrossFade(clip, fade);
                current = clip;
                return true;
            }
            if (animator && animator.runtimeAnimatorController && animator.HasState(0, Animator.StringToHash(clip)))
            {
                animator.CrossFadeInFixedTime(clip, fade);
                current = clip;
                return true;
            }
            return false;
        }

        public bool IsPlaying => legacy ? legacy.isPlaying : animator != null;
        public bool Any => (legacy && legacy.GetClipCount() > 0) || (animator && animator.runtimeAnimatorController);
    }

    /// A kin's body: model + toon materials + clip playback + procedural "juice"
    /// (squash and stretch, hop arcs, breathing) layered on a pivot so it works
    /// with or without authored animation.
    public sealed class CreatureVisual : MonoBehaviour
    {
        public SpeciesId Species;
        public int Stage;
        public Transform Pivot;     // procedural layer
        public Transform Model;     // the imported or generated body
        public float Height = 0.8f;

        ClipPlayer clips;
        float squash, hopT = -1, hopHeight, spinT = -1;
        float breathe;
        KinPose pose = KinPose.Idle;
        Vector3 baseScale = Vector3.one;

        static readonly float[] StageHeights = { 0.72f, 0.98f, 1.28f };

        public static CreatureVisual Create(Transform parent, SpeciesId species, int stage)
        {
            var go = new GameObject($"{species}_{stage}");
            go.transform.SetParent(parent, false);
            var v = go.AddComponent<CreatureVisual>();
            v.Build(species, stage);
            return v;
        }

        public void Build(SpeciesId species, int stage)
        {
            Species = species;
            Stage = stage;
            if (Pivot) Destroy(Pivot.gameObject);
            Pivot = new GameObject("Pivot").transform;
            Pivot.SetParent(transform, false);

            var def = Catalog.Of(species);
            GameObject prefab = null;
            bool legacyAsset = false;
            for (int s = Mathf.Clamp(stage, 0, 2); s >= 0 && !prefab; s--) prefab = Resources.Load<GameObject>(def.Models[s]);
            if (!prefab)
            {
                prefab = Resources.Load<GameObject>(def.Models[3]);
                legacyAsset = prefab != null;
            }

            Height = StageHeights[Mathf.Clamp(stage, 0, 2)];
            if (prefab)
            {
                Model = Instantiate(prefab, Pivot).transform;
                // Old builder faced Blender +Y; new kit faces Blender -Y (glTF forward).
                Model.localRotation = Quaternion.Euler(0, legacyAsset ? 180 : 0, 0);
                Mats.ToonifyHierarchy(Model.gameObject, 2.0f);
                FitHeight(Model, Height);
            }
            else
            {
                Model = BuildFallback(def, stage).transform;
                Model.SetParent(Pivot, false);
                // Procedural parts are laid out facing -Z; characters face +Z (Unity forward).
                Model.localRotation = Quaternion.Euler(0, 180, 0);
            }
            foreach (var r in Model.GetComponentsInChildren<Renderer>()) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            clips = new ClipPlayer(Model.gameObject);
            baseScale = Vector3.one;
            var shadow = GlenBuilder.AddBlobShadow(transform, 0.38f * Height / 0.8f);
            shadow.transform.SetSiblingIndex(0);
            SetPose(pose, true);
        }

        static void FitHeight(Transform model, float target)
        {
            var renderers = model.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) return;
            var b = renderers[0].bounds;
            foreach (var r in renderers) b.Encapsulate(r.bounds);
            if (b.size.y < 0.001f) return;
            float k = target / b.size.y;
            model.localScale *= k;
            // Feet on the ground.
            float bottom = (b.min.y - model.position.y) * k;
            model.localPosition -= Vector3.up * bottom;
        }

        /// Species-shaped clay kin: bloom hare, tide otter, ember fox-cub.
        GameObject BuildFallback(SpeciesDef def, int stage)
        {
            var root = new GameObject("FallbackBody");
            float s = StageHeights[Mathf.Clamp(stage, 0, 2)] / 0.8f;
            var main = def.Tint;
            var cream = Color.Lerp(main, new Color(0.98f, 0.94f, 0.86f), 0.72f);
            var ink = new Color(0.1f, 0.08f, 0.12f);
            var blush = new Color(1f, 0.58f, 0.6f);
            GameObject Part(string n, Mesh m, Color c, Vector3 pos, Vector3 scale, float outline = 1.9f)
            {
                var g = GlenBuilder.Make(n, root.transform, m, Mats.Toon(c, outline));
                g.transform.localPosition = pos * s;
                g.transform.localScale = scale * s;
                return g;
            }
            bool bloom = def.Element == KinElement.Bloom;
            bool tide = def.Element == KinElement.Tide;
            // Body: hare oval / otter loaf / fox wedge.
            if (bloom)
            {
                Part("Body", MeshKit.Blob(2, 0.12f, 1), main, new Vector3(0, 0.28f, 0.02f), new Vector3(0.46f, 0.42f, 0.52f));
                Part("Haunch", MeshKit.Blob(2), main * 0.92f, new Vector3(0, 0.2f, 0.16f), new Vector3(0.5f, 0.32f, 0.28f));
                Part("Belly", MeshKit.Blob(2), cream, new Vector3(0, 0.22f, -0.14f), new Vector3(0.34f, 0.28f, 0.28f));
                Part("Head", MeshKit.Blob(2, 0.08f, 2), main, new Vector3(0, 0.64f, -0.08f), new Vector3(0.5f, 0.46f, 0.48f));
                Part("Muzzle", MeshKit.Blob(2), cream, new Vector3(0, 0.56f, -0.28f), new Vector3(0.22f, 0.16f, 0.18f));
                Part("Nose", MeshKit.Blob(1), new Color(0.85f, 0.4f, 0.45f), new Vector3(0, 0.57f, -0.36f), new Vector3(0.07f, 0.05f, 0.05f), 0.4f);
                Part("Cotton", MeshKit.Blob(2, 0.2f, 4), cream, new Vector3(0, 0.22f, 0.32f), new Vector3(0.16f, 0.16f, 0.14f));
                Part("Sprout", MeshKit.Cylinder(6, 0.3f), new Color(0.38f, 0.7f, 0.32f), new Vector3(0, 0.86f, -0.02f), new Vector3(0.05f, 0.18f, 0.05f), 1.2f);
            }
            else if (tide)
            {
                Part("Body", MeshKit.Blob(2, 0.1f, 3), main, new Vector3(0, 0.24f, 0.04f), new Vector3(0.58f, 0.4f, 0.7f));
                Part("Belly", MeshKit.Blob(2), cream, new Vector3(0, 0.2f, -0.1f), new Vector3(0.44f, 0.3f, 0.42f));
                Part("Head", MeshKit.Blob(2), main, new Vector3(0, 0.48f, -0.22f), new Vector3(0.48f, 0.4f, 0.42f));
                Part("Muzzle", MeshKit.Blob(2), cream, new Vector3(0, 0.42f, -0.4f), new Vector3(0.28f, 0.18f, 0.2f));
                Part("Nose", MeshKit.Blob(1), new Color(0.25f, 0.22f, 0.3f), new Vector3(0, 0.44f, -0.5f), new Vector3(0.08f, 0.06f, 0.06f), 0.3f);
                var tail = Part("Tail", MeshKit.Blob(2, 0.15f, 5), cream, new Vector3(0, 0.16f, 0.42f), new Vector3(0.22f, 0.12f, 0.5f));
                tail.transform.localRotation = Quaternion.Euler(18, 0, 0);
            }
            else
            {
                Part("Body", MeshKit.Blob(2, 0.1f, 7), main, new Vector3(0, 0.28f, 0.04f), new Vector3(0.42f, 0.4f, 0.56f));
                Part("Chest", MeshKit.Blob(2), cream, new Vector3(0, 0.26f, -0.12f), new Vector3(0.3f, 0.28f, 0.28f));
                Part("Head", MeshKit.Blob(2, 0.06f, 8), main, new Vector3(0, 0.62f, -0.16f), new Vector3(0.44f, 0.42f, 0.46f));
                Part("Snout", MeshKit.Blob(2), cream, new Vector3(0, 0.54f, -0.36f), new Vector3(0.2f, 0.14f, 0.22f));
                Part("Nose", MeshKit.Blob(1), ink, new Vector3(0, 0.55f, -0.46f), new Vector3(0.06f, 0.05f, 0.05f), 0.2f);
                var tail = Part("Brush", MeshKit.Blob(2, 0.22f, 9), Color.Lerp(main, new Color(1f, 0.85f, 0.4f), 0.25f), new Vector3(0, 0.28f, 0.38f), new Vector3(0.22f, 0.22f, 0.48f));
                tail.transform.localRotation = Quaternion.Euler(-25, 0, 0);
                var flame = Part("Flame", MeshKit.Blob(1, 0.3f, 2), new Color(1f, 0.7f, 0.2f), new Vector3(0, 0.92f, -0.04f), new Vector3(0.12f, 0.22f, 0.12f), 1f);
                flame.GetComponent<Renderer>().sharedMaterial = Mats.Toon(new Color(1f, 0.7f, 0.2f), 1f, emission: new Color(0.9f, 0.35f, 0.05f));
            }
            foreach (int side in new[] { -1, 1 })
            {
                Part("Eye", MeshKit.Blob(1), ink, new Vector3(side * 0.11f, bloom ? 0.68f : tide ? 0.52f : 0.66f, bloom ? -0.26f : tide ? -0.36f : -0.32f), new Vector3(0.09f, 0.12f, 0.05f), 0.25f);
                Part("Shine", MeshKit.Blob(1), Color.white, new Vector3(side * 0.1f + 0.02f, (bloom ? 0.71f : tide ? 0.55f : 0.69f), bloom ? -0.29f : tide ? -0.39f : -0.35f), new Vector3(0.035f, 0.035f, 0.02f), 0f);
                Part("Cheek", MeshKit.Blob(1), blush, new Vector3(side * 0.18f, bloom ? 0.58f : 0.48f, bloom ? -0.22f : -0.3f), new Vector3(0.07f, 0.045f, 0.03f), 0f);
                Part("Arm", MeshKit.Blob(1), main, new Vector3(side * (tide ? 0.28f : 0.22f), tide ? 0.22f : 0.28f, -0.08f), new Vector3(0.1f, 0.16f, 0.12f));
                Part("Foot", MeshKit.Blob(1), main * 0.88f, new Vector3(side * 0.14f, 0.06f, -0.08f), new Vector3(tide ? 0.18f : 0.14f, 0.09f, 0.22f));
                if (bloom)
                {
                    var ear = Part("Ear", MeshKit.Blob(2), main, new Vector3(side * 0.16f, 0.92f, 0.02f), new Vector3(0.12f, 0.34f, 0.08f));
                    ear.transform.localRotation = Quaternion.Euler(-12, 0, -side * 18);
                    Part("Inner", MeshKit.Blob(1), cream, new Vector3(side * 0.16f, 0.9f, -0.01f), new Vector3(0.06f, 0.22f, 0.04f), 0.3f);
                    var leaf = Part("Leaf", MeshKit.Blob(1), new Color(0.4f, 0.75f, 0.35f), new Vector3(side * 0.2f, 0.88f, 0.08f), new Vector3(0.1f, 0.24f, 0.04f));
                    leaf.transform.localRotation = Quaternion.Euler(0, 0, -side * 28);
                }
                else if (tide)
                {
                    Part("Ear", MeshKit.Blob(1), main, new Vector3(side * 0.16f, 0.62f, -0.16f), new Vector3(0.08f, 0.1f, 0.06f));
                    var whisk = Part("Whisker", MeshKit.Box(), cream, new Vector3(side * 0.22f, 0.44f, -0.42f), new Vector3(0.18f, 0.015f, 0.015f), 0.2f);
                    whisk.transform.localRotation = Quaternion.Euler(0, 0, side * 12);
                    var fin = Part("Fin", MeshKit.Blob(1), new Color(0.75f, 0.92f, 1f), new Vector3(side * 0.32f, 0.32f, 0.04f), new Vector3(0.16f, 0.08f, 0.12f));
                    fin.transform.localRotation = Quaternion.Euler(0, 0, side * 25);
                }
                else
                {
                    var ear = Part("Ear", MeshKit.Blob(2), main, new Vector3(side * 0.16f, 0.86f, -0.08f), new Vector3(0.12f, 0.22f, 0.1f));
                    ear.transform.localRotation = Quaternion.Euler(-8, 0, -side * 22);
                    Part("Inner", MeshKit.Blob(1), new Color(1f, 0.55f, 0.4f), new Vector3(side * 0.16f, 0.84f, -0.1f), new Vector3(0.06f, 0.12f, 0.04f), 0.3f);
                }
            }
            if (stage >= 2)
                Part("Crest", MeshKit.Blob(1), Catalog.ElementColor(def.Element), new Vector3(0, bloom ? 0.96f : 0.9f, 0.06f), new Vector3(0.22f, 0.1f, 0.26f));
            return root;
        }

        public void SetPose(KinPose p, bool force = false)
        {
            if (p == pose && !force) return;
            pose = p;
            string clip = p switch
            {
                KinPose.Walk => "Walk",
                KinPose.Hop or KinPose.Cheer => "Happy_Hop",
                KinPose.Eat => "Eat",
                KinPose.Groom => "Pet_Enjoy",
                KinPose.Sleep => "Sleep",
                KinPose.Sulk => "Refuse",
                _ => "Idle",
            };
            if (clips == null || !clips.Play(clip)) clips?.Play("Idle");
            if (p is KinPose.Hop or KinPose.Cheer) Hop(0.35f);
        }

        public void Hop(float height = 0.35f)
        {
            hopT = 0;
            hopHeight = height;
            squash = -0.25f;
        }

        public void Spin() => spinT = 0;
        public void Squash(float amount) => squash = amount;

        void Update()
        {
            if (!Pivot) return;
            float dt = Time.deltaTime;
            breathe += dt * (pose == KinPose.Sleep ? 1.4f : 2.6f);
            squash = Mathf.Lerp(squash, 0, dt * 9f);
            float y = 0;
            if (hopT >= 0)
            {
                hopT += dt / 0.42f;
                y = Mathf.Sin(Mathf.Clamp01(hopT) * Mathf.PI) * hopHeight;
                if (hopT >= 1) { hopT = -1; squash = -0.2f; }
                else if (hopT > 0.1f) squash = Mathf.Lerp(squash, 0.12f, dt * 10);
            }
            float walkBob = pose == KinPose.Walk && !(clips?.Any ?? false) ? Mathf.Abs(Mathf.Sin(breathe * 3.2f)) * 0.06f : 0;
            float br = Mathf.Sin(breathe) * (pose == KinPose.Sleep ? 0.04f : 0.022f);
            float sy = 1 + squash + br;
            float sxz = 1 - squash * 0.5f - br * 0.4f;
            Pivot.localScale = new Vector3(baseScale.x * sxz, baseScale.y * sy, baseScale.z * sxz);
            Pivot.localPosition = Vector3.up * (y + walkBob);
            if (spinT >= 0)
            {
                spinT += dt / 0.6f;
                Pivot.localRotation = Quaternion.Euler(0, Mathf.SmoothStep(0, 360, Mathf.Clamp01(spinT)), 0);
                if (spinT >= 1) { spinT = -1; Pivot.localRotation = Quaternion.identity; }
            }
            if (pose == KinPose.Sulk && !(clips?.Any ?? false))
                Pivot.localRotation = Quaternion.Euler(0, Mathf.Sin(Time.time * 7) * 8, 0);
        }
    }

    /// Procedural chibi human (big head, small body), for the Keeper and the villagers.
    /// Replaced by Resources/Kit/<kitName> when an artist model exists.
    public sealed class ChibiCharacter : MonoBehaviour
    {
        public float Speed01;
        Transform body, head, legL, legR, armL, armR;
        ClipPlayer clips;
        float phase;
        float wave = -1;

        public static ChibiCharacter Create(Transform parent, string kitName, Color shirt, Color hair, Color skin, bool hat = false, Color? hatColor = null)
        {
            var go = new GameObject(kitName);
            go.transform.SetParent(parent, false);
            var c = go.AddComponent<ChibiCharacter>();
            var kit = Resources.Load<GameObject>("Kit/" + kitName);
            if (kit)
            {
                var m = Instantiate(kit, go.transform);
                Mats.ToonifyHierarchy(m, 1.8f);
                c.clips = new ClipPlayer(m);
            }
            else c.BuildProcedural(shirt, hair, skin, hat, hatColor ?? new Color(0.9f, 0.3f, 0.3f));
            GlenBuilder.AddBlobShadow(go.transform, 0.32f);
            return c;
        }

        void BuildProcedural(Color shirt, Color hair, Color skin, bool hat, Color hatColor)
        {
            var pants = new Color(0.3f, 0.34f, 0.5f);
            var ink = new Color(0.12f, 0.1f, 0.14f);
            Transform Node(string n, Transform parent, Vector3 pos)
            {
                var t = new GameObject(n).transform;
                t.SetParent(parent, false);
                t.localPosition = pos;
                return t;
            }
            GameObject Part(string n, Transform parent, Mesh m, Color c, Vector3 pos, Vector3 scale, float outline = 1.8f)
            {
                var g = GlenBuilder.Make(n, parent, m, Mats.Toon(c, outline));
                g.transform.localPosition = pos;
                g.transform.localScale = scale;
                return g;
            }
            body = Node("Body", transform, Vector3.zero);
            body.localRotation = Quaternion.Euler(0, 180, 0); // parts face -Z; character forward is +Z
            legL = Node("LegL", body, new Vector3(-0.09f, 0.3f, 0));
            legR = Node("LegR", body, new Vector3(0.09f, 0.3f, 0));
            Part("Leg", legL, MeshKit.Cylinder(8, 0.9f), pants, new Vector3(0, -0.3f, 0), new Vector3(0.13f, 0.28f, 0.13f));
            Part("Leg", legR, MeshKit.Cylinder(8, 0.9f), pants, new Vector3(0, -0.3f, 0), new Vector3(0.13f, 0.28f, 0.13f));
            Part("Shoe", legL, MeshKit.Blob(1), ink * 2.2f, new Vector3(0, -0.28f, -0.04f), new Vector3(0.14f, 0.08f, 0.2f));
            Part("Shoe", legR, MeshKit.Blob(1), ink * 2.2f, new Vector3(0, -0.28f, -0.04f), new Vector3(0.14f, 0.08f, 0.2f));
            Part("Torso", body, MeshKit.Cylinder(10, 0.75f), shirt, new Vector3(0, 0.28f, 0), new Vector3(0.38f, 0.38f, 0.3f));
            Part("Collar", body, MeshKit.Cylinder(12, 1.1f), Color.Lerp(shirt, Color.white, 0.35f), new Vector3(0, 0.48f, -0.02f), new Vector3(0.32f, 0.06f, 0.28f), 0.8f);
            armL = Node("ArmL", body, new Vector3(-0.21f, 0.56f, 0));
            armR = Node("ArmR", body, new Vector3(0.21f, 0.56f, 0));
            Part("Arm", armL, MeshKit.Cylinder(6, 0.8f), shirt, new Vector3(0, -0.26f, 0), new Vector3(0.09f, 0.26f, 0.09f));
            Part("Arm", armR, MeshKit.Cylinder(6, 0.8f), shirt, new Vector3(0, -0.26f, 0), new Vector3(0.09f, 0.26f, 0.09f));
            Part("Hand", armL, MeshKit.Blob(1), skin, new Vector3(0, -0.28f, 0), Vector3.one * 0.08f);
            Part("Hand", armR, MeshKit.Blob(1), skin, new Vector3(0, -0.28f, 0), Vector3.one * 0.08f);
            head = Node("Head", body, new Vector3(0, 0.92f, 0));
            Part("Face", head, MeshKit.Blob(2, 0.06f, 3), skin, Vector3.zero, new Vector3(0.56f, 0.52f, 0.5f));
            Part("Hair", head, MeshKit.Blob(2, 0.2f, 5), hair, new Vector3(0, 0.1f, 0.06f), new Vector3(0.6f, 0.5f, 0.56f));
            Part("Bangs", head, MeshKit.Blob(1, 0.28f, 6), hair, new Vector3(0, 0.16f, -0.2f), new Vector3(0.48f, 0.18f, 0.18f));
            Part("Nose", head, MeshKit.Blob(1), skin * 0.92f, new Vector3(0, -0.04f, -0.24f), new Vector3(0.08f, 0.07f, 0.06f), 0.6f);
            foreach (int side in new[] { -1, 1 })
            {
                Part("Ear", head, MeshKit.Blob(1), skin, new Vector3(side * 0.24f, 0.06f, 0.04f), new Vector3(0.08f, 0.12f, 0.06f), 1.2f);
                Part("Eye", head, MeshKit.Blob(1), ink, new Vector3(side * 0.1f, 0.0f, -0.23f), new Vector3(0.07f, 0.1f, 0.04f), 0f);
                Part("Shine", head, MeshKit.Blob(1), Color.white, new Vector3(side * 0.1f + 0.018f, 0.03f, -0.255f), new Vector3(0.028f, 0.028f, 0.012f), 0f);
                Part("Blush", head, MeshKit.Blob(1), new Color(1f, 0.62f, 0.6f), new Vector3(side * 0.17f, -0.09f, -0.2f), new Vector3(0.055f, 0.032f, 0.02f), 0f);
            }
            if (hat)
            {
                Part("Hat", head, MeshKit.Blob(2), hatColor, new Vector3(0, 0.17f, 0.02f), new Vector3(0.54f, 0.3f, 0.52f));
                Part("Brim", head, MeshKit.Cylinder(14), hatColor * 0.9f, new Vector3(0, 0.12f, -0.12f), new Vector3(0.5f, 0.03f, 0.4f));
                Part("Band", head, MeshKit.Cylinder(14), Color.white, new Vector3(0, 0.16f, 0.02f), new Vector3(0.5f, 0.05f, 0.5f));
            }
            foreach (var r in GetComponentsInChildren<Renderer>()) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
        }

        public void Wave() => wave = 0;

        void Update()
        {
            if (clips != null)
            {
                clips.Play(Speed01 > 0.05f ? (Speed01 > 0.7f ? "Run" : "Walk") : "Idle");
                return;
            }
            if (!body) return;
            float dt = Time.deltaTime;
            phase += dt * Mathf.Lerp(2f, 13f, Speed01);
            float swing = Mathf.Sin(phase) * 38f * Speed01;
            legL.localRotation = Quaternion.Euler(swing, 0, 0);
            legR.localRotation = Quaternion.Euler(-swing, 0, 0);
            armL.localRotation = Quaternion.Euler(-swing * 0.8f, 0, -6);
            armR.localRotation = Quaternion.Euler(swing * 0.8f, 0, 6);
            if (wave >= 0)
            {
                wave += dt / 1.2f;
                armR.localRotation = Quaternion.Euler(0, 0, 140 + Mathf.Sin(wave * 20) * 18);
                if (wave >= 1) wave = -1;
            }
            float bob = Speed01 > 0.05f ? Mathf.Abs(Mathf.Sin(phase)) * 0.05f : Mathf.Sin(phase * 0.6f) * 0.008f;
            body.localPosition = Vector3.up * bob;
            head.localRotation = Quaternion.Euler(Speed01 * 6f, 0, Mathf.Sin(phase * 0.5f) * 2f * (1 - Speed01));
        }
    }
}
