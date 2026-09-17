# Architecture

PAIDBALL is a thin, immutable layer that sits between a token's trading
activity and its fee destinations. It does not replace PAID / UsePaid's
launch infrastructure — it intercepts the single value that infrastructure
already produces (the fee) and enforces a different distribution on it.

```
                    ┌─────────────┐
   swap tx  ───────▶│  PAID INFRA │  (launch, bonding curve / AMM hook, fee capture)
                    └──────┬──────┘
                           │  100% of fee
                           ▼
                  ┌────────────────────┐
                  │ PaidballFeeRouter  │  stateless, per-tx, no custody
                  └─────────┬──────────┘
                50%         │         50%
                 ▼                     ▼
        ┌─────────────────┐   ┌───────────────────┐
        │ PaidballVault   │   │  Fee Recipient EOA │
        │ (pull, pro-rata)│   │  or contract        │
        └─────────────────┘   └───────────────────┘
```

## Components

### `PaidballFeeRouter`
The only contract that ever touches an in-flight fee. `routeFee` computes the
split once, forwards 50% to the vault (or directly to a holder, for the
native-asset path) and 50% to the registered recipient, and emits `FeeSplit`.
It holds no balance between transactions — every unit of value that enters a
call either leaves as part of the holder share or the recipient share before
the call returns. There is nothing to drain because there is nothing to hold.

### `PaidballVault`
Holder-side payouts are **pull-based**, not push-based. Pushing a payment to
every holder on every swap is O(holders) and gets more expensive — and more
fragile — as a token grows. Instead the vault keeps a single running
accumulator (`rewardPerShareStored`), the same pattern used by mainstream
staking-reward contracts:

```
rewardPerShare += depositAmount * 1e18 / totalShares
pending(holder) = shares(holder) * (rewardPerShare - rewardDebt(holder)) / 1e18
```

Claiming is O(1) regardless of deposit count or holder count. Share balances
are kept in sync with the underlying token's actual balances via a
`syncShares` hook, which in production is wired to the token's transfer path
so it updates automatically — holders never need to "register."

### Fee recipient
A single address designated at token registration. It can be reassigned by
the token's launch authority (e.g. to a multisig or a new treasury), but it
can never claim more than its fixed 50%, and it can never be pointed at the
holder share — that path is hardcoded to the vault.

## Why 50/50 is enforced in code, not policy

`HOLDER_BPS` and `RECIPIENT_BPS` are `constant`s. There is no setter, no
timelocked governance vote, no admin override that can move the split for an
already-registered token. If PAIDBALL ever needs a different ratio for a new
cohort of tokens, that ships as a new router version — existing tokens keep
the split they launched with, permanently.

## Trust assumptions

- PAIDBALL trusts the PAID / UsePaid fee hook to call `routeFee` with the
  correct amount. It does not re-derive fees from swap data itself.
- PAIDBALL does **not** trust any off-chain indexer for the split itself —
  everything above the fee-hook boundary is on-chain and reproducible from
  event logs.
- Share tracking for the holder vault does rely on a transfer hook being
  wired correctly at token deployment; see `contracts/PaidballVault.sol` for
  the sync interface a token integrates against.
