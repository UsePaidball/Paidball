# Why 50/50

Most fee-on-transfer or fee-on-swap token launches route close to 100% of the
fee to whoever launched the token, or to a treasury the trading public has no
claim on. Holders take on all the volatility and get none of the fee upside
that their own trading activity created.

PAIDBALL's position: **the trading activity itself is the product, and the
people generating it should own half of what it produces.**

```
                 every swap
                     │
                     ▼
        ┌─────────────────────────┐
        │        fee (100%)       │
        └────────────┬────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
  ┌───────────┐               ┌───────────┐
  │  50%      │               │  50%      │
  │  HOLDERS  │               │ RECIPIENT │
  └───────────┘               └───────────┘
   pro-rata,                   fixed address,
   pull-based,                 set at launch,
   O(1) claim                  re-assignable by
                                launch authority
```

This isn't a governance parameter that can drift over time or get voted down
by whoever accumulates the most tokens later — it's fixed at the contract
level for every token that registers with a given router version.

## What this does and doesn't change

**Doesn't change:** how the token launches, how the bonding curve or AMM
prices trades, how PAID / UsePaid's infrastructure captures the fee in the
first place.

**Changes:** what happens to the fee the moment it's captured. Instead of one
destination, there are two, in a fixed, auditable ratio.

## Second-order effect

Because the split is public and enforced in the contract holders can verify
independently (see `docs/SECURITY.md`), holding the token is no longer purely
a directional bet — it's a claim on half of the fee stream that trading
volume generates, for as long as the token exists. Recipients still get a
predictable, undiluted 50% regardless of holder count or distribution.
