using System;
using System.Collections;
using UnityEngine;

namespace LuminaVale
{
    /// Friendly spar in the ring behind the shed. Rules are a straight port of
    /// ValeController.sparMove / _damage / _foeMove; presentation is a battle scene
    /// with its own arena, camera cuts and element effects.
    public sealed class SparBattle : MonoBehaviour
    {
        public GameUI UI;
        public GridCamera Camera;
        public Transform ArenaRoot;
        public Action<bool> Finished;

        static readonly Vector3 ArenaCenter = new(90, 0, 15);
        static readonly Vector3 SelfSpot = ArenaCenter + new Vector3(-1.5f, 0, -1.3f);
        static readonly Vector3 FoeSpot = ArenaCenter + new Vector3(1.6f, 0, 1.7f);
        static readonly string[] RivalNames = { "Bram", "Neri", "Soot", "Lumen", "Pebble", "Cinder", "Moss", "Dapple" };

        readonly System.Random rng = new();
        CreatureVisual self, foe;
        SpeciesDef foeDef;
        string rivalName;
        int selfHp, foeHp, maxHp, turn;
        bool selfGuard, foeGuard, busy, done, won;
        string lastFoeKind = "none", sparKey;

        void Awake() => BuildArena();

        void BuildArena()
        {
            ArenaRoot = new GameObject("Arena").transform;
            var ring = GlenBuilder.Make("Ring", ArenaRoot, MeshKit.Cylinder(40), Mats.Toon(new Color(0.94f, 0.86f, 0.66f), 1.2f));
            ring.transform.position = ArenaCenter;
            ring.transform.localScale = new Vector3(9, 0.1f, 9);
            var inner = GlenBuilder.Make("Inner", ArenaRoot, MeshKit.Cylinder(40), Mats.Toon(new Color(0.98f, 0.92f, 0.76f), 0f));
            inner.transform.position = ArenaCenter + Vector3.up * 0.005f;
            inner.transform.localScale = new Vector3(6.5f, 0.1f, 6.5f);
            var lawn = GlenBuilder.Make("Lawn", ArenaRoot, MeshKit.Box(), Mats.Toon(GlenBuilder.Grass, 0f));
            lawn.transform.position = ArenaCenter - Vector3.up * 0.06f;
            lawn.transform.localScale = new Vector3(40, 0.1f, 40);
            for (int i = 0; i < 18; i++)
            {
                float a = i / 18f * Mathf.PI * 2;
                var stone = GlenBuilder.Make("RingStone", ArenaRoot, MeshKit.Blob(1, 0.25f, i), Mats.Toon(GlenBuilder.Stone));
                stone.transform.position = ArenaCenter + new Vector3(Mathf.Cos(a), 0.12f, Mathf.Sin(a)) * 4.6f;
                stone.transform.localScale = new Vector3(0.5f, 0.35f, 0.5f);
            }
            for (int i = 0; i < 26; i++)
            {
                float a = i / 26f * Mathf.PI * 2;
                GlenBuilder.Tree(ArenaRoot, ArenaCenter + new Vector3(Mathf.Cos(a) * (8 + (i % 3)), 0, Mathf.Sin(a) * (8 + (i % 2) * 2)), 1.3f, i % 4 == 0, i % 7 == 0);
            }
            foreach (int side in new[] { -1, 1 })
            {
                var pole = GlenBuilder.Make("BannerPole", ArenaRoot, MeshKit.Cylinder(8), Mats.Toon(GlenBuilder.Wood));
                pole.transform.position = ArenaCenter + new Vector3(side * 3.6f, 0, 3.4f);
                pole.transform.localScale = new Vector3(0.12f, 2.6f, 0.12f);
                var flag = GlenBuilder.Make("Banner", ArenaRoot, MeshKit.Box(), Mats.Toon(side < 0 ? new Color(0.95f, 0.45f, 0.4f) : new Color(0.4f, 0.6f, 0.95f), wind: 0.3f));
                flag.transform.position = ArenaCenter + new Vector3(side * 3.6f + 0.4f, 2.2f, 3.4f);
                flag.transform.localScale = new Vector3(0.75f, 0.6f, 0.04f);
            }
        }

        int fixedStage = -1;
        bool wildFoe;

        public void Begin(string rival = null, SpeciesId? foeSpecies = null, int foeStage = -1)
        {
            var gm = GameManager.I;
            var kin = gm.Kin;
            var others = Array.FindAll(Catalog.All, s => s.Id != kin.Species);
            foeDef = foeSpecies.HasValue ? Catalog.Of(foeSpecies.Value) : others[rng.Next(others.Length)];
            fixedStage = foeStage;
            wildFoe = foeSpecies.HasValue;
            rivalName = rival ?? RivalNames[rng.Next(RivalNames.Length)];
            maxHp = 34 + kin.Stage * 8 + Mathf.RoundToInt(gm.Save.Psyche.Experience * 2f);
            selfHp = foeHp = maxHp;
            turn = 0;
            done = won = selfGuard = foeGuard = false;
            lastFoeKind = "none";
            sparKey = MoveMind.KeyFor(foeDef.Element, 1, "none");
            StartCoroutine(Intro());
        }

        IEnumerator Intro()
        {
            busy = true;
            GameInput.Locked = true;
            var gm = GameManager.I;
            yield return UI.Fade(1, 0.35f);
            if (self) Destroy(self.gameObject);
            if (foe) Destroy(foe.gameObject);
            self = CreatureVisual.Create(ArenaRoot, gm.Kin.Species, gm.Kin.Stage);
            self.transform.position = SelfSpot;
            self.transform.rotation = Quaternion.LookRotation(FoeSpot - SelfSpot);
            int foeStage = fixedStage >= 0 ? Mathf.Clamp(fixedStage, 0, 2) : Mathf.Clamp(gm.Kin.Stage + (rng.NextDouble() < 0.3 ? 1 : 0), 0, 2);
            foe = CreatureVisual.Create(ArenaRoot, foeDef.Id, foeStage);
            foe.transform.position = FoeSpot;
            foe.transform.rotation = Quaternion.LookRotation(SelfSpot - FoeSpot);
            ProcAudio.I?.Music("battle");
            Camera.Push(FoeSpot + Vector3.up * 0.6f, 14, 6.5f, 34, -35);
            UI.ShowBattle(true);
            UI.SetMoves(null, 0, null);
            Refresh($"{rivalName} pads into the ring.");
            yield return UI.Fade(0, 0.35f);
            yield return new WaitForSeconds(0.4f);
            foe.SetPose(KinPose.Cheer);
            ProcAudio.I?.Chirp(foeDef.Id, 0.9f);
            if (!wildFoe) yield return Say($"{rivalName} sends out {foeDef.TitleFor(foeStage)}!");
            Camera.Push(Vector3.Lerp(SelfSpot, FoeSpot, 0.45f) + Vector3.up * 0.5f, 22, 7.6f, 34, 0);
            self.SetPose(KinPose.Cheer);
            ProcAudio.I?.Chirp(gm.Kin.Species);
            yield return Say($"Go, {gm.Kin.Name}!");
            busy = false;
            ShowMoves();
        }

        IEnumerator Say(string line)
        {
            Refresh(line);
            yield return new WaitForSeconds(Mathf.Clamp(line.Length * 0.035f, 0.9f, 2f));
        }

        void Refresh(string log)
        {
            var gm = GameManager.I;
            UI.SetBattle($"{gm.Kin.Name}  <size=28>{Psyche.Word(gm.Save.Psyche.Dominant)}</size>", selfHp / (float)maxHp,
                $"{rivalName}'s {foeDef.Name}", foeHp / (float)maxHp, log);
        }

        void ShowMoves()
        {
            var kin = GameManager.I.Kin;
            UI.SetMoves(kin.Def.Moves, MoveMind.Suggest(GameManager.I.Save.SparQ, sparKey, GameManager.I.Save.Mind("spar")), Pick);
            Refresh($"What will {kin.Name} do?");
        }

        void Pick(int index)
        {
            if (busy || done) return;
            UI.SetMoves(null, 0, null);
            StartCoroutine(Turn(index));
        }

        MoveDef FoeMove()
        {
            double roll = rng.NextDouble();
            if (roll < 0.62) return foeDef.Moves[0];
            if (roll < 0.84) return foeDef.Moves[2];
            return foeDef.Moves[1];
        }

        int Damage(MoveDef move, KinElement defense, bool guarding, float skill, float learned = 1f)
        {
            if (move.IsGuard) return 0;
            float amount = move.Power;
            if (move.IsRally) amount *= 0.55f;
            amount *= Catalog.TypeMod(move.Element, defense);
            amount *= 1 + skill / 150f;
            amount *= 0.9f + (float)rng.NextDouble() * 0.22f;
            if (guarding) amount *= 0.42f;
            amount *= learned;   // per-move proficiency x battle spirit, both learned
            return Mathf.Clamp(Mathf.RoundToInt(amount), 1, 20);
        }

        IEnumerator Turn(int index)
        {
            busy = true;
            var gm = GameManager.I;
            var kin = gm.Kin;
            var selfDef = kin.Def;
            var psyche = gm.Save.Psyche;
            int commanded = index;
            // A kin that does not trust you yet may follow its own learned policy instead.
            bool loafed = false;
            if (rng.NextDouble() > psyche.Obedience)
            {
                if (psyche[Emotion.Frustration] > 0.5f && rng.NextDouble() < 0.35) loafed = true;
                else index = MoveMind.Suggest(gm.Save.SparQ, sparKey, gm.Save.Mind("spar"));
            }
            var move = selfDef.Moves[Mathf.Clamp(index, 0, selfDef.Moves.Length - 1)];
            var foeMove = FoeMove();
            int dealt = 0, taken = 0;
            selfGuard = move.IsGuard && !loafed;
            bool prevFoeGuard = foeGuard;
            foeGuard = false;

            if (loafed) yield return Say($"{kin.Name} is too frustrated to listen and sulks this turn...");
            else if (index != commanded) yield return Say($"{kin.Name} ignores you and goes with {move.Name}!");
            else yield return Say($"{kin.Name} uses {move.Name}!");
            if (loafed) { }
            else if (move.IsGuard)
            {
                yield return Guard(self, selfDef.Element);
                yield return Say(move.Line);
            }
            else
            {
                dealt = Damage(move, foeDef.Element, prevFoeGuard, kin.PatternSkill, psyche.Skill(move.Id) * psyche.BattleSpirit);
                yield return Attack(self, foe, move);
                foeHp -= dealt;
                if (move.IsRally) selfHp = Math.Min(maxHp, selfHp + 7);
                float mod = Catalog.TypeMod(move.Element, foeDef.Element);
                yield return Say($"{dealt} hits." + (mod > 1.05f ? " It lands bright!" : mod < 0.95f ? " It glances off." : ""));
            }

            bool win = foeHp <= 0;
            if (!win)
            {
                yield return Say($"{rivalName}'s {foeDef.Name} uses {foeMove.Name}!");
                if (foeMove.IsGuard)
                {
                    foeGuard = true;
                    yield return Guard(foe, foeDef.Element);
                }
                else
                {
                    taken = Damage(foeMove, selfDef.Element, selfGuard, 0);
                    yield return Attack(foe, self, foeMove);
                    if (foeMove.IsRally) foeHp = Math.Min(maxHp, foeHp + 6);
                    selfHp -= taken;
                    yield return Say($"{taken} back.");
                }
            }

            turn++;
            done = win || selfHp <= 0 || turn >= 8;
            if (done && !win && selfHp > 0 && foeHp > 0) win = selfHp >= foeHp;
            if (done && selfHp <= 0) win = false;
            selfHp = Math.Max(0, selfHp);
            foeHp = Math.Max(0, foeHp);
            string nextKey = MoveMind.KeyFor(foeDef.Element, maxHp == 0 ? 0 : selfHp / (float)maxHp, foeMove.Kind);
            float reward = (dealt - taken * 0.65f) / 10f;
            if (done && win) reward += 0.85f;
            if (done && !win) reward -= 0.45f;
            MoveMind.Learn(gm.Save.SparQ, sparKey, Mathf.Clamp(index, 0, 2), reward, nextKey, gm.Save.Mind("spar"));
            if (!loafed) psyche.LearnMove(move.Id, reward);
            sparKey = nextKey;
            lastFoeKind = foeMove.Kind;
            Refresh("");
            won = win;
            busy = false;
            if (done) StartCoroutine(Outro());
            else ShowMoves();
        }

        IEnumerator Attack(CreatureVisual a, CreatureVisual b, MoveDef move)
        {
            var start = a.transform.position;
            var toward = (b.transform.position - start).normalized;
            Camera.Push(Vector3.Lerp(a.transform.position, b.transform.position, 0.6f) + Vector3.up * 0.5f, 18, 6f, 30, a == self ? -12 : 12);
            ProcAudio.I?.Play("whoosh", 0.7f);
            a.Squash(-0.25f);
            for (float t = 0; t < 1; t += Time.deltaTime / 0.22f)
            {
                a.transform.position = start + toward * Mathf.Sin(t * Mathf.PI) * 1.1f;
                yield return null;
            }
            a.transform.position = start;
            Fx.Element(b.transform.position + Vector3.up * 0.5f, move.Element);
            ProcAudio.I?.Play("hit", 0.9f);
            Camera.Shake(0.8f);
            b.Squash(0.3f);
            var back = b.transform.position;
            for (float t = 0; t < 1; t += Time.deltaTime / 0.3f)
            {
                b.transform.position = back + toward * Mathf.Sin(t * Mathf.PI) * 0.25f;
                yield return null;
            }
            b.transform.position = back;
            yield return new WaitForSeconds(0.2f);
        }

        IEnumerator Guard(CreatureVisual who, KinElement element)
        {
            ProcAudio.I?.Play("guard", 0.8f);
            Fx.Burst(who.transform.position + Vector3.up * 0.5f, Color.Lerp(Catalog.ElementColor(element), Color.white, 0.5f), 18, 1.4f, 0.24f, true, 0, 0.8f, 0);
            who.Squash(-0.2f);
            yield return new WaitForSeconds(0.5f);
        }

        IEnumerator Outro()
        {
            var gm = GameManager.I;
            var loser = won ? foe : self;
            var winner = won ? self : foe;
            loser.SetPose(KinPose.Sleep);
            winner.SetPose(KinPose.Cheer);
            Camera.Push(winner.transform.position + Vector3.up * 0.5f, 16, 4.5f, 30, won ? -20 : 20);
            if (won) ProcAudio.I?.Play("fanfare");
            yield return Say(won ? $"{gm.Kin.Name} wins the spar!" : $"{rivalName}'s {foeDef.Name} takes this one.");
            yield return new WaitForSeconds(0.8f);
            yield return UI.Fade(1, 0.4f);
            UI.ShowBattle(false);
            Camera.Release();
            Destroy(self.gameObject);
            Destroy(foe.gameObject);
            GameInput.Locked = false;
            gm.BattleResult(won, selfHp / (float)maxHp);
            Finished?.Invoke(won);
            yield return UI.Fade(0, 0.4f);
        }
    }
}
