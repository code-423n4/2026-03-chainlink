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

*See [scope.txt](https://github.com/code-423n4/2026-03-chainlink/blob/main/scope.txt)*

### Files in scope


| File   | Logic Contracts | Interfaces | nSLOC | Purpose | Libraries used |
| ------ | --------------- | ---------- | ----- | -----   | ------------ |
| /src/AuctionBidder.sol | 1| **** | 103 | |@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol<br>src/interfaces/IAuctionBidder.sol<br>src/interfaces/IAuctionCallback.sol<br>src/interfaces/IBaseAuction.sol<br>src/Caller.sol<br>src/PausableWithAccessControl.sol<br>src/libraries/Common.sol<br>src/libraries/Errors.sol<br>src/libraries/Roles.sol<br>@openzeppelin/contracts/interfaces/IERC20.sol<br>@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol<br>@openzeppelin/contracts/utils/introspection/IERC165.sol|
| /src/BaseAuction.sol | 1| **** | 420 | |@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol<br>src/interfaces/IAuctionCallback.sol<br>src/interfaces/IBaseAuction.sol<br>src/interfaces/IFeeAggregator.sol<br>src/Caller.sol<br>src/PriceManager.sol<br>src/libraries/Common.sol<br>src/libraries/Errors.sol<br>src/libraries/Roles.sol<br>@openzeppelin/contracts/interfaces/IERC20Metadata.sol<br>@openzeppelin/contracts/token/ERC20/IERC20.sol<br>@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol<br>@openzeppelin/contracts/utils/introspection/IERC165.sol<br>@openzeppelin/contracts/utils/structs/EnumerableSet.sol<br>solady/src/utils/FixedPointMathLib.sol|
| /src/Caller.sol | 1| **** | 33 | |src/libraries/Errors.sol|
| /src/GPV2CompatibleAuction.sol | 1| **** | 104 | |src/interfaces/IGPV2Settlement.sol<br>src/BaseAuction.sol<br>src/libraries/Errors.sol<br>@cowprotocol/libraries/GPv2Order.sol<br>@openzeppelin/contracts/interfaces/IERC1271.sol<br>@openzeppelin/contracts/token/ERC20/IERC20.sol<br>@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol|
| /src/PriceManager.sol | 1| **** | 227 | |@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol<br>@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol<br>src/interfaces/IPriceManager.sol<br>src/EmergencyWithdrawer.sol<br>src/LinkReceiver.sol<br>src/PausableWithAccessControl.sol<br>src/libraries/Errors.sol<br>src/libraries/Roles.sol<br>@openzeppelin/contracts/utils/introspection/IERC165.sol<br>@openzeppelin/contracts/utils/math/SafeCast.sol<br>@openzeppelin/contracts/utils/structs/EnumerableSet.sol|
| /src/WorkflowRouter.sol | 1| **** | 125 | |@chainlink/contracts/src/v0.8/keystone/interfaces/IReceiver.sol<br>@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol<br>src/interfaces/IAuctionBidder.sol<br>src/interfaces/IBaseAuction.sol<br>src/interfaces/IPriceManager.sol<br>src/Caller.sol<br>src/PausableWithAccessControl.sol<br>src/libraries/Errors.sol<br>src/libraries/Roles.sol|
| /src/interfaces/IAuctionBidder.sol | ****| 1 | 4 | |src/Caller.sol|
| /src/interfaces/IAuctionCallback.sol | ****| 1 | 3 | ||
| /src/interfaces/IBaseAuction.sol | ****| 1 | 3 | ||
| /src/interfaces/IGPV2Settlement.sol | ****| 1 | 6 | |@cowprotocol/interfaces/IERC20.sol<br>@cowprotocol/libraries/GPv2Interaction.sol<br>@cowprotocol/libraries/GPv2Trade.sol|
| /src/interfaces/IPriceManager.sol | ****| 1 | 3 | ||
| /src/libraries/Errors.sol | 1| **** | 15 | ||
| /src/libraries/Roles.sol | 1| **** | 15 | ||
| **Totals** | **8** | **5** | **1061** | | |

### Files out of scope

*See [out_of_scope.txt](https://github.com/code-423n4/2026-03-chainlink/blob/main/out_of_scope.txt)*

| File         |
| ------------ |
| ./src/EmergencyWithdrawer.sol |
| ./src/FeeAggregator.sol |
| ./src/LinkReceiver.sol |
| ./src/NativeTokenReceiver.sol |
| ./src/PausableWithAccessControl.sol |
| ./src/interfaces/IFeeAggregator.sol |
| ./src/interfaces/IFeeWithdrawer.sol |
| ./src/interfaces/ILinkAvailable.sol |
| ./src/interfaces/IPausable.sol |
| ./src/libraries/Common.sol |
| ./src/libraries/EnumerableBytesSet.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/interfaces/GPv2Authentication.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/interfaces/GPv2EIP1271.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/interfaces/IERC20.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/libraries/GPv2Interaction.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/libraries/GPv2Order.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/libraries/GPv2Trade.sol |
| ./src/vendor/@cowprotocol/contracts/src/contracts/mixins/GPv2Signing.sol |
| ./test/Addresses.t.sol |
| ./test/BaseTest.t.sol |
| ./test/Constants.t.sol |
| ./test/fork/BaseForkTest.t.sol |
| ./test/fork/auction-bidder/bid/bid.t.sol |
| ./test/fork/gpv2-compatible-auction/is-valid-signature/isValidSignature.t.sol |
| ./test/fork/price-manager/BasePriceManagerForkTest.t.sol |
| ./test/fork/price-manager/transmit/transmit.t.sol |
| ./test/fork/workflow-router/on-report/onReport.t.sol |
| ./test/helpers/PriceManagerHelper.t.sol |
| ./test/integration/BaseIntegrationTest.t.sol |
| ./test/integration/auction-bidder/withdraw/withdraw.t.sol |
| ./test/integration/base-auction/bid/bid.t.sol |
| ./test/integration/base-auction/perform-upkeep/performUpkeep.t.sol |
| ./test/integration/emergency-withdrawer/emergency-withdraw/emergencyWithdraw.t.sol |
| ./test/integration/emergency-withdrawer/emergency-withdraw-native/emergencyWithdrawNative.t.sol |
| ./test/integration/gpv2-compatible-auction/is-valid-signature/isValidSignature.t.sol |
| ./test/integration/gpv2-compatible-auction/perform-upkeep/performUpkeep.t.sol |
| ./test/integration/link-receiver/on-token-transfer/onTokenTransfer.t.sol |
| ./test/integration/workflow-router/onReport.t.sol |
| ./test/mocks/MockAggregatorV3.sol |
| ./test/mocks/MockERC20.sol |
| ./test/mocks/MockGPV2Settlement.sol |
| ./test/mocks/MockLinkToken.sol |
| ./test/mocks/MockUniswapQuoterV2.sol |
| ./test/mocks/MockUniswapRouter.sol |
| ./test/mocks/MockVerifierProxy.sol |
| ./test/mocks/MockWrappedNative.sol |
| ./test/unit/BaseUnitTest.t.sol |
| ./test/unit/auction-bidder/auction-callback/auctionCallback.t.sol |
| ./test/unit/auction-bidder/constructor/constructor.t.sol |
| ./test/unit/auction-bidder/set-auction/setAuction.t.sol |
| ./test/unit/auction-bidder/set-receiver/setReceiver.sol |
| ./test/unit/base-auction/apply-asset-params-update/applyAssetParamsUpdates.t.sol |
| ./test/unit/base-auction/check-upkeep/checkUpkeep.t.sol |
| ./test/unit/base-auction/constructor/constructor.t.sol |
| ./test/unit/base-auction/get-asset-out-amount/getAssetOutAmount.t.sol |
| ./test/unit/base-auction/set-asset-out/setAssetOut.t.sol |
| ./test/unit/base-auction/set-asset-out-receiver/setAssetOutReceiver.t.sol |
| ./test/unit/base-auction/set-fee-aggregator/setFeeAggregator.sol |
| ./test/unit/base-auction/set-min-bid-usd-value/setMinBidUsdValue.t.sol |
| ./test/unit/gpv2-compatible-auction/constructor/constructor.t.sol |
| ./test/unit/pausable-with-access-control/emergency-pause/emergencyPause.t.sol |
| ./test/unit/pausable-with-access-control/emergency-unpause/emergencyUnpause.t.sol |
| ./test/unit/pausable-with-access-control/grant-role/grantRole.t.sol |
| ./test/unit/pausable-with-access-control/revoke-role/revokeRole.t.sol |
| ./test/unit/pausable-with-access-control/supports-interface/supportsInterface.t.sol |
| ./test/unit/price-manager/apply-feed-info-updates/applyFeedInfoUpdates.t.sol |
| ./test/unit/price-manager/get-asset-price/getAssetPrice.t.sol |
| ./test/unit/price-manager/transmit/transmit.t.sol |
| ./test/unit/workflow-router/constructor/constructor.t.sol |
| ./test/unit/workflow-router/set-auction/setAuction.t.sol |
| ./test/unit/workflow-router/set-auction-bidder/setAuctionBidder.t.sol |
| ./test/unit/workflow-router/set-workflow-ids/setWorkflowIds.t.sol |
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

| Role | Description | Granted To |
|---|---|---|
| DEFAULT_ADMIN_ROLE | Owner of the contracts. Manages roles, critical configurations and can emergency withdraw assets. | Timelock |
| PAUSER_ROLE | Pauses the contract when an emergency is detected. | Monitoring |
| UNPAUSER_ROLE | Unpauses the contract when an emergency is resolved. This is separate from the PAUSER_ROLE to decouple the role. | Timelock |
| SWAPPER_ROLE | Assigned to the GPV2CompatibleAuction contract, this role allows for pulling allowlisted assets from the FeeAggregator contract when starting an auction. | GPV2CompatibleAuction |
| ASSET_ADMIN_ROLE | Configures feeds, asset parameters, minimum bid value and asset out. | Timelock |
| PRICE_ADMIN_ROLE | Transmits Streams prices to the GPV2CompatibleAuction contract. | WorkflowRouter |
| AUCTION_WORKER_ROLE | Starts and expires auctions by calling performUpkeep on the GPV2CompatibleAuction contract. | WorkflowRouter |
| AUCTION_BIDDER_ROLE | Pushes solutions to the AuctionBidder’s bid function to solve live auctions. | WorkflowRouter |
| FORWARDER_ROLE | Transmits CRE workflow payloads to the WorkflowRouter’s onReport function. | CRE forwarder |

## Running tests

TODO

## Miscellaneous

Employees of Chainlink and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.
