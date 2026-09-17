# Contributing

PAIDBALL is small on purpose. Before adding a file, ask whether the idea can
be expressed as a smaller change to an existing one.

## Local setup

```bash
npm install
npm run compile
npm test
npm run simulate -- --swaps 5000 --mean-fee 0.5
```

## Pull requests

- One concern per PR. A PR that touches `PaidballFeeRouter.sol` and the
  README styling at the same time will be asked to split.
- New behavior needs a test in `test/`. New contract invariants belong in
  `docs/SECURITY.md`, not just a comment.
- Solidity: match the existing NatSpec style — every external function gets
  a `@notice`, every non-obvious internal one gets a `@dev`.

## Security disclosures

Do not open a public issue for a vulnerability. Email
`security@paidball.dev` (placeholder — replace with a real monitored
address before mainnet deployment) with a description and, if possible, a
proof of concept.
