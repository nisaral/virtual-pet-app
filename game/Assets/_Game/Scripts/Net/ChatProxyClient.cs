using System;
using System.Collections;
using System.Text;
using Newtonsoft.Json;
using UnityEngine;
using UnityEngine.Networking;

namespace LuminaVale
{
    /// Asks the kin's "voice" for a line through a small server-side proxy
    /// (see supabase/functions/kin-voice). The OpenRouter key lives only on the server.
    /// Without an endpoint configured, falls back to lines built from memories.
    public static class ChatProxyClient
    {
        static string endpoint;

        /// Put the proxy URL in Assets/_Game/Resources/kin_voice_endpoint.txt (not secret).
        public static string Endpoint
        {
            get
            {
                if (endpoint != null) return endpoint;
                var asset = Resources.Load<TextAsset>("kin_voice_endpoint");
                endpoint = asset ? asset.text.Trim() : "";
                return endpoint;
            }
        }

        public static IEnumerator Thought(SaveData save, Action<string> done)
        {
            var kin = save.Kin;
            string fallback = LocalLine(save);
            if (string.IsNullOrEmpty(Endpoint)) { done(fallback); yield break; }
            var payload = new
            {
                name = kin.Name,
                species = kin.Def.TitleFor(kin.Stage),
                nature = kin.Nature,
                mood = kin.MoodAt(DateTime.Now).ToString(),
                phase = Catalog.PhaseAt(DateTime.Now).ToString(),
                stats = new { kin.Satiation, kin.Energy, kin.Coat, kin.Joy, kin.Bond },
                memories = save.Memories.GetRange(0, Math.Min(6, save.Memories.Count)).ConvertAll(m => m.Text),
                keeper = save.KeeperName,
            };
            using var req = new UnityWebRequest(Endpoint, "POST")
            {
                uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(payload))),
                downloadHandler = new DownloadHandlerBuffer(),
                timeout = 8,
            };
            req.SetRequestHeader("Content-Type", "application/json");
            yield return req.SendWebRequest();
            if (req.result != UnityWebRequest.Result.Success) { done(fallback); yield break; }
            try
            {
                var reply = JsonConvert.DeserializeAnonymousType(req.downloadHandler.text, new { line = "" });
                done(string.IsNullOrWhiteSpace(reply?.line) ? fallback : reply.line.Trim());
            }
            catch
            {
                done(fallback);
            }
        }

        static string LocalLine(SaveData save)
        {
            var kin = save.Kin;
            var mood = kin.MoodAt(DateTime.Now);
            if (kin.Satiation < 35) return "(its tummy rumbles, and it looks at the pavilion)";
            if (kin.Energy < 30) return "(a big yawn… it leans on your leg)";
            if (kin.Coat < 35) return "(it scratches an ear and looks at the brush)";
            if (save.Memories.Count > 1 && UnityEngine.Random.value < 0.5f)
                return $"(it seems to remember: \"{save.Memories[UnityEngine.Random.Range(0, Math.Min(5, save.Memories.Count))].Text}\")";
            return mood switch
            {
                Mood.Radiant => "(it bounces in a little circle, glowing)",
                Mood.Glad => "(a happy chirp, tail going)",
                _ => "(it watches the glen with you, quietly content)",
            };
        }
    }
}
