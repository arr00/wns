# WNS
This is a fork of [Compound Governance](https://github.com/compound-finance/compound-governance/). Note all commits made prior to 3/16 are from that repo.

WNS provides a registry for validating ENS addresses. Each individual can only do this once as it requires worldcoin proofs. The governance system itself uses ENS nodes for all accounting and delegation. You delegate to `cool.eth`, not the address `cool.eth` resolves to. This means that if you transfer an ENS address, the delegation would actually transfer with it.

## Running
### Setup
- `npm install`
### Tests
- `npm test`
### Coverage
- `npm run coverage`

