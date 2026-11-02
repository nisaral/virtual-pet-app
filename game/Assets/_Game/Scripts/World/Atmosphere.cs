using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuminaVale
{
    /// Real-clock day phases (dawn / day / dusk / night), each a hand-tuned lighting
    /// preset, blended smoothly. Also drives lamps, windows, post grading and weather.
    public sealed class DayNightDirector : MonoBehaviour
    {
        struct Preset
        {
            public Color Sun, Sky, Equator, Ground, Fog, Background, Grade, Shade;
            public float SunIntensity, SunPitch, SunYaw, Night, Bloom, Saturation, Exposure;
        }

        static readonly Preset Dawn = new()
        {
            Sun = new Color(1f, 0.78f, 0.66f), SunIntensity = 1.05f, SunPitch = 26, SunYaw = -60,
            Sky = new Color(0.98f, 0.74f, 0.74f), Equator = new Color(0.86f, 0.72f, 0.8f), Ground = new Color(0.52f, 0.5f, 0.56f),
            Fog = new Color(0.98f, 0.82f, 0.8f), Background = new Color(1f, 0.8f, 0.72f), Grade = new Color(1f, 0.93f, 0.92f),
            Night = 0.15f, Bloom = 0.7f, Saturation = 6, Exposure = 0.05f,
        };
        static readonly Preset Day = new()
        {
            Sun = new Color(1f, 0.97f, 0.9f), SunIntensity = 1.25f, SunPitch = 52, SunYaw = -35,
            Sky = new Color(0.78f, 0.88f, 1f), Equator = new Color(0.8f, 0.86f, 0.84f), Ground = new Color(0.55f, 0.58f, 0.5f),
            Fog = new Color(0.82f, 0.92f, 1f), Background = new Color(0.62f, 0.84f, 1f), Grade = Color.white,
            Night = 0, Bloom = 0.45f, Saturation = 10, Exposure = 0.1f,
        };
        static readonly Preset Dusk = new()
        {
            Sun = new Color(1f, 0.62f, 0.38f), SunIntensity = 1.0f, SunPitch = 18, SunYaw = 60,
            Sky = new Color(0.82f, 0.56f, 0.72f), Equator = new Color(0.86f, 0.58f, 0.52f), Ground = new Color(0.4f, 0.34f, 0.42f),
            Fog = new Color(0.92f, 0.6f, 0.58f), Background = new Color(0.95f, 0.55f, 0.48f), Grade = new Color(1f, 0.88f, 0.84f),
            Night = 0.45f, Bloom = 0.9f, Saturation = 8, Exposure = 0f,
        };
        static readonly Preset Night = new()
        {
            Sun = new Color(0.55f, 0.66f, 1f), SunIntensity = 0.42f, SunPitch = 58, SunYaw = 20,
            Sky = new Color(0.26f, 0.32f, 0.58f), Equator = new Color(0.2f, 0.24f, 0.44f), Ground = new Color(0.12f, 0.12f, 0.2f),
            Fog = new Color(0.16f, 0.2f, 0.38f), Background = new Color(0.1f, 0.12f, 0.26f), Grade = new Color(0.82f, 0.88f, 1f),
            Night = 1f, Bloom = 1.25f, Saturation = 2, Exposure = -0.1f,
        };

        public Light Sun;
        public GlenWorld World;
        public Camera Cam;
        public Volume Volume;
        public WeatherDirector Weather;

        DayPhase phase;
        Preset current;
        bool initialised;
        Bloom bloom;
        ColorAdjustments grade;
        public DayPhase Phase => phase;
        public event Action<DayPhase> PhaseChanged;

        public static Volume CreateVolume()
        {
            var go = new GameObject("PostFX");
            var v = go.AddComponent<Volume>();
            v.isGlobal = true;
            var profile = ScriptableObject.CreateInstance<VolumeProfile>();
            var bl = profile.Add<Bloom>(true);
            bl.threshold.Override(0.92f);
            bl.intensity.Override(0.5f);
            bl.scatter.Override(0.65f);
            var tm = profile.Add<Tonemapping>(true);
            tm.mode.Override(TonemappingMode.Neutral);
            var ca = profile.Add<ColorAdjustments>(true);
            ca.saturation.Override(8);
            ca.contrast.Override(6);
            var vig = profile.Add<Vignette>(true);
            vig.intensity.Override(0.2f);
            vig.smoothness.Override(0.5f);
            v.sharedProfile = profile;
            return v;
        }

        void Start()
        {
            Volume.sharedProfile.TryGet(out bloom);
            Volume.sharedProfile.TryGet(out grade);
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 26;
            RenderSettings.fogEndDistance = 55;
            phase = Catalog.PhaseAt(DateTime.Now);
            current = For(phase);
            initialised = true;
            Apply(current, 1);
        }

        static Preset For(DayPhase p) => p switch { DayPhase.Dawn => Dawn, DayPhase.Day => Day, DayPhase.Dusk => Dusk, _ => Night };

        public void Cycle()
        {
            var next = (DayPhase)(((int)Catalog.PhaseAt(DateTime.Now) + 1) % 4);
            if (Catalog.DebugPhaseOverride.HasValue) next = (DayPhase)(((int)Catalog.DebugPhaseOverride.Value + 1) % 4);
            Catalog.DebugPhaseOverride = next;
        }

        void Update()
        {
            if (!initialised) return;
            var now = Catalog.PhaseAt(DateTime.Now);
            if (now != phase)
            {
                phase = now;
                PhaseChanged?.Invoke(phase);
            }
            var target = For(phase);
            float k = 1 - Mathf.Exp(-Time.deltaTime * 0.8f);
            current = Lerp(current, target, k);
            Apply(current, k);
        }

        static Preset Lerp(Preset a, Preset b, float t) => new()
        {
            Sun = Color.Lerp(a.Sun, b.Sun, t), Sky = Color.Lerp(a.Sky, b.Sky, t), Equator = Color.Lerp(a.Equator, b.Equator, t),
            Ground = Color.Lerp(a.Ground, b.Ground, t), Fog = Color.Lerp(a.Fog, b.Fog, t), Background = Color.Lerp(a.Background, b.Background, t),
            Grade = Color.Lerp(a.Grade, b.Grade, t),
            SunIntensity = Mathf.Lerp(a.SunIntensity, b.SunIntensity, t), SunPitch = Mathf.Lerp(a.SunPitch, b.SunPitch, t),
            SunYaw = Mathf.LerpAngle(a.SunYaw, b.SunYaw, t), Night = Mathf.Lerp(a.Night, b.Night, t), Bloom = Mathf.Lerp(a.Bloom, b.Bloom, t),
            Saturation = Mathf.Lerp(a.Saturation, b.Saturation, t), Exposure = Mathf.Lerp(a.Exposure, b.Exposure, t),
        };

        void Apply(Preset p, float k)
        {
            if (Sun)
            {
                Sun.color = p.Sun;
                Sun.intensity = p.SunIntensity;
                Sun.transform.rotation = Quaternion.Euler(p.SunPitch, p.SunYaw, 0);
            }
            RenderSettings.ambientSkyColor = p.Sky;
            RenderSettings.ambientEquatorColor = p.Equator;
            RenderSettings.ambientGroundColor = p.Ground;
            RenderSettings.fogColor = p.Fog;
            if (Cam) Cam.backgroundColor = p.Background;
            if (bloom != null) bloom.intensity.value = p.Bloom;
            if (grade != null)
            {
                grade.colorFilter.Override(p.Grade);
                grade.saturation.value = p.Saturation;
                grade.postExposure.Override(p.Exposure);
            }
            if (World)
            {
                foreach (var l in World.Lamps) if (l) l.intensity = Mathf.Lerp(0, 2.2f, Mathf.InverseLerp(0.3f, 1f, p.Night));
                var glow = Color.Lerp(Color.black, new Color(1f, 0.72f, 0.35f) * 1.4f, Mathf.InverseLerp(0.2f, 0.9f, p.Night));
                foreach (var m in World.WindowMats) if (m) m.SetColor("_EmissionColor", glow);
            }
            if (Weather) Weather.Night = p.Night;
        }
    }

    /// Particle weather and ambient life, all built in code with the soft particle shader.
    public sealed class WeatherDirector : MonoBehaviour
    {
        public Transform Follow;
        public Transform Chimney;
        public float Night;
        public bool Raining { get; private set; }
        ParticleSystem petals, rain, fireflies, butterflies, smoke;
        float rainRoll;

        void Start()
        {
            petals = Make("Petals", 14, new Color(1f, 0.82f, 0.88f, 0.9f), 0.09f, false, 0, new Vector3(22, 1, 16), 1.5f, 6, new Vector3(0.5f, -0.35f, 0.2f));
            rain = Make("Rain", 0, new Color(0.75f, 0.85f, 1f, 0.55f), 0.06f, false, 2, new Vector3(24, 1, 18), 0.8f, 9, new Vector3(0.6f, -14f, 0));
            var rr = rain.GetComponent<ParticleSystemRenderer>();
            rr.renderMode = ParticleSystemRenderMode.Stretch;
            rr.lengthScale = 4;
            fireflies = Make("Fireflies", 0, new Color(1f, 0.92f, 0.45f, 1f), 0.12f, true, 1, new Vector3(22, 2, 16), 4, 0.5f, Vector3.zero);
            var fn = fireflies.noise;
            fn.enabled = true;
            fn.strength = 0.6f;
            fn.frequency = 0.4f;
            butterflies = Make("Butterflies", 4, new Color(1f, 0.95f, 0.6f, 1f), 0.14f, false, 1, new Vector3(18, 1, 14), 6, 0.3f, Vector3.zero);
            var bn = butterflies.noise;
            bn.enabled = true;
            bn.strength = 1.2f;
            bn.frequency = 0.8f;
            var bc = butterflies.colorOverLifetime;
            bc.enabled = true;
            bc.color = new ParticleSystem.MinMaxGradient(new Color(1f, 0.7f, 0.85f), new Color(0.75f, 0.85f, 1f));
            if (Chimney)
            {
                smoke = Make("ChimneySmoke", 3, new Color(0.96f, 0.96f, 1f, 0.55f), 0.5f, false, 0, new Vector3(0.2f, 0.1f, 0.2f), 3.5f, 0.6f, new Vector3(0.2f, 0.7f, 0));
                smoke.transform.SetParent(Chimney, false);
                smoke.transform.localPosition = Vector3.zero;
                var sz = smoke.sizeOverLifetime;
                sz.enabled = true;
                sz.size = new ParticleSystem.MinMaxCurve(1f, AnimationCurve.Linear(0, 0.4f, 1, 1.6f));
                var col = smoke.colorOverLifetime;
                col.enabled = true;
                var g = new Gradient();
                g.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
                    new[] { new GradientAlphaKey(0, 0), new GradientAlphaKey(0.6f, 0.2f), new GradientAlphaKey(0, 1) });
                col.color = g;
            }
            rainRoll = UnityEngine.Random.value;
        }

        ParticleSystem Make(string name, float rate, Color color, float size, bool additive, int shape, Vector3 box, float life, float speed, Vector3 velocity)
        {
            var go = new GameObject(name);
            go.transform.SetParent(transform, false);
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = ps.main;
            main.loop = true;
            main.startLifetime = life;
            main.startSpeed = 0;
            main.startSize = new ParticleSystem.MinMaxCurve(size * 0.7f, size * 1.3f);
            main.startColor = color;
            main.maxParticles = 600;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            var em = ps.emission;
            em.rateOverTime = rate;
            var sh = ps.shape;
            sh.shapeType = ParticleSystemShapeType.Box;
            sh.scale = box;
            var vel = ps.velocityOverLifetime;
            vel.enabled = velocity != Vector3.zero;
            vel.space = ParticleSystemSimulationSpace.World;
            vel.x = velocity.x; vel.y = velocity.y; vel.z = velocity.z;
            var r = go.GetComponent<ParticleSystemRenderer>();
            r.sharedMaterial = Mats.Particle(additive, shape);
            _ = speed;
            ps.Play();
            return ps;
        }

        void Update()
        {
            if (Follow)
            {
                var p = Follow.position;
                petals.transform.position = p + new Vector3(0, 5, 2);
                rain.transform.position = p + new Vector3(0, 9, 3);
                fireflies.transform.position = p + new Vector3(0, 1.2f, 1);
                butterflies.transform.position = p + new Vector3(0, 1f, 1);
            }
            var phase = Catalog.PhaseAt(DateTime.Now);
            // Rain is a property of the (real) day: about one day in four, during daytime.
            Raining = phase == DayPhase.Day && ((DateTime.Now.DayOfYear * 7919 + (int)(rainRoll * 4)) % 4 == 0);
            SetRate(rain, Raining ? 220 : 0);
            SetRate(petals, !Raining && phase is DayPhase.Dawn or DayPhase.Day ? 10 : 0);
            SetRate(butterflies, !Raining && phase == DayPhase.Day ? 3 : 0);
            SetRate(fireflies, Mathf.Lerp(0, 18, Mathf.InverseLerp(0.4f, 1f, Night)));
        }

        static void SetRate(ParticleSystem ps, float rate)
        {
            if (!ps) return;
            var em = ps.emission;
            em.rateOverTime = rate;
        }
    }

    /// One-shot effect bursts: hearts, sparkles, dust, element hits, evolution light.
    public static class Fx
    {
        public static void Burst(Vector3 at, Color color, int count = 14, float speed = 2.2f, float size = 0.16f, bool additive = true, int shape = 1, float life = 0.8f, float gravity = -0.2f)
        {
            var go = new GameObject("Fx");
            go.transform.position = at;
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = ps.main;
            main.loop = false;
            main.duration = 0.2f;
            main.startLifetime = new ParticleSystem.MinMaxCurve(life * 0.6f, life);
            main.startSpeed = new ParticleSystem.MinMaxCurve(speed * 0.5f, speed);
            main.startSize = new ParticleSystem.MinMaxCurve(size * 0.6f, size * 1.2f);
            main.startColor = color;
            main.gravityModifier = -gravity;
            main.stopAction = ParticleSystemStopAction.Destroy;
            var em = ps.emission;
            em.rateOverTime = 0;
            em.SetBursts(new[] { new ParticleSystem.Burst(0, (short)count) });
            var sh = ps.shape;
            sh.shapeType = ParticleSystemShapeType.Sphere;
            sh.radius = 0.15f;
            var sz = ps.sizeOverLifetime;
            sz.enabled = true;
            sz.size = new ParticleSystem.MinMaxCurve(1, AnimationCurve.EaseInOut(0, 1, 1, 0));
            go.GetComponent<ParticleSystemRenderer>().sharedMaterial = Mats.Particle(additive, shape);
            ps.Play();
        }

        public static void Hearts(Vector3 at) => Burst(at + Vector3.up * 0.9f, new Color(1f, 0.55f, 0.65f), 8, 1.2f, 0.2f, false, 0, 1.1f, 0.6f);
        public static void Sparkle(Vector3 at, Color c) => Burst(at + Vector3.up * 0.6f, c, 16, 2.4f, 0.18f, true, 1, 0.7f, 0);
        public static void Dust(Vector3 at) => Burst(at + Vector3.up * 0.1f, new Color(0.9f, 0.84f, 0.72f, 0.7f), 8, 1.1f, 0.22f, false, 0, 0.5f, 0.2f);

        public static void Element(Vector3 at, KinElement e)
        {
            switch (e)
            {
                case KinElement.Bloom:
                    Burst(at, new Color(0.5f, 0.9f, 0.4f), 22, 3f, 0.2f, false, 0, 0.9f, -0.4f);
                    Burst(at, new Color(1f, 0.8f, 0.9f), 10, 2f, 0.14f, false, 0, 1f, -0.3f);
                    break;
                case KinElement.Tide:
                    Burst(at, new Color(0.55f, 0.85f, 1f), 26, 3.4f, 0.18f, false, 0, 0.7f, -1.5f);
                    Burst(at, Color.white, 10, 2f, 0.12f, true, 1, 0.5f, 0);
                    break;
                default:
                    Burst(at, new Color(1f, 0.6f, 0.15f), 24, 3.6f, 0.16f, true, 1, 0.6f, 0.5f);
                    Burst(at, new Color(1f, 0.9f, 0.4f), 12, 2f, 0.22f, true, 0, 0.5f, 0.8f);
                    break;
            }
        }
    }
}
