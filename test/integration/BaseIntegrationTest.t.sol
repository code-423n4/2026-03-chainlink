// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AuctionBidder} from "src/AuctionBidder.sol";
import {BaseAuction} from "src/BaseAuction.sol";
import {FeeAggregator} from "src/FeeAggregator.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";
import {PriceManager} from "src/PriceManager.sol";
import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseTest} from "test/BaseTest.t.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGPV2Settlement} from "test/mocks/MockGPV2Settlement.sol";
import {MockLinkToken} from "test/mocks/MockLinkToken.sol";
import {MockUniswapQuoterV2} from "test/mocks/MockUniswapQuoterV2.sol";
import {MockUniswapRouter} from "test/mocks/MockUniswapRouter.sol";
import {MockVerifierProxy} from "test/mocks/MockVerifierProxy.sol";
import {MockWrappedNative} from "test/mocks/MockWrappedNative.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// @notice Base contract for integration tests. Tests the interactions between multiple contracts in a simulated
// environment.
abstract contract BaseIntegrationTest is BaseTest {
  bytes32 internal immutable i_mockWETHFeedId = _generateDataStreamsFeedId("MockWETH");
  bytes32 internal immutable i_mockUSDCFeedId = _generateDataStreamsFeedId("MockUSDC");
  bytes32 internal immutable i_mockLINKFeedId = _generateDataStreamsFeedId("MockLINK");

  FeeAggregator internal s_feeAggregator;
  WorkflowRouter internal s_workflowRouter;
  GPV2CompatibleAuction internal s_auction;
  AuctionBidder internal s_auctionBidder;

  MockWrappedNative internal s_mockWETH;
  MockLinkToken internal s_mockLINK;
  MockERC20 internal s_mockUSDC;
  MockERC20 internal s_mockWBTC;

  MockAggregatorV3 internal s_mockWethUsdFeed;
  MockAggregatorV3 internal s_mockUsdcUsdFeed;
  MockAggregatorV3 internal s_mockLinkUsdFeed;

  MockUniswapRouter internal s_mockUniswapRouter;
  MockUniswapQuoterV2 internal s_mockUniswapQuoterV2;

  MockVerifierProxy internal s_mockStreamsVerifierProxy;
  MockGPV2Settlement internal s_mockGPV2Settlement;

  address internal s_gpV2VaultRelayer = makeAddr("GPV2VaultRelayer");
  address internal s_reserves = makeAddr("Reserves");
  address internal s_authority;
  uint256 internal s_authorityPk;

  address[] internal s_serviceProviders;
  address[] internal s_paymentRequestSigners;

  modifier givenAssetIsAllowlisted(
    address asset
  ) {
    (, address msgSender,) = vm.readCallers();

    address[] memory assets = new address[](1);
    assets[0] = asset;

    _changePrank(i_assetAdmin);
    s_feeAggregator.applyAllowlistedAssetUpdates(new address[](0), assets);
    _changePrank(msgSender);
    _;
  }

  constructor() {
    // Increment block.timestamp to avoid underflows
    skip(1 weeks);

    // ================================================================================================
    // │                                          Deployment                                          │
    // ================================================================================================

    s_mockWETH = new MockWrappedNative();
    s_mockLINK = new MockLinkToken();
    s_mockUSDC = new MockERC20("USDC", "USDC", 6);
    s_mockWBTC = new MockERC20("WBTC", "WBTC", 8);

    s_mockLinkUsdFeed = new MockAggregatorV3();
    s_mockWethUsdFeed = new MockAggregatorV3();
    s_mockUsdcUsdFeed = new MockAggregatorV3();

    s_mockLinkUsdFeed.transmit(20e8);
    s_mockWethUsdFeed.transmit(4_000e8);
    s_mockUsdcUsdFeed.transmit(1e8);

    s_mockUniswapRouter = new MockUniswapRouter(address(s_mockLINK));
    s_mockUniswapQuoterV2 = new MockUniswapQuoterV2();

    s_feeAggregator = new FeeAggregator(
      FeeAggregator.ConstructorParams({
        adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
        admin: i_owner,
        linkToken: address(s_mockLINK),
        ccipRouterClient: i_mockCCIPRouterClient,
        wrappedNativeToken: address(s_mockWETH)
      })
    );

    s_mockStreamsVerifierProxy = new MockVerifierProxy();

    PriceManager.ApplyFeedInfoUpdateParams[] memory feedInfos = new PriceManager.ApplyFeedInfoUpdateParams[](3);
    feedInfos[0] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: address(s_mockWETH),
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_mockWETHFeedId,
        usdDataFeed: AggregatorV3Interface(s_mockWethUsdFeed),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: 1 hours
      })
    });
    feedInfos[1] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: address(s_mockUSDC),
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_mockUSDCFeedId,
        usdDataFeed: AggregatorV3Interface(s_mockUsdcUsdFeed),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: 1 hours
      })
    });
    feedInfos[2] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: address(s_mockLINK),
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_mockLINKFeedId,
        usdDataFeed: AggregatorV3Interface(s_mockLinkUsdFeed),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: 1 hours
      })
    });

    s_mockGPV2Settlement = new MockGPV2Settlement();

    GPV2CompatibleAuction.ConstructorParams memory params = BaseAuction.ConstructorParams({
      adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
      admin: i_owner,
      minPriceMultiplier: MIN_PRICE_MULTIPLIER,
      verifierProxy: address(s_mockStreamsVerifierProxy),
      minBidUsdValue: MIN_BID_USD_VALUE,
      linkToken: address(s_mockLINK),
      assetOut: address(s_mockLINK),
      assetOutReceiver: s_reserves,
      feeAggregator: address(s_feeAggregator),
      feedInfos: feedInfos
    });

    s_auction = new GPV2CompatibleAuction(params, s_gpV2VaultRelayer, address(s_mockGPV2Settlement));
    s_auctionBidder = new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), address(s_auction));
    s_auctionBidder = new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), address(s_reserves));
    s_workflowRouter = new WorkflowRouter(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner);

    // ================================================================================================
    // │                                        Role Granting                                         │
    // ================================================================================================

    s_feeAggregator.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);
    s_feeAggregator.grantRole(Roles.SWAPPER_ROLE, address(s_auction));
    s_auction.grantRole(Roles.PAUSER_ROLE, i_pauser);
    s_auction.grantRole(Roles.UNPAUSER_ROLE, i_unpauser);
    s_auction.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);
    s_auction.grantRole(Roles.FORWARDER_ROLE, i_forwarder);
    s_auction.grantRole(Roles.AUCTION_WORKER_ROLE, i_auctionAdmin);
    s_auction.grantRole(Roles.AUCTION_WORKER_ROLE, address(s_workflowRouter));
    s_auction.grantRole(Roles.PRICE_ADMIN_ROLE, i_priceAdmin);
    s_auction.grantRole(Roles.PRICE_ADMIN_ROLE, address(s_workflowRouter));
    s_workflowRouter.grantRole(Roles.PAUSER_ROLE, i_pauser);
    s_workflowRouter.grantRole(Roles.FORWARDER_ROLE, i_forwarder);
    s_auctionBidder.grantRole(Roles.AUCTION_BIDDER_ROLE, i_auctionBidder);
    s_auctionBidder.grantRole(Roles.AUCTION_BIDDER_ROLE, address(s_workflowRouter));

    // ================================================================================================
    // │                                        Configuration                                         │
    // ================================================================================================

    (s_authority, s_authorityPk) = makeAddrAndKey("authority");

    s_paymentRequestSigners.push(s_authority);
    s_serviceProviders.push(i_serviceProvider1);
    s_serviceProviders.push(i_serviceProvider2);

    _changePrank(i_assetAdmin);
    GPV2CompatibleAuction.ApplyAssetParamsUpdate[] memory assetParamsUpdates =
      new GPV2CompatibleAuction.ApplyAssetParamsUpdate[](3);
    // +10% -> -2%
    assetParamsUpdates[0] = BaseAuction.ApplyAssetParamsUpdate({
      asset: address(s_mockWETH),
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.1e18, // 10% starting premium
        endingPriceMultiplier: 0.98e18, // 2% minimum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    // +5% -> -1%
    assetParamsUpdates[1] = BaseAuction.ApplyAssetParamsUpdate({
      asset: address(s_mockUSDC),
      params: BaseAuction.AssetParams({
        decimals: 6,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.05e18, // 5% starting premium
        endingPriceMultiplier: 0.99e18, // 1% minimum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    assetParamsUpdates[2] = BaseAuction.ApplyAssetParamsUpdate({
      asset: address(s_mockLINK),
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1,
        startingPriceMultiplier: 1e18,
        endingPriceMultiplier: 1e18,
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });

    s_auction.applyAssetParamsUpdates(assetParamsUpdates, new address[](0));

    // Allowlist assets on fee aggregator
    address[] memory allowlistedAssets = new address[](3);
    allowlistedAssets[0] = address(s_mockWETH);
    allowlistedAssets[1] = address(s_mockUSDC);
    allowlistedAssets[2] = address(s_mockLINK);

    s_feeAggregator.applyAllowlistedAssetUpdates(new address[](0), allowlistedAssets);

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

    // Add contracts to the list of contracts that are EmergencyWithdrawer
    s_commonContracts[CommonContracts.EMERGENCY_WITHDRAWER].push(address(s_auction));

    // Add contracts to the list of contracts that are LinkReceiver
    s_commonContracts[CommonContracts.LINK_RECEIVER].push(address(s_auction));

    // Add contracts to the list of contracts that are BaseAuction
    s_commonContracts[CommonContracts.BASE_AUCTION].push(address(s_auction));

    // ================================================================================================
    // │                                           Labeling                                           │
    // ================================================================================================

    vm.label(address(s_feeAggregator), "FeeAggregatorReceiver");
    vm.label(address(s_auction), "Auction");
    vm.label(address(s_workflowRouter), "Workflow Router");
    vm.label(address(s_auctionBidder), "Auction Bidder");
    vm.label(address(s_reserves), "Reserves");
    vm.label(i_owner, "Owner");
    vm.label(i_unpauser, "Unpauser");
    vm.label(i_assetAdmin, "Asset Admin");
    vm.label(address(s_mockLINK), "Mock LINK");
    vm.label(address(s_mockWETH), "Mock WETH");
    vm.label(address(s_mockUSDC), "Mock USDC");
    vm.label(address(s_mockWBTC), "Mock WBTC");
    vm.label(i_mockCCIPRouterClient, "Mock CCIP Router Client");
    vm.label(i_bridger, "Bridger");
    vm.label(i_withdrawer, "Withdrawer");
    vm.label(i_receiver, "Receiver");
    vm.label(address(s_mockLinkUsdFeed), "Mock LINK USD Feed");
    vm.label(address(s_mockWethUsdFeed), "Mock WETH USD Feed");
    vm.label(address(s_mockUsdcUsdFeed), "Mock USDC USD Feed");
    vm.label(address(s_mockUniswapRouter), "Mock Uniswap Router");
    vm.label(address(s_mockUniswapQuoterV2), "Mock Uniswap Quoter V2");
  }

  /// @notice Empty test function to ignore file in coverage report
  function test_baseUnitTest() public {}
}
