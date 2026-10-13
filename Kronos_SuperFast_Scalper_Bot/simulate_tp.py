import os
import pandas as pd
import numpy as np

# Simulation of 100 typical BTC scalp trades matching our live distribution
# Distribution:
# - 50 trades: Micro impulse to +$15-$25 then full reversal back to entry/below
# - 25 trades: Immediate loss (-$13)
# - 15 trades: Impulse to +$20, pullback to +$5, then continuation to full 2R (+ $60)
# - 10 trades: Direct monster runner to full 3R (+ $100)

n_sim = 10000
np.random.seed(42)

# Trade Types
types = np.random.choice(['reversal_after_impulse', 'immediate_loss', 'pullback_then_tp', 'monster_runner'], 
                         size=n_sim, p=[0.50, 0.25, 0.15, 0.10])

# Strategy 1: Partial 50% TP at +$20 (half lot), runner has wide breathing SL
pnl_partial = []
for t in types:
    if t == 'immediate_loss':
        pnl_partial.append(-13.0)
    elif t == 'reversal_after_impulse':
        # Bank 50% of +$20 = +$10. Remaining 50% closes at BE ($0)
        pnl_partial.append(10.0)
    elif t == 'pullback_then_tp':
        # Bank 50% of +$20 = +$10. Remaining 50% hits +$60 TP = +$30
        pnl_partial.append(10.0 + 30.0) # +$40
    elif t == 'monster_runner':
        # Bank 50% of +$20 = +$10. Remaining 50% hits +$100 TP = +$50
        pnl_partial.append(10.0 + 50.0) # +$60

# Strategy 2: Step-Ladder Profit Lock (100% volume, SL moves to lock +$10 at +$20, but pullbacks >$10 get stopped out)
pnl_steplock = []
for t in types:
    if t == 'immediate_loss':
        pnl_steplock.append(-13.0)
    elif t == 'reversal_after_impulse':
        # 100% volume stopped at +$10 lock
        pnl_steplock.append(10.0)
    elif t == 'pullback_then_tp':
        # The $15 pullback hits the tight +$10 step-lock! Exits with only +$10 instead of riding to TP!
        pnl_steplock.append(10.0)
    elif t == 'monster_runner':
        # Rides the wave with 100% volume to +$100
        pnl_steplock.append(100.0)

print("=== QUANTITATIVE SIMULATION RESULTS (10,000 TRADES) ===")
print(f"Strategy 1 (Partial 50% Take-Profit) Total PnL: ${sum(pnl_partial):,.2f} | Avg Trade: ${np.mean(pnl_partial):.2f}")
print(f"Strategy 2 (Step-Ladder Lock)         Total PnL: ${sum(pnl_steplock):,.2f} | Avg Trade: ${np.mean(pnl_steplock):.2f}")
print(f"Profit Factor - Partial TP : {(sum(x for x in pnl_partial if x>0) / abs(sum(x for x in pnl_partial if x<0))):.2f}")
print(f"Profit Factor - Step-Lock  : {(sum(x for x in pnl_steplock if x>0) / abs(sum(x for x in pnl_steplock if x<0))):.2f}")
