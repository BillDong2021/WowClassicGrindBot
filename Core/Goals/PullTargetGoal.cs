using Core.GOAP;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Core.Goals
{
    public class PullTargetGoal : GoapGoal
    {
        public override float CostOfPerformingAction { get => 7f; }

        private readonly ILogger logger;
        private readonly ConfigurableInput input;

        private readonly Wait wait;
        private readonly AddonReader addonReader;
        private readonly PlayerReader playerReader;
        private readonly StopMoving stopMoving;
        private readonly StuckDetector stuckDetector;
        private readonly ClassConfiguration classConfiguration;
        
        private readonly CastingHandler castingHandler;
        private readonly MountHandler mountHandler;

        private readonly Random random = new();

        private DateTime pullStart;

        private int SecondsSincePullStarted => (int)(DateTime.UtcNow - pullStart).TotalSeconds;

        public PullTargetGoal(ILogger logger, ConfigurableInput input, Wait wait, AddonReader addonReader, StopMoving stopMoving, CastingHandler castingHandler, MountHandler mountHandler, StuckDetector stuckDetector, ClassConfiguration classConfiguration)
        {
            this.logger = logger;
            this.input = input;

            this.wait = wait;
            this.addonReader = addonReader;
            this.playerReader = addonReader.PlayerReader;
            this.stopMoving = stopMoving;
            
            this.castingHandler = castingHandler;
            this.mountHandler = mountHandler;

            this.stuckDetector = stuckDetector;
            this.classConfiguration = classConfiguration;

            classConfiguration.Pull.Sequence.Where(k => k != null).ToList().ForEach(key => Keys.Add(key));

            AddPrecondition(GoapKey.targetisalive, true);
            AddPrecondition(GoapKey.incombat, false);
            AddPrecondition(GoapKey.hastarget, true);
            AddPrecondition(GoapKey.pulled, false);
            AddPrecondition(GoapKey.withinpullrange, true);

            AddEffect(GoapKey.pulled, true);
        }

        public override ValueTask OnEnter()
        {
            if (mountHandler.IsMounted())
            {
                mountHandler.Dismount();
            }

            input.TapApproachKey($"{nameof(PullTargetGoal)}: OnEnter - Face the target and stop");
            stopMoving.Stop();
            wait.Update(1);

            pullStart = DateTime.UtcNow;

            return ValueTask.CompletedTask;
        }

        public override void OnActionEvent(object sender, ActionEventArgs e)
        {
            if (e.Key == GoapKey.resume)
            {
                pullStart = DateTime.UtcNow;
            }
        }

        public override ValueTask PerformAction()
        {
            if (SecondsSincePullStarted > 7)
            {
                input.TapClearTarget();
                input.KeyPress(random.Next(2) == 0 ? input.TurnLeftKey : input.TurnRightKey, 1000, "Too much time to pull!");
                pullStart = DateTime.UtcNow;

                return ValueTask.CompletedTask;
            }

            SendActionEvent(new ActionEventArgs(GoapKey.fighting, true));

            if (!Pull())
            {
                if (HasPickedUpAnAdd)
                {
                    Log($"Combat={this.playerReader.Bits.PlayerInCombat}, Is Target targetting me={this.playerReader.Bits.TargetOfTargetIsPlayer}");
                    Log($"Add on approach");

                    stopMoving.Stop();

                    input.TapNearestTarget();
                    wait.Update(1);

                    if (this.playerReader.HasTarget && playerReader.Bits.TargetInCombat)
                    {
                        if (this.playerReader.TargetTarget == TargetTargetEnum.TargetIsTargettingMe)
                        {
                            return ValueTask.CompletedTask;
                        }
                    }

                    input.TapClearTarget();
                    wait.Update(1);
                    pullStart = DateTime.UtcNow;

                    return ValueTask.CompletedTask;
                }

                if (!stuckDetector.IsMoving())
                {
                    stuckDetector.Unstick();
                }

                if (classConfiguration.Approach.GetCooldownRemaining() == 0)
                {
                    input.TapApproachKey($"{nameof(PullTargetGoal)}");
                    wait.Update(1);
                }
            }
            else
            {
                SendActionEvent(new ActionEventArgs(GoapKey.pulled, true));
            }

            wait.Update(1);

            return ValueTask.CompletedTask;
        }

        protected bool HasPickedUpAnAdd
        {
            get
            {
                return this.playerReader.Bits.PlayerInCombat && !this.playerReader.Bits.TargetOfTargetIsPlayer && this.playerReader.HealthPercent > 98;
            }
        }

        protected void WaitForWithinMeleeRange(KeyAction item, bool lastCastSuccess)
        {
            stopMoving.Stop();
            wait.Update(1);

            var start = DateTime.UtcNow;
            var lastKnownHealth = playerReader.HealthCurrent;
            int maxWaitTime = 10;

            Log($"Waiting for the target to reach melee range - max {maxWaitTime}s");

            while (playerReader.HasTarget && !playerReader.IsInMeleeRange && (DateTime.UtcNow - start).TotalSeconds < maxWaitTime)
            {
                if (playerReader.HealthCurrent < lastKnownHealth)
                {
                    Log("Got damage. Stop waiting for melee range.");
                    break;
                }

                if (playerReader.IsTargetCasting)
                {
                    Log("Target started casting. Stop waiting for melee range.");
                    break;
                }

                if (lastCastSuccess && addonReader.UsableAction.Is(item))
                {
                    Log($"While waiting, repeat current action: {item.Name}");
                    lastCastSuccess = castingHandler.CastIfReady(item, item.DelayBeforeCast);
                    Log($"Repeat current action: {lastCastSuccess}");
                }

                wait.Update(1);
            }
        }

        public bool Pull()
        {
            if (Keys.Count != 0)
            {
                input.TapStopAttack();
                wait.Update(1);
            }

            if (playerReader.Bits.HasPet && !playerReader.PetHasTarget)
            {
                input.TapPetAttack();
            }

            bool castAny = false;
            foreach (var item in Keys)
            {
                var success = castingHandler.CastIfReady(item, item.DelayBeforeCast);
                if (success)
                {
                    if (!playerReader.HasTarget)
                    {
                        return false;
                    }

                    castAny = true;

                    if (item.WaitForWithinMeleeRange)
                    {
                        WaitForWithinMeleeRange(item, success);
                    }
                }
            }

            if (castAny)
            {
                (bool timeout, double elapsedMs) = wait.Until(1000,
                    () => playerReader.TargetTarget == TargetTargetEnum.TargetIsTargettingMe ||
                          playerReader.TargetTarget == TargetTargetEnum.TargetIsTargettingPet);
                if (!timeout)
                {
                    Log($"Entered combat after {elapsedMs}ms");
                }
            }

            return playerReader.Bits.PlayerInCombat;
        }

        private void Log(string s)
        {
            logger.LogInformation($"{nameof(PullTargetGoal)}: {s}");
        }
    }
}