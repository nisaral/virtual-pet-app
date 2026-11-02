using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace LuminaVale
{
    /// One place that merges keyboard, gamepad and the on-screen pad.
    public static class GameInput
    {
        public static Vector2 Stick;          // written by VirtualJoystick
        static bool uiA, uiMenu, uiMap;
        public static void PressA() => uiA = true;
        public static void PressMenu() => uiMenu = true;
        public static void PressMap() => uiMap = true;
        public static bool Locked;           // menus, battle, cutscenes

        public static Vector2 Move
        {
            get
            {
                if (Locked) return Vector2.zero;
                Vector2 v = Stick;
#if ENABLE_INPUT_SYSTEM
                var k = Keyboard.current;
                if (k != null)
                {
                    if (k.wKey.isPressed || k.upArrowKey.isPressed) v.y += 1;
                    if (k.sKey.isPressed || k.downArrowKey.isPressed) v.y -= 1;
                    if (k.aKey.isPressed || k.leftArrowKey.isPressed) v.x -= 1;
                    if (k.dKey.isPressed || k.rightArrowKey.isPressed) v.x += 1;
                }
                var g = Gamepad.current;
                if (g != null) v += g.leftStick.ReadValue();
#else
                v += new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
#endif
                return Vector2.ClampMagnitude(v, 1f);
            }
        }

        public static bool Run
        {
            get
            {
#if ENABLE_INPUT_SYSTEM
                if (Keyboard.current != null && Keyboard.current.leftShiftKey.isPressed) return true;
                if (Gamepad.current != null && Gamepad.current.buttonEast.isPressed) return true;
#else
                if (Input.GetKey(KeyCode.LeftShift)) return true;
#endif
                return Stick.magnitude > 0.92f;
            }
        }

        public static bool ConsumeA()
        {
            bool hit = uiA;
            uiA = false;
#if ENABLE_INPUT_SYSTEM
            if (Keyboard.current != null && (Keyboard.current.spaceKey.wasPressedThisFrame || Keyboard.current.enterKey.wasPressedThisFrame || Keyboard.current.eKey.wasPressedThisFrame)) hit = true;
            if (Gamepad.current != null && Gamepad.current.buttonSouth.wasPressedThisFrame) hit = true;
#else
            if (Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.E)) hit = true;
#endif
            return hit;
        }

        public static bool ConsumeMap()
        {
            bool hit = uiMap;
            uiMap = false;
            return hit;
        }

        public static bool ConsumeMenu()
        {
            bool hit = uiMenu;
            uiMenu = false;
#if ENABLE_INPUT_SYSTEM
            if (Keyboard.current != null && (Keyboard.current.escapeKey.wasPressedThisFrame || Keyboard.current.tabKey.wasPressedThisFrame)) hit = true;
            if (Gamepad.current != null && Gamepad.current.startButton.wasPressedThisFrame) hit = true;
#else
            if (Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.Tab)) hit = true;
#endif
            return hit;
        }
    }

    /// The fixed 2.5D camera: locked yaw, narrow lens, steep pitch, soft follow.
    /// Framing can be pushed (close-ups, battle) and always eases back.
    public sealed class GridCamera : MonoBehaviour
    {
        public Transform Target;
        public Bounds Clamp;
        public float Pitch = 52f, Distance = 15.5f, Fov = 28f;
        public Vector3 Offset = new(0, 0.6f, 0);

        Camera cam;
        Vector3 focus, vel;
        float pitch, distance, fov;
        float shake;
        Vector3? overrideFocus;
        float overridePitch, overrideDistance, overrideFov, overrideYaw;
        bool hasOverride;

        public Camera Cam => cam;

        void Awake()
        {
            cam = GetComponent<Camera>();
            pitch = Pitch; distance = Distance; fov = Fov;
        }

        public void Snap()
        {
            if (Target) focus = Target.position + Offset;
            Apply(0, 0);
        }

        public void Push(Vector3 focusPoint, float p, float d, float f, float yaw = 0)
        {
            hasOverride = true;
            overrideFocus = focusPoint;
            overridePitch = p; overrideDistance = d; overrideFov = f; overrideYaw = yaw;
        }

        public void Release() { hasOverride = false; overrideFocus = null; }

        public void Shake(float amount) => shake = Mathf.Max(shake, amount);

        void LateUpdate()
        {
            float dt = Time.deltaTime;
            Vector3 want = hasOverride && overrideFocus.HasValue ? overrideFocus.Value : (Target ? Target.position + Offset : focus);
            if (!hasOverride && Clamp.size != Vector3.zero)
            {
                // Keep the map edge just off-screen: tighter clamp along Z because the view is tilted.
                want.x = Mathf.Clamp(want.x, Clamp.min.x + 6.5f, Clamp.max.x - 6.5f);
                want.z = Mathf.Clamp(want.z, Clamp.min.z + 2.5f, Clamp.max.z - 6f);
            }
            focus = Vector3.SmoothDamp(focus, want, ref vel, hasOverride ? 0.35f : 0.22f);
            float k = 1 - Mathf.Exp(-dt * 4f);
            pitch = Mathf.Lerp(pitch, hasOverride ? overridePitch : Pitch, k);
            distance = Mathf.Lerp(distance, hasOverride ? overrideDistance : Distance, k);
            fov = Mathf.Lerp(fov, hasOverride ? overrideFov : Fov, k);
            Apply(hasOverride ? overrideYaw : 0, dt);
        }

        float yawNow;

        void Apply(float yaw, float dt)
        {
            yawNow = dt <= 0 ? yaw : Mathf.LerpAngle(yawNow, yaw, 1 - Mathf.Exp(-dt * 4f));
            var rot = Quaternion.Euler(pitch, yawNow, 0);
            var pos = focus - rot * Vector3.forward * distance;
            if (shake > 0)
            {
                pos += Random.insideUnitSphere * shake * 0.12f;
                shake = Mathf.MoveTowards(shake, 0, dt * 3f);
            }
            transform.SetPositionAndRotation(pos, rot);
            if (cam) cam.fieldOfView = fov;
        }
    }

    /// The player avatar. 8-direction analog movement over the tile grid, with
    /// grid collision, stairs ramps and one-way ledge hops.
    public sealed class KeeperController : MonoBehaviour
    {
        public float WalkSpeed = 3.1f, RunSpeed = 5.2f, Radius = 0.28f;
        public ChibiCharacter Body;
        public bool Busy;
        public Bounds? Indoor;
        public Vector2Int Cell => GlenMap.ToCell(transform.position);
        public Vector3 Forward => transform.forward;
        public float Speed01 { get; private set; }
        public System.Action<Vector2Int> Stepped;

        Vector2Int lastCell;
        float stepTimer;

        public void Place(Vector2Int cell)
        {
            transform.position = GlenMap.ToWorld(cell);
            lastCell = cell;
        }

        void Update()
        {
            if (Busy) { Speed01 = Mathf.MoveTowards(Speed01, 0, Time.deltaTime * 6); if (Body) Body.Speed01 = Speed01; return; }
            var input = GameInput.Move;
            float mag = input.magnitude;
            var dir = new Vector3(input.x, 0, input.y);
            if (mag > 0.15f)
            {
                float speed = (GameInput.Run ? RunSpeed : WalkSpeed) * Mathf.Clamp01(mag * 1.2f);
                TryMove(dir.normalized * speed * Time.deltaTime);
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(dir), 1 - Mathf.Exp(-Time.deltaTime * 14f));
                Speed01 = Mathf.MoveTowards(Speed01, speed / RunSpeed, Time.deltaTime * 6);
            }
            else Speed01 = Mathf.MoveTowards(Speed01, 0, Time.deltaTime * 6);
            if (Body) Body.Speed01 = Speed01;

            var p = transform.position;
            float ground = Indoor.HasValue ? Indoor.Value.min.y : GlenMap.SurfaceAt(p);
            p.y = Mathf.Lerp(p.y, ground, 1 - Mathf.Exp(-Time.deltaTime * 18f));
            transform.position = p;

            if (Cell != lastCell)
            {
                lastCell = Cell;
                Stepped?.Invoke(Cell);
            }
            if (Speed01 > 0.1f)
            {
                stepTimer -= Time.deltaTime * (0.6f + Speed01);
                if (stepTimer <= 0) { stepTimer = 0.33f; ProcAudio.I?.Play("step", 0.25f, Random.Range(0.9f, 1.1f)); }
            }
        }

        void TryMove(Vector3 delta)
        {
            if (Indoor.HasValue)
            {
                var pos = transform.position + delta;
                var box = Indoor.Value;
                pos.x = Mathf.Clamp(pos.x, box.min.x, box.max.x);
                pos.z = Mathf.Clamp(pos.z, box.min.z, box.max.z);
                transform.position = pos;
                return;
            }
            var from = Cell;
            // Ledge hop: pushing south off a ledge edge.
            if (delta.z < -0.001f && GlenMap.At(from.x, from.y) == Tile.Ledge)
            {
                var below = from + Vector2Int.up; // grid y grows southward
                var localZ = transform.position.z - (GlenMap.Height - 1 - from.y);
                if (localZ < 0.35f && GlenMap.IsLedgeHop(from, below)) { StartCoroutine(Hop(below)); return; }
            }
            var p = transform.position;
            var tryX = p + new Vector3(delta.x, 0, 0);
            if (Free(tryX)) p = tryX;
            var tryZ = p + new Vector3(0, 0, delta.z);
            if (Free(tryZ)) p = tryZ;
            transform.position = p;
        }

        /// A point is free if every probe around the body sits on a cell we may step into.
        bool Free(Vector3 pos)
        {
            var from = Cell;
            for (int i = 0; i < 4; i++)
            {
                var probe = pos + new Vector3(i % 2 == 0 ? -Radius : Radius, 0, i < 2 ? -Radius * 0.6f : Radius * 0.6f);
                var c = GlenMap.ToCell(probe);
                if (c == from) continue;
                if (!GlenMap.CanStep(from, c) || GlenMap.IsLedgeHop(from, c)) return false;
            }
            var center = GlenMap.ToCell(pos);
            if (center != from && (!GlenMap.CanStep(from, center) || GlenMap.IsLedgeHop(from, center))) return false;
            return !Physics.CheckSphere(pos + Vector3.up * 0.5f, Radius * 0.8f, 1 << 8);
        }

        IEnumerator Hop(Vector2Int to)
        {
            Busy = true;
            var start = transform.position;
            var end = GlenMap.ToWorld(to);
            transform.rotation = Quaternion.LookRotation(Vector3.back);
            ProcAudio.I?.Play("hop", 0.5f);
            for (float t = 0; t < 1; t += Time.deltaTime / 0.42f)
            {
                var p = Vector3.Lerp(start, end, t);
                p.y = Mathf.Lerp(start.y, end.y, t) + Mathf.Sin(t * Mathf.PI) * 0.7f;
                transform.position = p;
                yield return null;
            }
            transform.position = end;
            ProcAudio.I?.Play("land", 0.5f);
            Busy = false;
        }
    }

    /// Follows a list of cells smoothly; used by the kin and villagers.
    public sealed class PathMover
    {
        public readonly List<Vector2Int> Path = new();
        public float Speed = 2.6f;
        public bool Moving => Path.Count > 0;
        public bool Hopping { get; private set; }
        float hopT;
        Vector3 hopFrom, hopTo;

        public void SetPath(Vector2Int from, Vector2Int to)
        {
            Path.Clear();
            Path.AddRange(GlenMap.FindPath(from, to));
        }

        public void Stop() => Path.Clear();

        /// Returns the facing direction this frame (zero when idle).
        public Vector3 Tick(Transform t, float dt)
        {
            if (Hopping)
            {
                hopT += dt / 0.45f;
                var p = Vector3.Lerp(hopFrom, hopTo, hopT);
                p.y = Mathf.Lerp(hopFrom.y, hopTo.y, hopT) + Mathf.Sin(Mathf.Clamp01(hopT) * Mathf.PI) * 0.6f;
                t.position = p;
                if (hopT >= 1) Hopping = false;
                return Vector3.back;
            }
            if (Path.Count == 0) return Vector3.zero;
            var cur = GlenMap.ToCell(t.position);
            var next = Path[0];
            if (GlenMap.IsLedgeHop(cur, next))
            {
                Hopping = true;
                hopT = 0;
                hopFrom = t.position;
                hopTo = GlenMap.ToWorld(next);
                Path.RemoveAt(0);
                return Vector3.back;
            }
            var target = GlenMap.ToWorld(next);
            var flat = new Vector3(target.x - t.position.x, 0, target.z - t.position.z);
            float step = Speed * dt;
            if (flat.magnitude <= step)
            {
                var p = t.position + flat;
                p.y = GlenMap.SurfaceAt(p);
                t.position = p;
                Path.RemoveAt(0);
            }
            else
            {
                var p = t.position + flat.normalized * step;
                p.y = Mathf.Lerp(t.position.y, GlenMap.SurfaceAt(p), 1 - Mathf.Exp(-dt * 16));
                t.position = p;
            }
            return flat.normalized;
        }
    }
}
