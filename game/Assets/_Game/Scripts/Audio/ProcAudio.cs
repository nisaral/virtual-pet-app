using System;
using System.Collections.Generic;
using UnityEngine;

namespace LuminaVale
{
    /// Every sound in the slice is synthesised at boot: no audio files needed, and a
    /// real soundtrack can replace any key later via Resources/Audio/<key>.
    public sealed class ProcAudio : MonoBehaviour
    {
        public static ProcAudio I { get; private set; }
        const int Rate = 22050;

        readonly Dictionary<string, AudioClip> clips = new();
        AudioSource sfx, musicA, musicB;
        bool aActive = true;
        string currentTrack;
        public float MusicVolume = 0.32f, SfxVolume = 0.8f;

        void Awake()
        {
            I = this;
            sfx = gameObject.AddComponent<AudioSource>();
            musicA = gameObject.AddComponent<AudioSource>();
            musicB = gameObject.AddComponent<AudioSource>();
            musicA.loop = musicB.loop = true;
            musicA.volume = musicB.volume = 0;
            BuildSfx();
        }

        // ---- Public API ----------------------------------------------------------------

        public void Play(string key, float volume = 1f, float pitch = 1f)
        {
            if (!clips.TryGetValue(key, out var clip)) return;
            sfx.pitch = pitch;
            sfx.PlayOneShot(clip, volume * SfxVolume);
        }

        public void Chirp(SpeciesId species, float pitch = 1f) => Play("chirp_" + species, 0.7f, pitch * UnityEngine.Random.Range(0.94f, 1.06f));

        public void Music(string track)
        {
            if (track == currentTrack) return;
            currentTrack = track;
            if (!clips.TryGetValue("music_" + track, out var clip))
            {
                clip = Resources.Load<AudioClip>("Audio/music_" + track) ?? BuildMusic(track);
                clips["music_" + track] = clip;
            }
            var next = aActive ? musicB : musicA;
            next.clip = clip;
            next.volume = 0;
            next.Play();
            aActive = !aActive;
        }

        void Update()
        {
            var on = aActive ? musicA : musicB;
            var off = aActive ? musicB : musicA;
            on.volume = Mathf.MoveTowards(on.volume, MusicVolume, Time.unscaledDeltaTime * 0.4f);
            off.volume = Mathf.MoveTowards(off.volume, 0, Time.unscaledDeltaTime * 0.4f);
            if (off.volume <= 0 && off.isPlaying) off.Stop();
        }

        // ---- SFX -----------------------------------------------------------------------

        void BuildSfx()
        {
            Add("step", 0.07f, t => Noise() * Env(t, 0.003f, 0.06f) * 0.35f);
            Add("hop", 0.22f, t => Sine(260 + t * 1600, t) * Env(t, 0.005f, 0.2f) * 0.5f);
            Add("land", 0.12f, t => (Noise() * 0.5f + Sine(90, t)) * Env(t, 0.002f, 0.11f) * 0.5f);
            Add("blip", 0.07f, t => Square(880, t) * Env(t, 0.002f, 0.06f) * 0.22f);
            Add("confirm", 0.22f, t => (Sine(660, t) * (t < 0.08f ? 1 : 0) + Sine(990, t) * (t >= 0.08f ? 1 : 0)) * Env(t, 0.004f, 0.2f) * 0.4f);
            Add("cancel", 0.16f, t => Sine(520 - t * 1200, t) * Env(t, 0.004f, 0.15f) * 0.35f);
            Add("sparkle", 0.6f, t => (Sine(1568, t) + Sine(2093, t) * 0.6f + Sine(2637, t) * 0.4f) * Env(t, 0.004f, 0.55f) * 0.18f * (0.6f + 0.4f * Mathf.Sin(t * 60)));
            Add("pickup", 0.3f, t => Sine(t < 0.1f ? 784 : 1175, t) * Env(t, 0.003f, 0.28f) * 0.4f);
            Add("brush", 0.18f, t => Noise() * Env(t, 0.03f, 0.15f) * 0.22f * (0.5f + 0.5f * Mathf.Sin(t * 90)));
            Add("munch", 0.14f, t => (Noise() * 0.6f + Square(140, t) * 0.4f) * Env(t, 0.002f, 0.12f) * 0.4f);
            Add("hit", 0.28f, t => (Noise() * 0.7f + Sine(110 - t * 200, t)) * Env(t, 0.001f, 0.26f) * 0.6f);
            Add("guard", 0.35f, t => (Sine(330, t) + Sine(495, t)) * Env(t, 0.01f, 0.33f) * 0.3f);
            Add("whoosh", 0.4f, t => Noise() * Env(t, 0.15f, 0.25f) * 0.35f);
            Add("rune", 0.5f, t => (Sine(523, t) + Sine(784, t) * 0.5f) * Env(t, 0.005f, 0.48f) * 0.32f);
            Add("rune_bad", 0.4f, t => Square(140, t) * Env(t, 0.005f, 0.38f) * 0.25f);
            Add("evolve", 2.6f, t => (Sine(220 * Mathf.Pow(2, t * 1.4f), t) + Sine(330 * Mathf.Pow(2, t * 1.4f), t) * 0.6f) * Env(t, 0.4f, 2.2f) * 0.3f);
            Add("fanfare", 1.4f, t =>
            {
                float[] notes = { 523, 659, 784, 1047 };
                int i = Mathf.Min(3, (int)(t / 0.16f));
                float local = t - i * 0.16f;
                return Square(notes[i], t) * 0.18f * Env(local, 0.005f, i == 3 ? 1f : 0.15f) + Sine(notes[i] / 2, t) * 0.2f * Env(t, 0.01f, 1.3f);
            });
            // Species voices: short formant-ish chirps with different contours.
            Add("chirp_Pipkin", 0.26f, t => Sine(700 + Mathf.Sin(t * 40) * 120 + t * 900, t) * Env(t, 0.01f, 0.24f) * 0.4f);
            Add("chirp_Marrow", 0.32f, t => (Sine(420 + Mathf.Sin(t * 22) * 90, t) + Sine(840 + Mathf.Sin(t * 22) * 180, t) * 0.4f) * Env(t, 0.02f, 0.28f) * 0.38f);
            Add("chirp_Solbit", 0.22f, t => (Square(560 + t * 1400, t) * 0.4f + Sine(1120 + t * 2800, t) * 0.5f) * Env(t, 0.005f, 0.2f) * 0.32f);
        }

        void Add(string key, float seconds, Func<float, float> fn)
        {
            var custom = Resources.Load<AudioClip>("Audio/" + key);
            if (custom) { clips[key] = custom; return; }
            int n = Mathf.CeilToInt(seconds * Rate);
            var data = new float[n];
            for (int i = 0; i < n; i++) data[i] = Mathf.Clamp(fn(i / (float)Rate), -1, 1);
            var clip = AudioClip.Create(key, n, 1, Rate, false);
            clip.SetData(data, 0);
            clips[key] = clip;
        }

        static readonly System.Random NoiseRng = new(3);
        static float Noise() => (float)NoiseRng.NextDouble() * 2 - 1;
        static float Sine(float f, float t) => Mathf.Sin(2 * Mathf.PI * f * t);
        static float Square(float f, float t) => Mathf.Sign(Mathf.Sin(2 * Mathf.PI * f * t)) * 0.6f;
        static float Tri(float f, float t) => Mathf.PingPong(t * f * 4, 2) - 1;
        static float Env(float t, float attack, float release) => t < attack ? t / attack : Mathf.Max(0, 1 - (t - attack) / release);

        // ---- Music ---------------------------------------------------------------------

        /// Generative loop: pad chords + plucked arpeggio + soft bass, one mood per track.
        AudioClip BuildMusic(string track)
        {
            float bpm; int[][] chords; float bright; bool swing;
            switch (track)
            {
                case "dawn": bpm = 84; bright = 0.6f; swing = false; chords = new[] { new[] { 62, 66, 69, 73 }, new[] { 59, 62, 66, 69 }, new[] { 55, 59, 62, 66 }, new[] { 57, 61, 64, 69 } }; break;
                case "dusk": bpm = 76; bright = 0.45f; swing = true; chords = new[] { new[] { 57, 60, 64, 67 }, new[] { 53, 57, 60, 64 }, new[] { 55, 59, 62, 65 }, new[] { 52, 55, 59, 64 } }; break;
                case "night": bpm = 64; bright = 0.3f; swing = false; chords = new[] { new[] { 52, 55, 59, 62 }, new[] { 48, 52, 55, 59 }, new[] { 50, 53, 57, 60 }, new[] { 47, 50, 54, 57 } }; break;
                case "battle": bpm = 138; bright = 1f; swing = false; chords = new[] { new[] { 57, 60, 64 }, new[] { 53, 57, 60 }, new[] { 55, 59, 62 }, new[] { 52, 56, 59 } }; break;
                default: bpm = 96; bright = 0.8f; swing = true; chords = new[] { new[] { 60, 64, 67, 71 }, new[] { 57, 60, 64, 67 }, new[] { 53, 57, 60, 64 }, new[] { 55, 59, 62, 65 } }; break;
            }
            float beat = 60f / bpm;
            int bars = 8, beatsPerBar = 4;
            float seconds = bars * beatsPerBar * beat;
            int n = Mathf.CeilToInt(seconds * Rate);
            var data = new float[n];
            var rng = new System.Random(track.GetHashCode());
            static float Hz(int midi) => 440f * Mathf.Pow(2, (midi - 69) / 12f);

            for (int bar = 0; bar < bars; bar++)
            {
                var chord = chords[bar % chords.Length];
                float barStart = bar * beatsPerBar * beat;
                // Pad: detuned triangle chord with slow swell.
                Render(data, barStart, beatsPerBar * beat, (t, len) =>
                {
                    float s = 0;
                    foreach (var m in chord) s += Tri(Hz(m), t) * 0.5f + Tri(Hz(m) * 1.003f, t) * 0.5f;
                    float env = Mathf.Min(1, t / 0.6f) * Mathf.Min(1, (len - t) / 0.4f);
                    return s * 0.035f * env;
                });
                // Bass on beats 1 and 3.
                for (int b = 0; b < beatsPerBar; b += 2)
                {
                    int root = chord[0] - 12;
                    Render(data, barStart + b * beat, beat * 1.8f, (t, len) => Sine(Hz(root), t) * 0.16f * Env(t, 0.01f, len));
                }
                // Arpeggio: eighth notes, pentatonic-safe chord tones up an octave.
                int steps = beatsPerBar * (track == "battle" ? 4 : 2);
                float stepLen = beatsPerBar * beat / steps;
                for (int i = 0; i < steps; i++)
                {
                    if (rng.NextDouble() < (track == "night" ? 0.45 : 0.18)) continue;
                    int note = chord[(i + bar) % chord.Length] + 12 + (rng.NextDouble() < 0.2 ? 12 : 0);
                    float start = barStart + i * stepLen + (swing && i % 2 == 1 ? stepLen * 0.18f : 0);
                    float vel = (i % 2 == 0 ? 1f : 0.7f) * bright;
                    Render(data, start, stepLen * 2.5f, (t, len) =>
                    {
                        float f = Hz(note);
                        float pluck = Sine(f, t) + Sine(f * 2, t) * 0.3f * Mathf.Exp(-t * 18) + Sine(f * 3, t) * 0.12f * Mathf.Exp(-t * 30);
                        return pluck * 0.07f * vel * Mathf.Exp(-t * (track == "battle" ? 9 : 5));
                    });
                }
                if (track == "battle")
                    for (int b = 0; b < beatsPerBar * 2; b++)
                        Render(data, barStart + b * beat / 2, 0.08f, (t, len) => Noise() * 0.06f * Env(t, 0.001f, 0.07f) * (b % 2 == 0 ? 1.4f : 0.6f));
            }
            // Seam fade so the loop clicks less.
            for (int i = 0; i < 400 && i < n; i++) { data[i] *= i / 400f; data[n - 1 - i] *= i / 400f; }
            var clip = AudioClip.Create("music_" + track, n, 1, Rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        static void Render(float[] data, float start, float length, Func<float, float, float> fn)
        {
            int s = Mathf.FloorToInt(start * Rate);
            int len = Mathf.CeilToInt(length * Rate);
            for (int i = 0; i < len; i++)
            {
                int idx = s + i;
                if (idx >= data.Length) idx -= data.Length; // wrap tails into the loop start
                data[idx] += fn(i / (float)Rate, length);
            }
        }
    }
}
