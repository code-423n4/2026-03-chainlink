// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AuctionBidder} from "src/AuctionBidder.sol";
import {BaseAuction} from "src/BaseAuction.sol";
import {FeeAggregator} from "src/FeeAggregator.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";
import {PriceManager} from "src/PriceManager.sol";
import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Roles} from "src/libraries/Roles.sol";
import {Mainnet} from "test/Addresses.t.sol";
import {BaseTest} from "test/BaseTest.t.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract BaseForkTest is BaseTest, Mainnet {
  FeeAggregator internal s_feeAggregator;
  WorkflowRouter internal s_workflowRouter;
  GPV2CompatibleAuction internal s_auction;
  AuctionBidder internal s_auctionBidder;

  constructor(
    uint256 blockNumber
  ) {
    string memory rpc = vm.envOr("MAINNET_RPC_URL", vm.envOr("GENERIC_SECRET_1", string("")));

    vm.createSelectFork(rpc, blockNumber);

    // ================================================================================================
    // │                                          Deployment                                          │
    // ================================================================================================

    s_feeAggregator = new FeeAggregator(
      FeeAggregator.ConstructorParams({
        adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
        admin: i_owner,
        linkToken: LINK,
        ccipRouterClient: CCIP_ROUTER,
        wrappedNativeToken: WETH
      })
    );

    GPV2CompatibleAuction.ConstructorParams memory params = BaseAuction.ConstructorParams({
      adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
      admin: i_owner,
      minPriceMultiplier: MIN_PRICE_MULTIPLIER,
      verifierProxy: VERIFIER_PROXY,
      minBidUsdValue: MIN_BID_USD_VALUE,
      linkToken: LINK,
      assetOut: LINK,
      assetOutReceiver: i_receiver,
      feeAggregator: address(s_feeAggregator),
      feedInfos: new PriceManager.ApplyFeedInfoUpdateParams[](3)
    });

    params.feedInfos[0] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: LINK,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: LINK_USD_FEED_ID,
        usdDataFeed: AggregatorV3Interface(LINK_USD_FEED),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: STALENESS_THRESHOLD
      })
    });
    params.feedInfos[1] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: WETH,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: ETH_USD_FEED_ID,
        usdDataFeed: AggregatorV3Interface(ETH_USD_FEED),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: STALENESS_THRESHOLD
      })
    });
    params.feedInfos[2] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: USDC,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: USDC_USD_FEED_ID,
        usdDataFeed: AggregatorV3Interface(USDC_USD_FEED),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: STALENESS_THRESHOLD
      })
    });

    s_auction = new GPV2CompatibleAuction(params, GP_V2_VAULT_RELAYER, GP_V2_SETTLEMENT);

    s_auctionBidder = new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), address(s_auction));

    s_workflowRouter = new WorkflowRouter(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner);

    // ================================================================================================
    // │                                        Role Granting                                         │
    // ================================================================================================

    s_feeAggregator.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);
    s_feeAggregator.grantRole(Roles.WITHDRAWER_ROLE, i_withdrawer);
    s_feeAggregator.grantRole(Roles.SWAPPER_ROLE, address(s_auction));
    s_auction.grantRole(Roles.PRICE_ADMIN_ROLE, i_priceAdmin);
    s_auction.grantRole(Roles.PRICE_ADMIN_ROLE, address(s_workflowRouter));
    s_workflowRouter.grantRole(Roles.FORWARDER_ROLE, i_forwarder);
    s_auction.grantRole(Roles.FORWARDER_ROLE, i_forwarder);
    s_auction.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);
    s_auction.grantRole(Roles.AUCTION_WORKER_ROLE, address(s_workflowRouter));
    s_auction.grantRole(Roles.AUCTION_WORKER_ROLE, i_auctionAdmin);
    s_auction.grantRole(Roles.ORDER_MANAGER_ROLE, address(s_workflowRouter));
    s_auctionBidder.grantRole(Roles.PAUSER_ROLE, i_pauser);
    s_auctionBidder.grantRole(Roles.AUCTION_BIDDER_ROLE, i_auctionBidder);
    s_auctionBidder.grantRole(Roles.AUCTION_BIDDER_ROLE, address(s_workflowRouter));

    // ================================================================================================
    // │                                        Configuration                                         │
    // ================================================================================================

    address[] memory assets = new address[](3);
    assets[0] = WETH;
    assets[1] = USDC;
    assets[2] = LINK;

    _changePrank(i_assetAdmin);
    s_feeAggregator.applyAllowlistedAssetUpdates(new address[](0), assets);

    BaseAuction.ApplyAssetParamsUpdate[] memory assetParamsUpdates = new BaseAuction.ApplyAssetParamsUpdate[](3);
    // +10% -> -2%
    assetParamsUpdates[0] = BaseAuction.ApplyAssetParamsUpdate({
      asset: WETH,
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.1e18, // 10% starting premium
        endingPriceMultiplier: 0.98e18, // 2% maximum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    // +5% -> -1%
    assetParamsUpdates[1] = BaseAuction.ApplyAssetParamsUpdate({
      asset: USDC,
      params: BaseAuction.AssetParams({
        decimals: 6,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.05e18, // 5% starting premium
        endingPriceMultiplier: 0.99e18, // 1% maximum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    assetParamsUpdates[2] = BaseAuction.ApplyAssetParamsUpdate({
      asset: LINK,
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1,
        startingPriceMultiplier: 1e18,
        endingPriceMultiplier: 1e18,
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });

    s_auction.applyAssetParamsUpdates(assetParamsUpdates, new address[](0));

    _changePrank(i_owner);

    WorkflowRouter.AllowlistedWorkflow[] memory adds = new WorkflowRouter.AllowlistedWorkflow[](3);
    adds[0].workflowId = PRICE_ADMIN_WORKFLOW_ID;
    adds[0].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[0].targetSelectors[0].target = address(s_auction);
    adds[0].targetSelectors[0].selectors = new bytes4[](1);
    adds[0].targetSelectors[0].selectors[0] = s_auction.transmit.selector;

    adds[1].workflowId = AUCTION_WORKER_WORKFLOW_ID;
    adds[1].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[1].targetSelectors[0].target = address(s_auction);
    adds[1].targetSelectors[0].selectors = new bytes4[](2);
    adds[1].targetSelectors[0].selectors[0] = s_auction.performUpkeep.selector;
    adds[1].targetSelectors[0].selectors[1] = s_auction.invalidateOrders.selector;

    adds[2].workflowId = AUCTION_BIDDER_WORKFLOW_ID;
    adds[2].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[2].targetSelectors[0].target = address(s_auctionBidder);
    adds[2].targetSelectors[0].selectors = new bytes4[](1);
    adds[2].targetSelectors[0].selectors[0] = s_auctionBidder.bid.selector;

    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), adds);

    s_commonContracts[CommonContracts.PRICE_MANAGER].push(address(s_auction));

    vm.label(address(s_feeAggregator), "FeeAggregator");
    vm.label(address(s_auction), "Auction");
    vm.label(address(s_auctionBidder), "AuctionBidder");
    vm.label(address(s_workflowRouter), "WorkflowRouter");
    vm.label(CCIP_ROUTER, "CCIP Router");
    vm.label(LINK, "LINK");
    vm.label(WETH, "WETH");
    vm.label(USDC, "USDC");
    vm.label(LINK_USD_FEED, "LINK/USD Feed");
    vm.label(ETH_USD_FEED, "ETH/USD Feed");
    vm.label(USDC_USD_FEED, "USDC/USD Feed");
  }

  function test_baseForkTest() public {}
}
