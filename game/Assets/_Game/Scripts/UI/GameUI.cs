using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace LuminaVale
{
    public struct Choice
    {
        public string Label, Sub;
        public Action Act;
        public bool Enabled;
        public Choice(string label, Action act, string sub = "", bool enabled = true) { Label = label; Act = act; Sub = sub; Enabled = enabled; }
    }

    /// All screen UI. The Director tells it what to show; it never changes game state itself.
    public sealed class GameUI : MonoBehaviour
    {
        public Camera Cam;
        Canvas canvas;
        RectTransform root, hud, dialog, choices, toast, battle, title, overlay, meter;
        Text kinName, kinTitle, gleamText, phaseText, promptText, dialogText, dialogName, toastText, meterLabel;
        Image fade, meterFill;
        readonly Dictionary<string, Image> bars = new();
        RectTransform bidBubble, thoughtBubble;
        Text bidText, thoughtText;
        Transform bubbleTarget;
        Button aButton;

        readonly Queue<(string who, string line)> lines = new();
        Action onDialogDone;
        string fullLine = "";
        float typed;
        bool typing;
        public bool DialogOpen => dialog && dialog.gameObject.activeSelf;
        public bool ChoicesOpen => choices && choices.gameObject.activeSelf;
        public bool Blocking => DialogOpen || ChoicesOpen || (title && title.gameObject.activeSelf);

        const float BarW = 210;

        public void Init(Camera cam)
        {
            Cam = cam;
            UiKit.EnsureEventSystem();
            canvas = UiKit.Canvas("GameUI", 10);
            canvas.transform.SetParent(transform, false);
            root = (RectTransform)canvas.transform;
            BuildHud();
            BuildEmotions();
            BuildBubbles();
            BuildDialog();
            BuildChoices();
            BuildToast();
            BuildBattle();
            BuildMeter();
            title = UiKit.Stretch("Title", root);
            title.gameObject.SetActive(false);
            overlay = UiKit.Stretch("Fade", root);
            fade = overlay.gameObject.AddComponent<Image>();
            fade.color = new Color(1, 0.98f, 0.94f, 0);
            fade.raycastTarget = false;
        }

        // ---- HUD -----------------------------------------------------------------------

        void BuildHud()
        {
            hud = UiKit.Stretch("HUD", root);
            var card = UiKit.Rect("KinCard", hud, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(28, -60), new Vector2(470, 250));
            UiKit.Panel(card, UiKit.Cream);
            kinName = UiKit.Label(card, "", 46, UiKit.Ink, TextAnchor.UpperLeft, true);
            Pad(kinName.rectTransform, 28, 18, 28, 0);
            kinTitle = UiKit.Label(card, "", 28, new Color(0.45f, 0.38f, 0.48f), TextAnchor.UpperLeft);
            Pad(kinTitle.rectTransform, 30, 74, 28, 0);
            string[] keys = { "Satiation", "Energy", "Coat", "Joy" };
            Color[] cols = { new(0.98f, 0.62f, 0.4f), new(0.45f, 0.72f, 1f), new(0.65f, 0.55f, 0.95f), new(1f, 0.7f, 0.82f) };
            for (int i = 0; i < 4; i++)
            {
                int col = i % 2, row = i / 2;
                var label = UiKit.Rect(keys[i], card, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(28 + col * 222, -122 - row * 58), new Vector2(200, 26));
                UiKit.Label(label, keys[i] == "Satiation" ? "Food" : keys[i], 22, new Color(0.45f, 0.38f, 0.48f));
                var fill = UiKit.Bar(card, keys[i] + "Bar", new Vector2(28 + col * 222, -148 - row * 58), new Vector2(BarW - 14, 22), cols[i], out _);
                bars[keys[i]] = fill;
            }

            var chip = UiKit.Rect("Chip", hud, new Vector2(1, 1), new Vector2(1, 1), new Vector2(1, 1), new Vector2(-28, -60), new Vector2(300, 128));
            UiKit.Panel(chip, UiKit.Cream);
            phaseText = UiKit.Label(chip, "", 34, UiKit.Ink, TextAnchor.UpperCenter, true);
            Pad(phaseText.rectTransform, 10, 14, 10, 0);
            gleamText = UiKit.Label(chip, "", 30, new Color(0.75f, 0.52f, 0.1f), TextAnchor.LowerCenter, true);
            Pad(gleamText.rectTransform, 10, 0, 10, 16);

            // Bottom controls.
            var stickArea = UiKit.Rect("StickArea", hud, new Vector2(0, 0), new Vector2(0.55f, 0.42f), new Vector2(0, 0), Vector2.zero, Vector2.zero);
            var areaImg = stickArea.gameObject.AddComponent<Image>();
            areaImg.color = new Color(0, 0, 0, 0);
            var js = stickArea.gameObject.AddComponent<VirtualJoystick>();
            var ring = UiKit.Rect("Ring", stickArea, Vector2.zero, Vector2.zero, new Vector2(0.5f, 0.5f), new Vector2(220, 260), new Vector2(260, 260));
            UiKit.Panel(ring, new Color(1, 1, 1, 0.28f), false, UiKit.Circle);
            ring.GetComponent<Image>().raycastTarget = false;
            var knob = UiKit.Rect("Knob", stickArea, Vector2.zero, Vector2.zero, new Vector2(0.5f, 0.5f), new Vector2(220, 260), new Vector2(120, 120));
            UiKit.Panel(knob, new Color(1, 0.98f, 0.92f, 0.85f), true, UiKit.Circle);
            knob.GetComponent<Image>().raycastTarget = false;
            js.Ring = ring;
            js.Knob = knob;
            ring.gameObject.SetActive(false);

            aButton = UiKit.Button(hud, "A", new Vector2(-170, 250), new Vector2(210, 210), UiKit.Gold, GameInput.PressA, 64, new Vector2(1, 0));
            aButton.GetComponent<Image>().sprite = UiKit.Circle;
            var prompt = UiKit.Rect("Prompt", hud, new Vector2(1, 0), new Vector2(1, 0), new Vector2(0.5f, 0.5f), new Vector2(-170, 400), new Vector2(300, 64));
            UiKit.Panel(prompt, new Color(0.2f, 0.16f, 0.22f, 0.8f), false);
            promptText = UiKit.Label(prompt, "", 30, Color.white, TextAnchor.MiddleCenter, true);
            var menu = UiKit.Button(hud, "Menu", new Vector2(-120, 520), new Vector2(170, 90), UiKit.Cream, GameInput.PressMenu, 34, new Vector2(1, 0));
            var map = UiKit.Button(hud, "Map", new Vector2(-120, 630), new Vector2(170, 90), UiKit.Teal, GameInput.PressMap, 34, new Vector2(1, 0));
            _ = menu;
            _ = map;
            ApplySafeArea(hud);
        }

        static void ApplySafeArea(RectTransform rt)
        {
            var sa = Screen.safeArea;
            float w = Mathf.Max(1, Screen.width), h = Mathf.Max(1, Screen.height);
            rt.anchorMin = new Vector2(sa.xMin / w, sa.yMin / h);
            rt.anchorMax = new Vector2(sa.xMax / w, sa.yMax / h);
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        static void Pad(RectTransform rt, float l, float t, float r, float b)
        {
            rt.offsetMin = new Vector2(l, b);
            rt.offsetMax = new Vector2(-r, -t);
        }

        public void ShowHud(bool on) => hud.gameObject.SetActive(on);

        public void Refresh(SaveData save, DayPhase phase)
        {
            if (save == null) return;
            var kin = save.Kin;
            var psyche = save.Psyche;
            kinName.text = kin.Name;
            kinTitle.text = $"{kin.Def.TitleFor(kin.Stage)} · {Catalog.NatureLabel(kin.Nature)}";
            RefreshEmotions(psyche, kin.Stage);
            UiKit.SetBar(bars["Satiation"], kin.Satiation / 100f, BarW - 14);
            UiKit.SetBar(bars["Energy"], kin.Energy / 100f, BarW - 14);
            UiKit.SetBar(bars["Coat"], kin.Coat / 100f, BarW - 14);
            UiKit.SetBar(bars["Joy"], kin.Joy / 100f, BarW - 14);
            phaseText.text = phase.ToString();
            gleamText.text = $"{save.Gleam} gleam";
        }

        // ---- Emotion panel ---------------------------------------------------------------

        Text emotionHead, growthText;
        Image growthFill;
        readonly Image[] emotionFills = new Image[Psyche.Count];
        const float EmoW = 130;

        void BuildEmotions()
        {
            var card = UiKit.Rect("Feelings", hud, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(28, -326), new Vector2(470, 300));
            UiKit.Panel(card, UiKit.Cream);
            emotionHead = UiKit.Label(card, "", 34, UiKit.Ink, TextAnchor.UpperLeft, true);
            emotionHead.supportRichText = true;
            Pad(emotionHead.rectTransform, 26, 14, 20, 0);
            for (int i = 0; i < Psyche.Count; i++)
            {
                var e = (Emotion)i;
                int col = i % 3, row = i / 3;
                float x = 22 + col * 148, y = -64 - row * 56;
                var lbl = UiKit.Rect("E" + i, card, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(x, y), new Vector2(EmoW, 24));
                UiKit.Label(lbl, Psyche.Word(e), 20, new Color(0.45f, 0.38f, 0.48f));
                emotionFills[i] = UiKit.Bar(card, "Bar" + i, new Vector2(x, y - 24), new Vector2(EmoW, 18), Psyche.Colour(e), out _);
            }
            var g = UiKit.Rect("GrowthLabel", card, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(22, -232), new Vector2(430, 26));
            growthText = UiKit.Label(g, "", 22, new Color(0.45f, 0.38f, 0.48f));
            growthFill = UiKit.Bar(card, "Growth", new Vector2(22, -258), new Vector2(426, 22), UiKit.Gold, out _);
        }

        void RefreshEmotions(Psyche p, int stage)
        {
            if (p == null || emotionHead == null) return;
            var dom = p.Dominant;
            string hex = ColorUtility.ToHtmlStringRGB(Psyche.Colour(dom) * 0.8f);
            emotionHead.text = $"Feeling <color=#{hex}>{Psyche.Word(dom)}</color>";
            for (int i = 0; i < Psyche.Count; i++) UiKit.SetBar(emotionFills[i], p.E[i], EmoW);
            growthText.text = stage >= 2 ? "Fully grown" : $"Growth toward next form {p.GrowthToNext(stage) * 100:0}%" + (p.GrowthToNext(stage) >= 1 && !p.ReadyFor(stage) ? " (needs more trust/calm)" : "");
            UiKit.SetBar(growthFill, p.GrowthToNext(stage), 426);
        }

        public void SetPrompt(string text)
        {
            promptText.transform.parent.gameObject.SetActive(!string.IsNullOrEmpty(text));
            promptText.text = text;
        }

        // ---- Bubbles over the kin ------------------------------------------------------

        void BuildBubbles()
        {
            bidBubble = UiKit.Rect("Bid", root, Vector2.zero, Vector2.zero, new Vector2(0.5f, 0), Vector2.zero, new Vector2(220, 86));
            UiKit.Panel(bidBubble, Color.white);
            bidText = UiKit.Label(bidBubble, "", 36, UiKit.Ink, TextAnchor.MiddleCenter, true);
            thoughtBubble = UiKit.Rect("Thought", root, Vector2.zero, Vector2.zero, new Vector2(0.5f, 0), Vector2.zero, new Vector2(170, 70));
            UiKit.Panel(thoughtBubble, new Color(1, 1, 1, 0.75f), false);
            thoughtText = UiKit.Label(thoughtBubble, "", 30, new Color(0.4f, 0.34f, 0.44f), TextAnchor.MiddleCenter, true);
            bidBubble.gameObject.SetActive(false);
            thoughtBubble.gameObject.SetActive(false);
        }

        public static string BidWord(string bid) => bid switch
        {
            "meal" => "Food?", "play" => "Play!", "brush" => "Brush?", "nap" => "Sleepy…", "trick" => "Watch!", "wander" => "Walk?", _ => "…",
        };

        static string ThoughtWord(string t) => t switch
        {
            "berry" => "berries…", "heart" => "friends!", "zzz" => "Zzz", "note" => "la-la!", "ball" => "play?", "?" => "?", _ => t,
        };

        public void SetBubbles(Transform target, string bid, string thought)
        {
            bubbleTarget = target;
            bidBubble.gameObject.SetActive(!string.IsNullOrEmpty(bid) && hud.gameObject.activeSelf);
            if (!string.IsNullOrEmpty(bid)) bidText.text = BidWord(bid);
            bool showThought = string.IsNullOrEmpty(bid) && !string.IsNullOrEmpty(thought) && hud.gameObject.activeSelf;
            thoughtBubble.gameObject.SetActive(showThought);
            if (showThought) thoughtText.text = ThoughtWord(thought);
        }

        void LateUpdate()
        {
            if (bubbleTarget && Cam)
            {
                var sp = Cam.WorldToScreenPoint(bubbleTarget.position + Vector3.up * 1.4f);
                float bob = Mathf.Sin(Time.time * 3f) * 8;
                RectTransformUtility.ScreenPointToLocalPointInRectangle(root, sp, null, out var local);
                var anchored = local + root.rect.size * 0.5f;
                bidBubble.anchoredPosition = anchored + new Vector2(0, bob);
                thoughtBubble.anchoredPosition = anchored + new Vector2(0, bob * 0.5f);
            }
            if (typing)
            {
                typed += Time.unscaledDeltaTime * 48;
                int n = Mathf.Min(fullLine.Length, (int)typed);
                dialogText.text = fullLine.Substring(0, n);
                if (n >= fullLine.Length) typing = false;
                if (n % 3 == 0 && n > 0 && n < fullLine.Length) ProcAudio.I?.Play("blip", 0.12f, 1.4f);
            }
        }

        // ---- Dialogue ------------------------------------------------------------------

        void BuildDialog()
        {
            dialog = UiKit.Rect("Dialog", root, new Vector2(0, 0), new Vector2(1, 0), new Vector2(0.5f, 0), new Vector2(0, 40), new Vector2(-60, 330));
            UiKit.Panel(dialog, UiKit.Cream);
            var border = UiKit.Stretch("Border", dialog, 12);
            var bi = UiKit.Panel(border, new Color(0, 0, 0, 0), false);
            bi.raycastTarget = false;
            var outline = border.gameObject.AddComponent<Outline>();
            outline.effectColor = new Color(0.98f, 0.76f, 0.3f, 0.7f);
            outline.effectDistance = new Vector2(3, 3);
            dialogText = UiKit.Label(dialog, "", 44, UiKit.Ink, TextAnchor.UpperLeft);
            Pad(dialogText.rectTransform, 50, 80, 50, 30);
            var nameTag = UiKit.Rect("Name", dialog, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 0.5f), new Vector2(40, 0), new Vector2(300, 74));
            UiKit.Panel(nameTag, UiKit.Gold);
            dialogName = UiKit.Label(nameTag, "", 36, UiKit.Ink, TextAnchor.MiddleCenter, true);
            var tap = dialog.gameObject.AddComponent<Button>();
            tap.onClick.AddListener(AdvanceDialog);
            dialog.gameObject.SetActive(false);
        }

        public void Say(string who, string line, Action done = null) => Say(new[] { (who, line) }, done);

        public void Say(IEnumerable<(string who, string line)> seq, Action done = null)
        {
            foreach (var l in seq) lines.Enqueue(l);
            onDialogDone = done ?? onDialogDone;
            if (!DialogOpen) NextLine();
        }

        void NextLine()
        {
            if (lines.Count == 0)
            {
                dialog.gameObject.SetActive(false);
                var d = onDialogDone;
                onDialogDone = null;
                d?.Invoke();
                return;
            }
            var (who, line) = lines.Dequeue();
            dialog.gameObject.SetActive(true);
            dialogName.transform.parent.gameObject.SetActive(!string.IsNullOrEmpty(who));
            dialogName.text = who;
            fullLine = line;
            typed = 0;
            typing = true;
        }

        public void AdvanceDialog()
        {
            if (!DialogOpen) return;
            if (typing) { typing = false; dialogText.text = fullLine; return; }
            NextLine();
        }

        // ---- Choices -------------------------------------------------------------------

        void BuildChoices()
        {
            choices = UiKit.Stretch("Choices", root);
            var dim = choices.gameObject.AddComponent<Image>();
            dim.color = UiKit.Shade;
            choices.gameObject.SetActive(false);
        }

        public void Choose(string heading, IList<Choice> options, Action onCancel = null)
        {
            foreach (Transform c in choices) Destroy(c.gameObject);
            choices.gameObject.SetActive(true);
            float h = 150 + options.Count * 132 + (onCancel != null ? 132 : 0);
            var panel = UiKit.Rect("Panel", choices, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0, -120), new Vector2(820, h));
            UiKit.Panel(panel, UiKit.Cream);
            var head = UiKit.Label(panel, heading, 48, UiKit.Ink, TextAnchor.UpperCenter, true);
            Pad(head.rectTransform, 20, 36, 20, 0);
            float y = h / 2 - 160;
            foreach (var opt in options)
            {
                var o = opt;
                string text = string.IsNullOrEmpty(o.Sub) ? o.Label : $"{o.Label}  <size=28><color=#7a6a80>{o.Sub}</color></size>";
                var b = UiKit.Button(panel, text, new Vector2(0, y), new Vector2(720, 112), o.Enabled ? Color.white : new Color(0.9f, 0.88f, 0.86f), () =>
                {
                    choices.gameObject.SetActive(false);
                    o.Act?.Invoke();
                }, 38);
                b.GetComponentInChildren<Text>().supportRichText = true;
                b.interactable = o.Enabled;
                y -= 132;
            }
            if (onCancel != null)
                UiKit.Button(panel, "Back", new Vector2(0, y), new Vector2(720, 100), new Color(0.92f, 0.88f, 0.94f), () =>
                {
                    choices.gameObject.SetActive(false);
                    ProcAudio.I?.Play("cancel");
                    onCancel();
                }, 36);
        }

        public void CloseChoices() => choices.gameObject.SetActive(false);

        // ---- Toast and meter -----------------------------------------------------------

        void BuildToast()
        {
            toast = UiKit.Rect("Toast", root, new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0, -360), new Vector2(900, 110));
            UiKit.Panel(toast, new Color(0.22f, 0.18f, 0.26f, 0.88f));
            toastText = UiKit.Label(toast, "", 34, Color.white, TextAnchor.MiddleCenter);
            Pad(toastText.rectTransform, 30, 10, 30, 10);
            toast.gameObject.SetActive(false);
        }

        Coroutine toastRoutine;

        public void Toast(string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            if (toastRoutine != null) StopCoroutine(toastRoutine);
            toastRoutine = StartCoroutine(ToastRoutine(text));
        }

        IEnumerator ToastRoutine(string text)
        {
            toast.gameObject.SetActive(true);
            toastText.text = text;
            if (!toast.TryGetComponent<CanvasGroup>(out var cg)) cg = toast.gameObject.AddComponent<CanvasGroup>();
            cg.blocksRaycasts = false;
            for (float t = 0; t < 1; t += Time.unscaledDeltaTime * 6) { cg.alpha = t; toast.anchoredPosition = new Vector2(0, -330 - (1 - t) * 30); yield return null; }
            cg.alpha = 1;
            yield return new WaitForSecondsRealtime(Mathf.Clamp(text.Length * 0.05f, 2f, 4.5f));
            for (float t = 1; t > 0; t -= Time.unscaledDeltaTime * 4) { cg.alpha = t; yield return null; }
            toast.gameObject.SetActive(false);
        }

        void BuildMeter()
        {
            meter = UiKit.Rect("Meter", root, new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0, -480), new Vector2(700, 130));
            UiKit.Panel(meter, UiKit.Cream);
            meterLabel = UiKit.Label(meter, "", 34, UiKit.Ink, TextAnchor.UpperCenter, true);
            Pad(meterLabel.rectTransform, 10, 12, 10, 0);
            meterFill = UiKit.Bar(meter, "Bar", new Vector2(40, -70), new Vector2(620, 38), UiKit.Gold, out _);
            meter.gameObject.SetActive(false);
        }

        public void Meter(string label, float value01)
        {
            meter.gameObject.SetActive(label != null);
            if (label == null) return;
            meterLabel.text = label;
            UiKit.SetBar(meterFill, value01, 620);
        }

        public IEnumerator Fade(float to, float seconds)
        {
            fade.raycastTarget = to > 0.5f;
            float from = fade.color.a;
            for (float t = 0; t < 1; t += Time.unscaledDeltaTime / Mathf.Max(0.01f, seconds))
            {
                var c = fade.color;
                c.a = Mathf.Lerp(from, to, Mathf.SmoothStep(0, 1, t));
                fade.color = c;
                yield return null;
            }
            var e = fade.color;
            e.a = to;
            fade.color = e;
        }

        public void FlashWhite(float alpha)
        {
            var c = fade.color;
            c.a = alpha;
            fade.color = c;
        }

        // ---- Battle --------------------------------------------------------------------

        RectTransform selfCard, foeCard, moveRow;
        Text selfLabel, foeLabel, battleLog;
        Image selfHp, foeHp;
        readonly List<Button> moveButtons = new();

        void BuildBattle()
        {
            battle = UiKit.Stretch("Battle", root);
            foeCard = UiKit.Rect("Foe", battle, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(40, -120), new Vector2(560, 150));
            UiKit.Panel(foeCard, UiKit.Cream);
            foeLabel = UiKit.Label(foeCard, "", 38, UiKit.Ink, TextAnchor.UpperLeft, true);
            Pad(foeLabel.rectTransform, 28, 18, 20, 0);
            foeHp = UiKit.Bar(foeCard, "HP", new Vector2(28, -88), new Vector2(500, 32), new Color(0.5f, 0.85f, 0.45f), out _);
            selfCard = UiKit.Rect("Self", battle, new Vector2(1, 0), new Vector2(1, 0), new Vector2(1, 0), new Vector2(-40, 820), new Vector2(560, 150));
            UiKit.Panel(selfCard, UiKit.Cream);
            selfLabel = UiKit.Label(selfCard, "", 38, UiKit.Ink, TextAnchor.UpperLeft, true);
            Pad(selfLabel.rectTransform, 28, 18, 20, 0);
            selfHp = UiKit.Bar(selfCard, "HP", new Vector2(28, -88), new Vector2(500, 32), new Color(0.5f, 0.85f, 0.45f), out _);
            var log = UiKit.Rect("Log", battle, new Vector2(0, 0), new Vector2(1, 0), new Vector2(0.5f, 0), new Vector2(0, 560), new Vector2(-60, 220));
            UiKit.Panel(log, UiKit.Cream);
            battleLog = UiKit.Label(log, "", 38, UiKit.Ink, TextAnchor.MiddleLeft);
            Pad(battleLog.rectTransform, 44, 20, 44, 20);
            moveRow = UiKit.Rect("Moves", battle, new Vector2(0, 0), new Vector2(1, 0), new Vector2(0.5f, 0), new Vector2(0, 60), new Vector2(0, 460));
            battle.gameObject.SetActive(false);
        }

        public void ShowBattle(bool on)
        {
            battle.gameObject.SetActive(on);
            hud.gameObject.SetActive(!on);
        }

        public void SetBattle(string self, float selfFrac, string foe, float foeFrac, string log)
        {
            selfLabel.text = self;
            foeLabel.text = foe;
            UiKit.SetBar(selfHp, selfFrac, 500);
            UiKit.SetBar(foeHp, foeFrac, 500);
            selfHp.color = selfFrac < 0.3f ? new Color(1f, 0.45f, 0.4f) : selfFrac < 0.6f ? new Color(1f, 0.8f, 0.35f) : new Color(0.5f, 0.85f, 0.45f);
            foeHp.color = foeFrac < 0.3f ? new Color(1f, 0.45f, 0.4f) : foeFrac < 0.6f ? new Color(1f, 0.8f, 0.35f) : new Color(0.5f, 0.85f, 0.45f);
            battleLog.text = log;
        }

        public void SetMoves(MoveDef[] moves, int suggested, Action<int> pick)
        {
            foreach (Transform c in moveRow) Destroy(c.gameObject);
            moveButtons.Clear();
            if (moves == null) return;
            for (int i = 0; i < moves.Length; i++)
            {
                int idx = i;
                var m = moves[i];
                var col = Color.Lerp(Catalog.ElementColor(m.Element), Color.white, 0.55f);
                string tag = m.IsGuard ? "Guard" : m.IsRally ? $"Rally · {m.Power}" : $"Strike · {m.Power}";
                string eager = i == suggested ? "  <color=#c0782a>(eager!)</color>" : "";
                var b = UiKit.Button(moveRow, $"{m.Name}{eager}\n<size=26><color=#6a5a70>{tag}</color></size>", new Vector2(0, 360 - i * 140), new Vector2(940, 124), col, () => pick(idx), 38, new Vector2(0.5f, 0));
                b.GetComponentInChildren<Text>().supportRichText = true;
                moveButtons.Add(b);
            }
        }

        // ---- Title / naming ------------------------------------------------------------

        public void ShowTitle(bool hasSave, Action onContinue, Action onNew)
        {
            foreach (Transform c in title) Destroy(c.gameObject);
            title.gameObject.SetActive(true);
            hud.gameObject.SetActive(false);
            var logo = UiKit.Rect("Logo", title, new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0, -260), new Vector2(1000, 260));
            var t = UiKit.Label(logo, "Lumina Vale", 132, Color.white, TextAnchor.MiddleCenter, true);
            var o = t.gameObject.AddComponent<Outline>();
            o.effectColor = new Color(0.36f, 0.22f, 0.4f, 0.9f);
            o.effectDistance = new Vector2(5, -5);
            var sub = UiKit.Rect("Sub", title, new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(0, -500), new Vector2(1000, 80));
            var st = UiKit.Label(sub, "raise a kin that learns the shape of your days", 38, Color.white, TextAnchor.MiddleCenter);
            st.gameObject.AddComponent<Shadow>().effectColor = new Color(0.2f, 0.1f, 0.3f, 0.6f);
            float y = 380;
            if (hasSave) { UiKit.Button(title, "Continue", new Vector2(0, y), new Vector2(620, 140), UiKit.Gold, () => { title.gameObject.SetActive(false); onContinue(); }, 54, new Vector2(0.5f, 0)); y -= 170; }
            UiKit.Button(title, hasSave ? "New journey" : "Begin", new Vector2(0, y), new Vector2(620, 140), hasSave ? UiKit.Cream : UiKit.Gold, () => { title.gameObject.SetActive(false); onNew(); }, 54, new Vector2(0.5f, 0));
        }

        public void AskName(string prompt, string initial, Action<string> done)
        {
            foreach (Transform c in title) Destroy(c.gameObject);
            title.gameObject.SetActive(true);
            if (!title.TryGetComponent<Image>(out var dim)) dim = title.gameObject.AddComponent<Image>();
            dim.color = UiKit.Shade;
            var panel = UiKit.Rect("Panel", title, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0, 200), new Vector2(860, 460));
            UiKit.Panel(panel, UiKit.Cream);
            var head = UiKit.Label(panel, prompt, 46, UiKit.Ink, TextAnchor.UpperCenter, true);
            Pad(head.rectTransform, 30, 40, 30, 0);
            var fieldRt = UiKit.Rect("Field", panel, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0, 10), new Vector2(700, 110));
            var bg = UiKit.Panel(fieldRt, Color.white, false);
            var field = fieldRt.gameObject.AddComponent<InputField>();
            field.targetGraphic = bg;
            var text = UiKit.Label(fieldRt, "", 48, UiKit.Ink, TextAnchor.MiddleCenter, true);
            text.supportRichText = false;
            field.textComponent = text;
            field.characterLimit = 12;
            field.text = initial;
            UiKit.Button(panel, "OK", new Vector2(0, -150), new Vector2(360, 110), UiKit.Gold, () =>
            {
                string v = string.IsNullOrWhiteSpace(field.text) ? initial : field.text.Trim();
                dim.color = new Color(0, 0, 0, 0);
                title.gameObject.SetActive(false);
                done(v);
            }, 46);
        }

        public void StarterPicker(Action<int> onChange, Action onPick)
        {
            foreach (Transform c in title) Destroy(c.gameObject);
            title.gameObject.SetActive(true);
            var dim = title.gameObject.GetComponent<Image>();
            if (dim) dim.color = new Color(0, 0, 0, 0);
            int index = 0;
            UiKit.Button(title, "<", new Vector2(110, 0), new Vector2(150, 150), UiKit.Cream, () => { index = (index + 2) % 3; onChange(index); }, 80, new Vector2(0, 0.5f)).GetComponent<Image>().sprite = UiKit.Circle;
            UiKit.Button(title, ">", new Vector2(-110, 0), new Vector2(150, 150), UiKit.Cream, () => { index = (index + 1) % 3; onChange(index); }, 80, new Vector2(1, 0.5f)).GetComponent<Image>().sprite = UiKit.Circle;
            UiKit.Button(title, "Choose this kin", new Vector2(0, 160), new Vector2(640, 140), UiKit.Gold, () => { title.gameObject.SetActive(false); onPick(); }, 50, new Vector2(0.5f, 0));
            onChange(0);
        }

        // ---- Journal -------------------------------------------------------------------

        public void ShowJournal(SaveData save, Action close)
        {
            foreach (Transform c in choices) Destroy(c.gameObject);
            choices.gameObject.SetActive(true);
            var panel = UiKit.Rect("Journal", choices, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(960, 1500));
            UiKit.Panel(panel, UiKit.Cream);
            var kin = save.Kin;
            var sb = new System.Text.StringBuilder();
            sb.AppendLine($"<size=56>{kin.Name}'s journal</size>");
            var ps = save.Psyche;
            sb.AppendLine($"{kin.Def.TitleFor(kin.Stage)} · Bond {kin.Bond:0} · {kin.DaysTogether} days together · {ps.Wins}W/{ps.Losses}L");
            sb.AppendLine();
            sb.AppendLine("<b>How it feels</b>  (now / temperament)");
            foreach (var e in Psyche.All)
                sb.AppendLine($"  {Psyche.Word(e),-12} {ps[e] * 100:0} / {ps.Temperament[(int)e] * 100:0}");
            sb.AppendLine();
            sb.AppendLine("<b>Growth</b> (credit earned by learning, not XP)");
            foreach (var kv in ps.Banks)
                sb.AppendLine($"  {kv.Key,-10} credit {kv.Value.Credit:0.0} · competence {kv.Value.Competence * 100:0}%");
            sb.AppendLine($"  feeding rhythm it expects: every {ps.Feeding.MeanHours:0.0} h (you are {ps.Feeding.Regularity * 100:0}% regular)");
            sb.AppendLine($"  obeys you in battle about {ps.Obedience * 100:0}% of the time");
            sb.AppendLine();
            sb.AppendLine("<b>What it has learned about you</b>");
            for (int h = 6; h <= 22; h += 4)
            {
                var a = save.Routine.Anticipate(h);
                if (a != null) sb.AppendLine($"  around {h:00}:00 it expects you to <b>{a}</b>");
            }
            if (save.Routine.Total < 4) sb.AppendLine("  (still watching your routine…)");
            string favFood = "", favGame = "";
            float bf = -1, bg = -1;
            foreach (var kv in kin.FoodLove) if (kv.Value > bf) { bf = kv.Value; favFood = kv.Key; }
            foreach (var kv in kin.GameLove) if (kv.Value > bg) { bg = kv.Value; favGame = kv.Key; }
            if (favFood != "") sb.AppendLine($"  favourite food: <b>{Catalog.Food(favFood).Name}</b>");
            if (favGame != "") sb.AppendLine($"  favourite game: <b>{favGame}</b>");
            sb.AppendLine($"  places it has learned about: {save.SpatialQ.Count}");
            sb.AppendLine();
            sb.AppendLine("<b>Memories</b>");
            for (int i = 0; i < Mathf.Min(12, save.Memories.Count); i++)
                sb.AppendLine($"<size=28><color=#8a7a90>{save.Memories[i].At:MMM d, HH:mm}</color></size>  {save.Memories[i].Text}");
            var text = UiKit.Label(panel, sb.ToString(), 32, UiKit.Ink, TextAnchor.UpperLeft);
            text.supportRichText = true;
            Pad(text.rectTransform, 50, 50, 50, 170);
            UiKit.Button(panel, "Close", new Vector2(0, 90), new Vector2(400, 110), UiKit.Gold, () => { choices.gameObject.SetActive(false); close(); }, 44, new Vector2(0.5f, 0));
        }
    }
}
