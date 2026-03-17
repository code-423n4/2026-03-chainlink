# Chainlink Payment Abstraction V2 audit details

- Total Prize Pool: $65,000 in USDC
  - HM awards: up to $57,600 in USDC
    - If no valid Highs or Mediums are found, the HM pool is $0
  - QA awards: $2,400 in USDC
  - Judge awards: $4,500 in USDC
  - Scout awards: $500 USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts March 18, 2026 20:00 UTC
- Ends March 27, 2026 20:00 UTC

### ❗ Important notes for wardens

1. A coded, runnable PoC is required for all High/Medium submissions to this audit.
   - This repo includes a basic template to run the test suite.
   - PoCs must use the test suite provided in this repo.
   - Your submission will be marked as Insufficient if the POC is not runnable and working with the provided test suite.
   - Exception: PoC is optional (though recommended) for wardens with signal ≥ 0.4.
2. Judging phase risk adjustments (upgrades/downgrades):
   - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
   - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
   - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## V12 findings

[V12](https://v12.zellic.io/) is [Zellic](https://zellic.io)'s in-house AI auditing tool. It is the only autonomous Solidity auditor that [reliably finds Highs and Criticals](https://www.zellic.io/blog/introducing-v12/). All issues found by V12 will be judged as out of scope and ineligible for awards.

V12 findings will typically be posted in this section within the first two days of the competition.

## Publicly known issues

_Anything included in this section is considered a publicly known issue and is therefore ineligible for awards._

- The auction contract is not designed to support non-canonical ERC20s such as:
  - Fee on transfer tokens
  - Rebasing tokens
  - Non approve 0 tokens (e.g. BNB)
- Arbitrary deposits of auctioned assets to the auction contract during live auctions: the auction contract relies on balance reading to determine the available auctioned amount, but the amount approval to the CowSwap settlement contract is done at auction start (in performUpkeep). Therefore, if additional auctioned assets are deposited in the contract during an auction, those assets won’t be made available to the CowSwap solvers (only participants calling the bid function). This is acceptable since such deposits would not be performed by us and therefore be a net positive even if swapped at the lower end of the auction curve.
- Asynchronous order updates on the CowSwap API: since auctions are relayed off-chain to the CowSwap API through periodic updates of limit orders:
  - Orders posted on the CowSwap order book will always have a higher price than the on-chain auction value (since the price decays per second). This may delay slightly the auction fills but this is an acceptable tradeoff as the on-chain price invariant can’t be broken.
  - Concurrent participants (CowSwap solvers and independent bidders) will both affect auctioned asset balances on the contract. Therefore, when a non CowSwap solver bids on the auction, the limit order quantity becomes stale on the CowSwap orderbook until the next workflow run. This may lead to failed orders attempted by solvers trying to fill 100% of the order during that time window.

# Overview

Payment Abstraction is a system of onchain smart contracts that aim to reduce payment friction for Chainlink services. The system is designed to (1) accept fees in various tokens across multiple blockchain networks, (2) consolidate fee tokens onto a single blockchain network via Chainlink CCIP, (3) convert fee tokens into LINK and (4) pass converted LINK into a dedicated contract for withdrawal by Chainlink Network service providers.

While Payment Abstraction V1 uses Uniswap V3 for executing fee-to-LINK conversions, V2 implements a permissionless dutch auction mechanism where any participant can bid on auctioned allowlisted assets.

The goal of Payment Abstraction V2 is to replace the current Payment Abstraction V1 system by:

- Implementing a permissionless dutch auction mechanism where any participant can bid on auctioned allowlisted assets. This model improves flexibility and resiliency by supporting multiple liquidity venues.
- Integrating with CowSwap to relay auctions to the protocol’s solvers to ensure sufficient participation.
- Building a backward and forward compatible solution allowing to integrate with multiple liquidity venues.

# Chainlink Payment Abstraction V2 Audit Catalyst

This project includes an [Audit Catalyst](https://github.com/code-423n4/2026-03-chainlink/blob/main/catalyst.md) prepared by [Zellic](https://www.zellic.io/). This is an essential read for accelerating your work as an auditor and using your time most effectively in contributing to the security of the project.

## Links

- **Previous audits:** N/A
- **Documentation:** https://github.com/code-423n4/2026-03-chainlink/blob/main/payment_abstraction_v2.pdf
- **Website:** https://chain.link/
- **X/Twitter:** https://x.com/chainlink

# Scope

_See [scope.txt](https://github.com/code-423n4/2026-03-chainlink/blob/main/scope.txt)_

### Files in scope

| File | nSLOC |
| ------------------------------------ | -------- |
| [src/AuctionBidder.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/AuctionBidder.sol) | 103 |
| [src/BaseAuction.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/BaseAuction.sol) | 420 |
| [src/Caller.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/Caller.sol) | 33 |
| [src/GPV2CompatibleAuction.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/GPV2CompatibleAuction.sol) | 104 |
| [src/PriceManager.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/PriceManager.sol) | 227 |
| [src/WorkflowRouter.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/WorkflowRouter.sol) | 125 |
| [src/interfaces/IAuctionBidder.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IAuctionBidder.sol) | 4 |
| [src/interfaces/IAuctionCallback.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IAuctionCallback.sol) | 3 |
| [src/interfaces/IBaseAuction.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IBaseAuction.sol) | 3 |
| [src/interfaces/IGPV2Settlement.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IGPV2Settlement.sol) | 6 |
| [src/interfaces/IPriceManager.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IPriceManager.sol) | 3 |
| [src/libraries/Errors.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/libraries/Errors.sol) | 15 |
| [src/libraries/Roles.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/libraries/Roles.sol) | 15 |
| **Totals** | **1061** |

### Files out of scope

_See [out_of_scope.txt](https://github.com/code-423n4/2026-03-chainlink/blob/main/out_of_scope.txt)_

| File |
| --- |
| [src/EmergencyWithdrawer.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/EmergencyWithdrawer.sol) |
| [src/FeeAggregator.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/FeeAggregator.sol) |
| [src/LinkReceiver.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/LinkReceiver.sol) |
| [src/NativeTokenReceiver.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/NativeTokenReceiver.sol) |
| [src/PausableWithAccessControl.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/PausableWithAccessControl.sol) |
| [src/interfaces/IFeeAggregator.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IFeeAggregator.sol) |
| [src/interfaces/IFeeWithdrawer.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IFeeWithdrawer.sol) |
| [src/interfaces/ILinkAvailable.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/ILinkAvailable.sol) |
| [src/interfaces/IPausable.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/interfaces/IPausable.sol) |
| [src/libraries/Common.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/libraries/Common.sol) |
| [src/libraries/EnumerableBytesSet.sol](https://github.com/code-423n4/2026-03-chainlink/blob/main/src/libraries/EnumerableBytesSet.sol) |
| [src/vendor/\*\*.\*\*](https://github.com/code-423n4/2026-03-chainlink/tree/main/src/vendor) |
| [test/\*\*.\*\*](https://github.com/code-423n4/2026-03-chainlink/tree/main/test) |
| Totals: 72 |

# Additional context

## Areas of concern (where to focus for bugs)

- Any vector that may break the systems' invariant (auction curve). No bid should ever result in higher slippage than the set threshold
- The auction contract will hold funds during auctions, which therefore represent value at risk
- Rounding operations
- Any vector that may block auction participation

### Questions to answer:

- Are there any user provided inputs that could result in unexpected behaviors/fund loss?
- Are there any race conditions that could result in sustained DoS?
- Are access controls implemented effectively to prevent unauthorized operations?

## Trusted roles in the protocol

| Role                | Description                                                                                                                                               | Granted To            |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| DEFAULT_ADMIN_ROLE  | Owner of the contracts. Manages roles, critical configurations and can emergency withdraw assets.                                                         | Timelock              |
| PAUSER_ROLE         | Pauses the contract when an emergency is detected.                                                                                                        | Monitoring            |
| UNPAUSER_ROLE       | Unpauses the contract when an emergency is resolved. This is separate from the PAUSER_ROLE to decouple the role.                                          | Timelock              |
| SWAPPER_ROLE        | Assigned to the GPV2CompatibleAuction contract, this role allows for pulling allowlisted assets from the FeeAggregator contract when starting an auction. | GPV2CompatibleAuction |
| ASSET_ADMIN_ROLE    | Configures feeds, asset parameters, minimum bid value and asset out.                                                                                      | Timelock              |
| PRICE_ADMIN_ROLE    | Transmits Streams prices to the GPV2CompatibleAuction contract.                                                                                           | WorkflowRouter        |
| AUCTION_WORKER_ROLE | Starts and expires auctions by calling performUpkeep on the GPV2CompatibleAuction contract.                                                               | WorkflowRouter        |
| AUCTION_BIDDER_ROLE | Pushes solutions to the AuctionBidder’s bid function to solve live auctions.                                                                              | WorkflowRouter        |
| FORWARDER_ROLE      | Transmits CRE workflow payloads to the WorkflowRouter’s onReport function.                                                                                | CRE forwarder         |

## Running tests

The codebase utilizes a `foundry` installation to compile the codebase and run tests. As such, `foundry` is expected to be installed and specifically at version `v1.5.0`.

### Pre-requisites

- [pnpm](https://pnpm.io/installation)
- [foundry](https://book.getfoundry.sh/getting-started/installation)
- Create an `.env` file, following the `.env.example` (some tests will fail without a configured mainnet RPC)

### Build

```shell
$ # The below command can be skipped if foundry has been installed at the appropriate version
$ pnpm foundry
$ # Install dependencies of the project
$ pnpm install
$ # Compile all contracts
$ forge build
```

### Test

**Run all tests:**

```shell
$ forge test
```

## Miscellaneous

Employees of Chainlink and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.
