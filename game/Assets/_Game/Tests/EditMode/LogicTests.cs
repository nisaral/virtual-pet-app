using System;
using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using UnityEngine;

namespace LuminaVale.Tests
{
    public class CareSimTests
    {
        [Test]
        public void FreshKinLovesItsFavouriteFood()
        {
            var kin = Kin.Fresh("Pip", SpeciesId.Pipkin);
            Assert.AreEqual(0.82f, kin.FoodLove["sunberry"], 1e-4);
            Assert.AreEqual(0.58f, kin.FoodLove["milkdrop"], 1e-4);
            Assert.AreEqual(0.28f, kin.FoodLove["kelpbit"], 1e-4);
        }

        [Test]
        public void FeedingLovedFoodFillsMoreAndUsesTheBag()
        {
            var kin = Kin.Fresh("Pip", SpeciesId.Pipkin);
            kin.Satiation = 40;
            var bag = new Dictionary<string, int> { ["sunberry"] = 1 };
            var o = CareSim.Feed(kin, "sunberry", bag);
            Assert.IsFalse(o.Rejected);
            Assert.AreEqual(64f, o.Kin.Satiation, 1e-3);
            Assert.AreEqual(0, o.Bag["sunberry"]);
            Assert.AreEqual(1, o.Kin.CareCount);
            Assert.Greater(o.Kin.FoodLove["sunberry"], 0.82f);
        }

        [Test]
        public void EmptyBagIsRejected()
        {
            var o = CareSim.Feed(Kin.Fresh("Pip", SpeciesId.Pipkin), "kelpbit", new Dictionary<string, int>());
            Assert.IsTrue(o.Rejected);
        }

        [Test]
        public void OverfeedingCostsJoy()
        {
            var kin = Kin.Fresh("Pip", SpeciesId.Pipkin);
            kin.Satiation = 90;
            var o = CareSim.Feed(kin, "kelpbit", new Dictionary<string, int> { ["kelpbit"] = 2 });
            Assert.IsTrue(o.Overfed);
            Assert.Less(o.Kin.Joy, kin.Joy);
        }

        [Test]
        public void DecayRespectsSoftFloor()
        {
            var kin = CareSim.Decay(Kin.Fresh("Pip", SpeciesId.Pipkin), 100);
            Assert.AreEqual(8f, kin.Satiation);
            Assert.AreEqual(8f, kin.Energy);
        }

        [Test]
        public void NoEvolutionWithoutGrowthAndTrust()
        {
            var p = new Psyche();
            Assert.IsFalse(p.ReadyFor(0));
            p.Banks["care"].Credit = 20;
            p[Emotion.Trust] = 0.1f;
            Assert.IsFalse(p.ReadyFor(0), "growth alone is not enough: a kin that doesn't trust you won't grow");
            p[Emotion.Trust] = 0.8f; p[Emotion.Joy] = 0.9f; p[Emotion.Contentment] = 0.9f; p[Emotion.Anxiety] = 0.05f; p[Emotion.Frustration] = 0f; p[Emotion.Loneliness] = 0f;
            Assert.IsTrue(p.ReadyFor(0));
        }

        [Test]
        public void RegularFeedingBuildsMoreTrustThanErratic()
        {
            var kin = Kin.Fresh("Pip", SpeciesId.Pipkin);
            kin.Satiation = 40;
            var regular = new Psyche();
            var erratic = new Psyche();
            var t = new DateTime(2026, 1, 1, 8, 0, 0);
            var rnd = new System.Random(1);
            float trustBefore = regular[Emotion.Trust];
            for (int i = 0; i < 10; i++)
            {
                regular.OnFeed(kin, false, false, t.AddHours(i * 4));
                erratic.OnFeed(kin, false, false, t.AddHours(i * 4 + rnd.Next(-3, 9)));
            }
            Assert.Greater(regular.Feeding.Regularity, erratic.Feeding.Regularity);
            Assert.Greater(regular[Emotion.Trust], trustBefore);
        }

        [Test]
        public void RepetitionHabituatesJoy()
        {
            var p = new Psyche();
            float first = p.OnPlay("pattern", 0.8f);
            for (int i = 0; i < 6; i++) p.OnPlay("pattern", 0.8f);
            float later = p.OnPlay("pattern", 0.8f);
            Assert.Less(later, first, "the same game over and over should feel less rewarding");
        }

        [Test]
        public void NeglectHurts()
        {
            var p = new Psyche();
            var kin = Kin.Fresh("Pip", SpeciesId.Pipkin);
            kin.Satiation = 15;
            float v = p.ValenceNow;
            p.Tick(10, kin, DateTime.Now);
            p.OnBidIgnored();
            Assert.Less(p.ValenceNow, v);
            Assert.Greater(p[Emotion.Loneliness], 0.2f);
        }

        [Test]
        public void CreditFavoursLearningOverGrinding()
        {
            var bank = new CreditBank();
            float early = bank.Learn(1f);
            for (int i = 0; i < 40; i++) bank.Learn(1f);
            float late = bank.Learn(1f);
            Assert.Less(late, early);
        }

        [Test]
        public void TrustRaisesObedience()
        {
            var p = new Psyche();
            p[Emotion.Trust] = 0.1f;
            float low = p.Obedience;
            p[Emotion.Trust] = 0.9f;
            Assert.Greater(p.Obedience, low);
        }

        [Test]
        public void TypeTriangle()
        {
            Assert.Greater(Catalog.TypeMod(KinElement.Ember, KinElement.Bloom), 1f);
            Assert.Greater(Catalog.TypeMod(KinElement.Bloom, KinElement.Tide), 1f);
            Assert.Greater(Catalog.TypeMod(KinElement.Tide, KinElement.Ember), 1f);
            Assert.Less(Catalog.TypeMod(KinElement.Bloom, KinElement.Ember), 1f);
        }
    }

    public class MindTests
    {
        [Test]
        public void BondMindLearnsFromRewards()
        {
            var table = new Dictionary<string, float[]>();
            BondMind.Learn(table, "s", 0, 1.45f, "s2");
            Assert.AreEqual(0.34f * 1.45f, table["s"][0], 1e-4);
        }

        [Test]
        public void RoutineAnticipatesRepeatedHabit()
        {
            var r = new RoutineModel();
            for (int i = 0; i < 4; i++) r.Observe("feed", 8);
            Assert.AreEqual("feed", r.Anticipate(8));
            Assert.IsNull(r.Anticipate(15));
        }

        [Test]
        public void MoveMindSuggestsBestMove()
        {
            var table = new Dictionary<string, float[]>();
            Assert.AreEqual(0, MoveMind.Suggest(table, "k"));
            MoveMind.Learn(table, "k", 2, 1f, "k");
            Assert.AreEqual(2, MoveMind.Suggest(table, "k"));
        }

        [Test]
        public void BackoffGivesNewStatesAHeadStart()
        {
            var table = new Dictionary<string, float[]>();
            var mem = new MindMemory();
            for (int i = 0; i < 6; i++) MoveMind.Learn(table, "fire|2|none", 1, 1f, "fire|2|none", mem);
            // A stamina bin never seen before still prefers the move that worked against fire.
            Assert.AreEqual(1, MoveMind.Suggest(table, "fire|0|strike", mem));
        }

        [Test]
        public void StepSizeShrinksWithVisits()
        {
            var table = new Dictionary<string, float[]>();
            var mem = new MindMemory();
            BondMind.Learn(table, "s", 0, 1f, "end", mem);
            float first = table["s"][0];
            for (int i = 0; i < 40; i++) BondMind.Learn(table, "s", 0, 1f, "end", mem);
            BondMind.Learn(table, "s", 0, -1f, "end", mem);
            Assert.Greater(first, 0.3f);
            // One bad event after many good ones only nudges the value.
            Assert.Greater(table["s"][0], 0.5f);
            Assert.LessOrEqual(mem.Replay.Count, QCore.ReplayCap);
        }

        [Test]
        public void RewardsAreClippedAndNanSafe()
        {
            var table = new Dictionary<string, float[]>();
            BondMind.Learn(table, "s", 0, float.NaN, "s2", new MindMemory());
            Assert.AreEqual(0f, table["s"][0]);
            BondMind.Learn(table, "t", 0, 1e6f, "t2", new MindMemory());
            Assert.LessOrEqual(table["t"][0], BondMind.Alpha * QCore.RewardClip + 1e-4f);
        }

        [Test]
        public void TablesStayBounded()
        {
            var table = new Dictionary<string, float[]>();
            var mem = new MindMemory();
            for (int i = 0; i < QCore.TableCap + 600; i++) BondMind.Learn(table, $"p|0|0|0|0|0|{i}", 0, 0.5f, "end", mem);
            Assert.LessOrEqual(table.Count, QCore.TableCap + 220);
            Assert.IsTrue(table.ContainsKey("~p|0|0"), "coarse backoff survives pruning");
        }

        [Test]
        public void SoftmaxPrefersBetterButExplores()
        {
            var r = new System.Random(5);
            int best = 0, other = 0;
            for (int i = 0; i < 400; i++)
            {
                int c = QCore.Softmax(new[] { 1f, 0.6f, 0f }, 0.3f, r);
                if (c == 0) best++; else other++;
            }
            Assert.Greater(best, other);
            Assert.Greater(other, 20);
        }

        [Test]
        public void SpatialCuriosityFades()
        {
            Assert.Greater(SpatialMind.Intrinsic(0), SpatialMind.Intrinsic(10));
        }

        [Test]
        public void SaveRoundTrips()
        {
            var save = new SaveData { Kin = Kin.Fresh("Pip", SpeciesId.Solbit) };
            save.QTable["a"] = new[] { 1f, 2f, 3f, 4f, 5f, 6f };
            save.Routine.Observe("play", 9);
            string json = Newtonsoft.Json.JsonConvert.SerializeObject(save);
            var back = Newtonsoft.Json.JsonConvert.DeserializeObject<SaveData>(json);
            Assert.AreEqual(SpeciesId.Solbit, back.Kin.Species);
            Assert.AreEqual(5f, back.QTable["a"][4]);
            Assert.AreEqual(1f, back.Routine.Counts[1][9]);
        }
    }

    public class MapTests
    {
        [Test]
        public void RowsAreRectangular()
        {
            foreach (var row in GlenMap.Rows) Assert.AreEqual(GlenMap.Rows[0].Length, row.Length);
        }

        [Test]
        public void EveryDoorAndTheRuneHillAreReachable()
        {
            var start = GlenMap.SpotById("keeperStart").Cell;
            foreach (var b in GlenMap.Buildings)
                Assert.IsNotEmpty(GlenMap.FindPath(start, b.Door), $"no path to {b.Name}");
            Assert.IsNotEmpty(GlenMap.FindPath(start, new Vector2Int(26 + GlenMap.Ox, 3 + GlenMap.Oy)), "no path up the stairs");
            Assert.IsNotEmpty(GlenMap.FindPath(start, GlenMap.SpotById("gateDesert").Cell), "no path west to the dunes");
            Assert.Greater(GlenMap.Width, 90);
            foreach (var r in GlenMap.Regions)
                Assert.IsTrue(r.Cell == start || GlenMap.FindPath(start, r.Cell, 40000).Count > 0, $"no path to {r.Title}");
        }

        [Test]
        public void WildKinHaveDensInEveryWildRegion()
        {
            var dens = WildLife.Dens();
            Assert.Greater(dens.Count, 20);
            var zones = new HashSet<string>();
            foreach (var d in dens)
            {
                Assert.AreEqual(Tile.TallGrass, GlenMap.At(d.x, d.y));
                zones.Add(GlenMap.ZoneAt(d));
            }
            foreach (var z in new[] { "frost", "dunes", "thicket" }) Assert.Contains(z, zones.ToList());
        }

        [Test]
        public void LedgesAreOneWay()
        {
            var top = new Vector2Int(25 + GlenMap.Ox, 6 + GlenMap.Oy);
            var below = new Vector2Int(25 + GlenMap.Ox, 7 + GlenMap.Oy);
            Assert.IsTrue(GlenMap.CanStep(top, below));
            Assert.IsFalse(GlenMap.CanStep(below, top));
        }

        [Test]
        public void WorldCellRoundTrip()
        {
            var c = new Vector2Int(12, 20);
            Assert.AreEqual(c, GlenMap.ToCell(GlenMap.ToWorld(c)));
        }
    }
}
