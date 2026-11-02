using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;
using UnityEngine;

namespace LuminaVale
{
    /// Port of ValeSave. Everything the kin has learned lives here.
    [Serializable]
    public sealed class SaveData
    {
        public int Version = 1;
        public string KeeperName = "Keeper";
        public DateTime CreatedAt = DateTime.Now;
        public DateTime LastSeen = DateTime.Now;
        public Kin Kin;
        public List<MemoryNote> Memories = new();
        public Dictionary<string, int> Bag = new() { ["sunberry"] = 3, ["kelpbit"] = 3, ["spicecrumb"] = 3, ["milkdrop"] = 2 };
        public int Gleam;
        public Dictionary<string, float[]> QTable = new();
        public RoutineModel Routine = new();
        public Dictionary<string, float[]> SparQ = new();
        public Dictionary<string, float[]> SpatialQ = new();
        public Dictionary<string, int> SpatialCounts = new();
        public int MindSteps;
        public int SpatialSteps;
        public HashSet<string> GamesPlayed = new();
        public HashSet<string> TakenPickups = new();
        public HashSet<string> MetFolk = new();
        /// Farm plots: 0 empty, 1 watered, 2 ripe. Key is spot id.
        public Dictionary<string, int> Farm = new();
        public int FarmDay = -1;
        /// Emotions, learned rhythms and growth credit (replaces XP levels).
        public Psyche Psyche = new();
        /// Wild kin you've caught, the Kindex of what you've seen, and the tools for it.
        public List<CaughtKin> Caught = new();
        public HashSet<string> Seen = new();
        public int Charms = 5;
        public int FishCaught;
        public RangerRequest Request;
        /// Visit counts and replay buffers for each learner ("bond", "spar", "spatial").
        public Dictionary<string, MindMemory> Minds = new();

        public MindMemory Mind(string id)
        {
            Minds ??= new();
            if (!Minds.TryGetValue(id, out var m) || m == null) Minds[id] = m = new MindMemory();
            return m;
        }
    }

    [Serializable]
    public sealed class CaughtKin
    {
        public SpeciesId Species;
        public int Stage;
        public string Name;
        public string Zone;
        public DateTime At = DateTime.Now;
    }

    /// A daily task from the rangers: catch a certain kind of kin.
    [Serializable]
    public sealed class RangerRequest
    {
        public SpeciesId Species;
        public DateTime Given = DateTime.Now;
        public bool Rewarded;
    }

    public static class SaveSystem
    {
        static string PathFor => System.IO.Path.Combine(Application.persistentDataPath, "lumina_vale_save.json");

        static readonly JsonSerializerSettings Settings = new()
        {
            Formatting = Formatting.Indented,
            NullValueHandling = NullValueHandling.Include,
            ReferenceLoopHandling = ReferenceLoopHandling.Ignore,
        };

        public static bool Exists => File.Exists(PathFor);

        public static SaveData Load()
        {
            try
            {
                if (!File.Exists(PathFor)) return null;
                return JsonConvert.DeserializeObject<SaveData>(File.ReadAllText(PathFor), Settings);
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[Save] Could not read save, starting fresh: {e.Message}");
                return null;
            }
        }

        public static void Write(SaveData save)
        {
            if (save == null) return;
            try
            {
                string tmp = PathFor + ".tmp";
                File.WriteAllText(tmp, JsonConvert.SerializeObject(save, Settings));
                if (File.Exists(PathFor)) File.Delete(PathFor);
                File.Move(tmp, PathFor);
            }
            catch (Exception e)
            {
                Debug.LogError($"[Save] Write failed: {e.Message}");
            }
        }

        public static void Delete()
        {
            if (File.Exists(PathFor)) File.Delete(PathFor);
        }
    }
}
