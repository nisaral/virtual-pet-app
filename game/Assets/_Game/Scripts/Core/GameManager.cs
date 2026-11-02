using System;
using UnityEngine;

namespace LuminaVale
{
    /// Owns the save and every rule that changes it. Port of the care half of
    /// lib/vale/controller.dart; world, battle and UI code call into this.
    public sealed class GameManager : MonoBehaviour
    {
        public static GameManager I { get; private set; }

        public SaveData Save { get; private set; }
        public Kin Kin => Save?.Kin;
        public bool HasGame => Save != null;

        public event Action KinChanged;
        public event Action<string> Toast;
        public event Action<string> BidRaised;
        public event Action EvolveReady;

        /// Real seconds per in-game hour of need decay. 3600 matches the Flutter app.
        public float SecondsPerDecayHour = 3600f;
        public float BidInterval = 75f;
        public float BidPatience = 150f;

        readonly System.Random rng = new();
        float bidTimer = 20f;
        float persistTimer;

        void Awake()
        {
            if (I != null && I != this) { Destroy(gameObject); return; }
            I = this;
            DontDestroyOnLoad(gameObject);
            Save = SaveSystem.Load();
            if (Save != null) Arrive();
        }

        public void NewGame(string keeper, string kinName, SpeciesId species)
        {
            Save = new SaveData { KeeperName = keeper, Kin = Kin.Fresh(kinName, species) };
            Save.Psyche.OnVisit(DateTime.Now);
            CareSim.Remember(Save, $"{kinName} came home to the glen with {keeper}.");
            Persist();
            KinChanged?.Invoke();
        }

        public void ResetGame()
        {
            SaveSystem.Delete();
            Save = null;
        }

        void Update()
        {
            if (Save == null) return;
            float dt = Time.unscaledDeltaTime;
            Save.Kin = DecayLive(Save.Kin, dt / SecondsPerDecayHour);
            Save.Psyche ??= new Psyche();
            Save.Psyche.Tick(dt / SecondsPerDecayHour, Save.Kin, DateTime.Now);

            bidTimer -= dt;
            if (bidTimer <= 0)
            {
                bidTimer = BidInterval * (0.75f + (float)rng.NextDouble() * 0.5f);
                TickBid();
            }

            persistTimer += dt;
            if (persistTimer > 20f) { persistTimer = 0; Persist(); }
        }

        static Kin DecayLive(Kin kin, float hours)
        {
            if (kin.Asleep)
            {
                kin.Energy = Catalog.ClampStat(kin.Energy + 18f * hours);
                if (kin.Energy >= 96) kin.Asleep = false;
                hours *= 0.4f;
            }
            kin.Satiation = Catalog.SoftFloor(kin.Satiation - 4.4f * hours);
            if (!kin.Asleep) kin.Energy = Catalog.SoftFloor(kin.Energy - 2.6f * hours);
            kin.Coat = Catalog.SoftFloor(kin.Coat - 1.7f * hours);
            kin.Joy = Catalog.SoftFloor(kin.Joy - 1.4f * hours);
            return kin;
        }

        void TickBid()
        {
            var kin = Save.Kin;
            if (kin.Asleep) return;
            if (kin.PendingBid != null)
            {
                if (kin.BidAt.HasValue && (DateTime.Now - kin.BidAt.Value).TotalSeconds > BidPatience)
                {
                    float hurt = Save.Psyche.OnBidIgnored();
                    BondMind.Learn(Save.QTable, kin.BidStateKey, BondMind.IndexOf(kin.PendingBid), -0.38f + hurt * 2f, BondMind.KeyFor(kin, DateTime.Now), Save.Mind("bond"));
                    CareSim.Remember(Save, $"{kin.Name} asked for a {kin.PendingBid} and let it go.");
                    kin.PendingBid = null;
                    kin.BidAt = null;
                    KinChanged?.Invoke();
                }
                return;
            }
            var key = BondMind.KeyFor(kin, DateTime.Now);
            var anticipated = Save.Routine.Anticipate(DateTime.Now.Hour);
            string bidHint = anticipated != null && BondMind.CareToBid.TryGetValue(anticipated, out var b) ? b : null;
            int index = BondMind.Choose(Save.QTable, key, kin, Save.MindSteps, bidHint, rng, Save.Mind("bond"));
            Save.MindSteps++;
            kin.PendingBid = BondMind.Actions[index];
            kin.BidAt = DateTime.Now;
            kin.BidStateKey = key;
            BidRaised?.Invoke(kin.PendingBid);
            KinChanged?.Invoke();
        }

        // ---- Care verbs ---------------------------------------------------------------

        // Each verb is appraised by the Psyche; the emotional change is the reward.
        public CareOutcome Feed(string foodId)
        {
            var before = Save.Kin;
            var o = CareSim.Feed(before, foodId, Save.Bag);
            bool loved = before.FoodLove.TryGetValue(foodId, out var l) && l >= 0.55f;
            return Apply("feed", o, true, () => Save.Psyche.OnFeed(before, loved, o.Overfed, DateTime.Now));
        }

        public CareOutcome Groom(float quality) => Apply("groom", CareSim.Groom(Save.Kin, quality), true, () => Save.Psyche.OnGroom(quality));
        public CareOutcome Rest() { bool tired = Save.Kin.Energy < 50; return Apply("rest", CareSim.Rest(Save.Kin), true, () => Save.Psyche.OnRest(tired)); }
        public CareOutcome Praise() { bool deserved = Save.Kin.PendingBid == "trick"; return Apply("praise", CareSim.Praise(Save.Kin), true, () => Save.Psyche.OnPraise(deserved)); }
        public CareOutcome Nuzzle() => Apply("nuzzle", CareSim.Nuzzle(Save.Kin), false, () => Save.Psyche.OnNuzzle());

        public CareOutcome Play(string gameId, float score)
        {
            Save.GamesPlayed.Add(gameId);
            return Apply("play", CareSim.Play(Save.Kin, gameId, score), true, () => Save.Psyche.OnPlay(gameId, score));
        }

        /// Battle results come back through here so emotions, credit and the bid learner all see them.
        public void BattleResult(bool won, float margin)
        {
            Save.Psyche.OnBattle(won, margin);
            Play("spar", won ? 0.6f + 0.4f * margin : 0.2f);
        }

        void Arrive()
        {
            CareSim.ApplyOffline(Save, DateTime.Now - Save.LastSeen);
            Save.Psyche ??= new Psyche();
            double away = (DateTime.Now - Save.LastSeen).TotalHours;
            Save.Psyche.Tick((float)Math.Min(away, 48), Save.Kin, DateTime.Now);
            if (away > 0.5) Save.Psyche.OnVisit(DateTime.Now);
        }

        public void TickFarm()
        {
            if (Save == null) return;
            int day = Save.Kin.DaysTogether;
            if (Save.FarmDay == day) return;
            Save.FarmDay = day;
            var keys = new System.Collections.Generic.List<string>(Save.Farm.Keys);
            foreach (var id in keys)
                if (Save.Farm[id] == 1) Save.Farm[id] = 2;
        }

        public int PlotStage(string id) => Save != null && Save.Farm.TryGetValue(id, out int s) ? s : 0;

        public bool WaterPlot(string id)
        {
            TickFarm();
            if (PlotStage(id) != 0) return false;
            Save.Farm[id] = 1;
            Persist();
            Say("You water the plot. Come back tomorrow.");
            return true;
        }

        public bool HarvestPlot(string id)
        {
            TickFarm();
            if (PlotStage(id) != 2) return false;
            Save.Farm[id] = 0;
            Save.Bag["sunberry"] = (Save.Bag.TryGetValue("sunberry", out int n) ? n : 0) + 2;
            Persist();
            KinChanged?.Invoke();
            Say("Ripe sunberries. Two for the bowl.");
            return true;
        }

        public void Collect(string pickupId, string itemId, int amount = 1)
        {
            if (!Save.TakenPickups.Add(pickupId)) return;
            if (itemId == "gleam") Save.Gleam += amount;
            else Save.Bag[itemId] = (Save.Bag.TryGetValue(itemId, out int n) ? n : 0) + amount;
            Toast?.Invoke(itemId == "gleam" ? $"+{amount} gleam" : $"Found {Catalog.Food(itemId).Name}!");
            KinChanged?.Invoke();
        }

        public void PassHours(int hours)
        {
            CareSim.PassHours(Save, hours);
            Persist();
            KinChanged?.Invoke();
        }

        public void Evolve()
        {
            var before = Save.Kin;
            Save.Kin = CareSim.Evolve(before);
            var def = Save.Kin.Def;
            CareSim.Remember(Save, $"{before.Name} became {def.TitleFor(Save.Kin.Stage)}.");
            Persist();
            KinChanged?.Invoke();
        }

        public bool ReadyToEvolve => Save != null && Save.Psyche.ReadyFor(Save.Kin.Stage);

        CareOutcome Apply(string action, CareOutcome outcome, bool fromCare, Func<float> appraise)
        {
            if (outcome.Rejected)
            {
                Toast?.Invoke(outcome.Reaction);
                return outcome;
            }
            var before = Save.Kin;
            float felt = appraise();   // valence change: the emotional reward of this moment
            if (before.PendingBid != null && action != "nuzzle")
            {
                float reward = BondMind.ResponseReward(before.PendingBid, action, before.Satiation, before.Energy, before.Coat);
                felt += Save.Psyche.OnBidAnswered(reward);
                BondMind.Learn(Save.QTable, before.BidStateKey, BondMind.IndexOf(before.PendingBid), reward + felt * 2f,
                    BondMind.KeyFor(outcome.Kin, DateTime.Now), Save.Mind("bond"));
            }
            Save.Kin = outcome.Kin;
            if (outcome.Bag.Count > 0) Save.Bag = outcome.Bag;
            Save.Gleam += outcome.GleamGain;
            Save.Routine.Observe(action, DateTime.Now.Hour);
            CareSim.Remember(Save, outcome.Memory);
            Save.LastSeen = DateTime.Now;
            if (!string.IsNullOrEmpty(outcome.Reaction)) Toast?.Invoke(outcome.Reaction);
            KinChanged?.Invoke();
            Persist();
            if (fromCare && ReadyToEvolve) EvolveReady?.Invoke();
            return outcome;
        }

        public void Notify() => KinChanged?.Invoke();
        public void Say(string line) => Toast?.Invoke(line);

        public void Persist()
        {
            if (Save == null) return;
            Save.LastSeen = DateTime.Now;
            SaveSystem.Write(Save);
        }

        void OnApplicationPause(bool paused)
        {
            if (Save == null) return;
            if (paused) Persist();
            else
            {
                Arrive();
                KinChanged?.Invoke();
            }
        }

        void OnApplicationQuit() => Persist();
    }
}
