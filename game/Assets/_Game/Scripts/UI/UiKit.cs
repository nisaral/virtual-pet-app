using System;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace LuminaVale
{
    /// Code-built uGUI widgets in the game's style: cream rounded panels, deep ink text,
    /// gold accents. Keeps the project free of hand-edited prefabs.
    public static class UiKit
    {
        public static readonly Color Cream = new(1f, 0.97f, 0.9f, 0.97f);
        public static readonly Color Ink = new(0.2f, 0.16f, 0.22f);
        public static readonly Color Gold = new(0.98f, 0.76f, 0.3f);
        public static readonly Color Teal = new(0.3f, 0.7f, 0.72f);
        public static readonly Color Shade = new(0.1f, 0.08f, 0.14f, 0.55f);

        static Sprite round, circle;
        static Font display, body;

        public static Font Display => display ??= Resources.Load<Font>("Fonts/Fredoka-SemiBold") ?? Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        public static Font Body => body ??= Resources.Load<Font>("Fonts/Nunito-Bold") ?? Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

        public static Sprite Round => round ??= MakeRound(64, 26);
        public static Sprite Circle => circle ??= MakeRound(64, 32);

        static Sprite MakeRound(int size, int radius)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            var px = new Color32[size * size];
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float cx = Mathf.Clamp(x + 0.5f, radius, size - radius);
                float cy = Mathf.Clamp(y + 0.5f, radius, size - radius);
                float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy));
                byte a = (byte)(Mathf.Clamp01(radius - d + 0.5f) * 255);
                px[y * size + x] = new Color32(255, 255, 255, a);
            }
            tex.SetPixels32(px);
            tex.Apply();
            float border = Mathf.Min(radius, size / 2 - 1);
            return Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100, 0, SpriteMeshType.FullRect, new Vector4(border, border, border, border));
        }

        public static Canvas Canvas(string name, int order)
        {
            var go = new GameObject(name, typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var c = go.GetComponent<Canvas>();
            c.renderMode = RenderMode.ScreenSpaceOverlay;
            c.sortingOrder = order;
            var s = go.GetComponent<CanvasScaler>();
            s.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            s.referenceResolution = new Vector2(1080, 1920);
            s.matchWidthOrHeight = 1f;
            s.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            return c;
        }

        public static void EnsureEventSystem()
        {
            if (UnityEngine.Object.FindFirstObjectByType<EventSystem>()) return;
            var es = new GameObject("EventSystem", typeof(EventSystem));
#if ENABLE_INPUT_SYSTEM
            es.AddComponent<UnityEngine.InputSystem.UI.InputSystemUIInputModule>();
#else
            es.AddComponent<StandaloneInputModule>();
#endif
        }

        public static RectTransform Rect(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 pivot, Vector2 pos, Vector2 size)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = go.GetComponent<RectTransform>();
            rt.SetParent(parent, false);
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.pivot = pivot;
            rt.anchoredPosition = pos;
            rt.sizeDelta = size;
            return rt;
        }

        public static RectTransform Stretch(string name, Transform parent, float inset = 0)
        {
            var rt = Rect(name, parent, Vector2.zero, Vector2.one, new Vector2(0.5f, 0.5f), Vector2.zero, Vector2.zero);
            rt.offsetMin = new Vector2(inset, inset);
            rt.offsetMax = new Vector2(-inset, -inset);
            return rt;
        }

        public static Image Panel(RectTransform rt, Color color, bool shadow = true, Sprite sprite = null)
        {
            var img = rt.gameObject.AddComponent<Image>();
            img.sprite = sprite ?? Round;
            img.type = Image.Type.Sliced;
            img.color = color;
            if (shadow)
            {
                var sh = rt.gameObject.AddComponent<Shadow>();
                sh.effectColor = new Color(0.12f, 0.08f, 0.16f, 0.3f);
                sh.effectDistance = new Vector2(3, -9);
            }
            return img;
        }

        public static Text Label(Transform parent, string text, int size, Color color, TextAnchor anchor = TextAnchor.MiddleLeft, bool display = false)
        {
            var rt = Stretch("Label", parent);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = display ? Display : Body;
            t.text = text;
            t.fontSize = size;
            t.color = color;
            t.alignment = anchor;
            t.horizontalOverflow = HorizontalWrapMode.Wrap;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            t.raycastTarget = false;
            return t;
        }

        public static Button Button(Transform parent, string text, Vector2 pos, Vector2 size, Color color, Action onClick, int fontSize = 40, Vector2? anchor = null)
        {
            var a = anchor ?? new Vector2(0.5f, 0.5f);
            var rt = Rect("Btn_" + text, parent, a, a, new Vector2(0.5f, 0.5f), pos, size);
            var img = Panel(rt, color);
            var b = rt.gameObject.AddComponent<Button>();
            b.targetGraphic = img;
            var cb = b.colors;
            cb.highlightedColor = new Color(1, 1, 1, 1);
            cb.pressedColor = new Color(0.85f, 0.85f, 0.85f, 1);
            cb.fadeDuration = 0.06f;
            b.colors = cb;
            var label = Label(rt, text, fontSize, Ink, TextAnchor.MiddleCenter, true);
            label.name = "Text";
            b.onClick.AddListener(new UnityAction(() => { ProcAudio.I?.Play("blip"); onClick?.Invoke(); }));
            rt.gameObject.AddComponent<PressBounce>();
            return b;
        }

        public static Image Bar(Transform parent, string name, Vector2 pos, Vector2 size, Color fill, out Image back)
        {
            var rt = Rect(name, parent, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), pos, size);
            back = Panel(rt, new Color(0.2f, 0.16f, 0.22f, 0.18f), false);
            var f = Rect("Fill", rt, new Vector2(0, 0), new Vector2(0, 1), new Vector2(0, 0.5f), Vector2.zero, new Vector2(size.x, 0));
            f.offsetMin = new Vector2(3, 3);
            f.offsetMax = new Vector2(size.x - 3, -3);
            var img = Panel(f, fill, false);
            return img;
        }

        public static void SetBar(Image fill, float value01, float width)
        {
            var rt = (RectTransform)fill.transform;
            rt.offsetMax = new Vector2(3 + Mathf.Clamp01(value01) * (width - 6) - 0, -3);
            rt.offsetMin = new Vector2(3, 3);
        }
    }

    /// Little squash on press, for that toy-like feel.
    public sealed class PressBounce : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        float target = 1, scale = 1;
        public void OnPointerDown(PointerEventData e) => target = 0.92f;
        public void OnPointerUp(PointerEventData e) => target = 1.04f;

        void Update()
        {
            scale = Mathf.Lerp(scale, target, 1 - Mathf.Exp(-Time.unscaledDeltaTime * 22));
            if (Mathf.Abs(target - 1.04f) < 0.001f && Mathf.Abs(scale - 1.04f) < 0.01f) target = 1;
            transform.localScale = Vector3.one * scale;
        }
    }

    /// Floating on-screen stick (bottom-left). Writes GameInput.Stick.
    public sealed class VirtualJoystick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public RectTransform Knob, Ring;
        Vector2 origin;
        const float Radius = 120;

        public void OnPointerDown(PointerEventData e)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle((RectTransform)transform, e.position, e.pressEventCamera, out origin);
            Ring.anchoredPosition = origin;
            Knob.anchoredPosition = origin;
            Ring.gameObject.SetActive(true);
            OnDrag(e);
        }

        public void OnDrag(PointerEventData e)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle((RectTransform)transform, e.position, e.pressEventCamera, out var p);
            var d = Vector2.ClampMagnitude(p - origin, Radius);
            Knob.anchoredPosition = origin + d;
            GameInput.Stick = d / Radius;
        }

        public void OnPointerUp(PointerEventData e)
        {
            GameInput.Stick = Vector2.zero;
            Knob.anchoredPosition = origin;
            Ring.gameObject.SetActive(false);
        }
    }
}
