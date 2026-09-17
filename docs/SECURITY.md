# Security notes

PAIDBALL has not been audited. Treat everything in `contracts/` as a
reference implementation of the split mechanism, not production-ready
custody code, until an independent audit is completed and linked here.

## Invariants the contracts are designed to hold

1. **No residual balance.** `PaidballFeeRouter` never holds funds across
   transactions. Every `routeFee` call fully disburses `amount` before
   returning. A fuzz/invariant test asserting
   `balance(router) == 0` after arbitrary sequences of `routeFee` calls is in
   `test/FeeRouter.test.ts` and should be extended with Foundry invariant
   tests before mainnet use.
2. **Split is constant.** `HOLDER_BPS` / `RECIPIENT_BPS` are immutable
   contract constants, not storage — they cannot be modified by any account,
   including the deployer.
3. **Recipient reassignment is scoped.** Only a token's original
   `launchAuthority` (set once, at registration, and never transferable in
   this reference implementation) may call `setFeeRecipient`, and only for
   that token's recipient-side address — never the holder side.
4. **Vault accounting cannot be inflated by a single actor.** Reward-per-share
   accounting only increases via `notifyDeposit` / `depositNative`, both
   `onlyRouter`, and both driven by real fee volume rather than arbitrary
   caller input.

## Known limitations / open questions for an auditor

- `syncShares` in `PaidballVault` assumes a correctly wired transfer hook on
  the underlying token. A token that fails to call `syncShares` on every
  balance change will produce **stale, not wrong** share weights — rewards
  accrue correctly against whatever the last-synced balance was, but a
  holder who never triggers a sync after acquiring tokens won't see their
  new weight reflected until the next transfer. This is a UX gap, not a
  fund-safety gap: no one can claim more than the vault's cumulative
  accumulator allows.
- Native-asset payouts to the recipient use a raw `.call{value:}` — this is
  intentional (max compatibility with contract recipients, including ones
  with non-trivial `receive()` logic) but means a recipient contract that
  reverts on receipt will revert the entire `routeFee` call. Production
  deployments should consider a pull-based fallback for the recipient side
  as well, or require recipients to be EOAs / simple forwarders.
- Integer division in the split favors the recipient by at most 1 wei /
  lamport per call (see `scripts/simulate_fees.py`). This is deliberate and
  documented, not a bug.

## Reporting

If you find an issue, do not open a public GitHub issue. See
`CONTRIBUTING.md` for a disclosure channel.
