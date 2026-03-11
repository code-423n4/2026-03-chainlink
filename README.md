# Chainlink Payment Abstraction V2 audit details
- Total Prize Pool: $65,000 in USDC
    - HM awards: up to $57,600 in USDC
        - If no valid Highs or Mediums are found, the HM pool is $0
    - QA awards: $2,400 in USDC
    - Judge awards: $4,500 in USDC
    - Scout awards: $500 USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts March 16, 2026 20:00 UTC
- Ends March 26, 2026 20:00 UTC

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

## V12 findings (🐺 C4 staff: remove this section for non-Solidity/EVM audits)

[V12](https://v12.zellic.io/) is [Zellic](https://zellic.io)'s in-house AI auditing tool. It is the only autonomous Solidity auditor that [reliably finds Highs and Criticals](https://www.zellic.io/blog/introducing-v12/). All issues found by V12 will be judged as out of scope and ineligible for awards.

V12 findings will typically be posted in this section within the first two days of the competition.  

## Publicly known issues

_Anything included in this section is considered a publicly known issue and is therefore ineligible for awards._

## 🐺 C4: Begin Gist paste here (and delete this line)





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

