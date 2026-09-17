#!/usr/bin/env python3
"""
PAIDBALL fee-split simulator.

Mirrors the exact integer math used in PaidballFeeRouter.sol so you can sanity
check distribution behavior — including rounding dust — before deploying.

    HOLDER_BPS     = 5000   # 50.00%
    RECIPIENT_BPS  = 5000   # 50.00%
    BPS_DENOMINATOR = 10000

Usage:
    python3 simulate_fees.py --swaps 500 --mean-fee 0.42
"""
from __future__ import annotations

import argparse
import random
from dataclasses import dataclass

HOLDER_BPS = 5_000
BPS_DENOMINATOR = 10_000


@dataclass
class SplitResult:
    total: int
    to_holders: int
    to_recipient: int


def split_fee(amount_lamports: int) -> SplitResult:
    """Integer-identical port of PaidballFeeRouter.routeFee's split math."""
    to_holders = (amount_lamports * HOLDER_BPS) // BPS_DENOMINATOR
    to_recipient = amount_lamports - to_holders
    return SplitResult(amount_lamports, to_holders, to_recipient)


def run(swaps: int, mean_fee_sol: float, seed: int) -> None:
    rng = random.Random(seed)
    total_holders = 0
    total_recipient = 0
    dust = 0

    for i in range(swaps):
        fee_sol = max(0.0, rng.gauss(mean_fee_sol, mean_fee_sol * 0.6))
        lamports = int(fee_sol * 1_000_000_000)
        result = split_fee(lamports)
        total_holders += result.to_holders
        total_recipient += result.to_recipient
        dust += result.to_recipient - result.to_holders  # <=1 lamport per swap

    print(f"swaps simulated:      {swaps}")
    print(f"total fees (SOL):     {(total_holders + total_recipient) / 1e9:.6f}")
    print(f"→ holders   (SOL):    {total_holders / 1e9:.6f}  ({total_holders / (total_holders + total_recipient):.4%})")
    print(f"→ recipient (SOL):    {total_recipient / 1e9:.6f}  ({total_recipient / (total_holders + total_recipient):.4%})")
    print(f"cumulative dust (lamports, favors recipient by design): {dust}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simulate PAIDBALL's 50/50 fee split.")
    parser.add_argument("--swaps", type=int, default=1000)
    parser.add_argument("--mean-fee", type=float, default=0.35, help="mean fee per swap, in SOL")
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    run(args.swaps, args.mean_fee, args.seed)
