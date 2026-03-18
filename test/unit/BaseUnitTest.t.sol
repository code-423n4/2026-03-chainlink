// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {AuctionBidder} from "src/AuctionBidder.sol";
import {BaseAuction} from "src/BaseAuction.sol";
import {FeeAggregator} from "src/FeeAggregator.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";
import {PriceManager} from "src/PriceManager.sol";
import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseTest} from "test/BaseTest.t.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

abstract contract BaseUnitTest is BaseTest {
  address internal immutable i_asset1 = makeAddr("asset1");
  address internal immutable i_asset2 = makeAddr("asset2");
  address internal immutable i_asset3 = makeAddr("asset3");
  address internal immutable i_mockLink = makeAddr("mockLink");
  address internal immutable i_asset1UsdFeed = makeAddr("asset1UsdFeed");
  address internal immutable i_asset2UsdFeed = makeAddr("asset2UsdFeed");
  address internal immutable i_asset3UsdFeed = makeAddr("asset3UsdFeed");
  address internal immutable i_mockLinkUSDFeed = makeAddr("mockLinkUSDFeed");
  address internal immutable i_mockUniswapRouter = makeAddr("mockUniswapRouter");
  address internal immutable i_mockUniswapQuoterV2 = makeAddr("mockUniswapQuoterV2");
  address internal immutable i_user1 = makeAddr("user1");
  address internal immutable i_user2 = makeAddr("user2");
  address internal immutable i_mockStreamsVerifierProxy = makeAddr("mockStreamsVerifierProxy");
  address internal immutable i_mockGPV2VaultRelayer = makeAddr("mockGPV2VaultRelayer");
  address internal immutable i_mockGPV2Settlement = makeAddr("mockGPV2Settlement");
  bytes32 internal immutable i_asset1dataStreamsFeedId = _generateDataStreamsFeedId("asset1dataStreamsFeedId");
  bytes32 internal immutable i_asset2dataStreamsFeedId = _generateDataStreamsFeedId("asset2dataStreamsFeedId");
  bytes32 internal immutable i_asset3dataStreamsFeedId = _generateDataStreamsFeedId("asset3dataStreamsFeedId");
  bytes32 internal immutable i_mockLinkdataStreamsFeedId = _generateDataStreamsFeedId("mockLinkdataStreamsFeedId");

  address internal s_authority;
  uint256 internal s_authorityPk;

  FeeAggregator internal s_feeAggregator;
  WorkflowRouter internal s_workflowRouter;
  GPV2CompatibleAuction internal s_auction;
  AuctionBidder internal s_auctionBidder;

  address internal s_mockWrappedNativeToken = makeAddr("mockWrappedNativeToken");

  address[] internal s_serviceProviders;
  address[] internal s_paymentRequestSigners;

  constructor() {
    // Increment block.timestamp to avoid underflows
    skip(1 weeks);

    // ================================================================================================
    // │                                          Mock Call                                           │
    // ================================================================================================

    // Set feed decimals
    vm.mockCall(i_asset1UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));
    vm.mockCall(i_asset3UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLinkUSDFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));

    // Set asset decimals
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
    vm.mockCall(i_asset3, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLink, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));

    // Set feed decimals
    vm.mockCall(i_asset1UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));
    vm.mockCall(i_asset3UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLinkUSDFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));

    // Set asset prices
    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(4_000e18), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_asset2UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(1e8), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_asset3UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(100e24), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_mockLinkUSDFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(20e8), 0, block.timestamp, 0)
    );

    // ================================================================================================
    // │                                          Deployment                                          │
    // ================================================================================================

    s_feeAggregator = new FeeAggregator(
      FeeAggregator.ConstructorParams({
        admin: i_owner,
        adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
        linkToken: i_mockLink,
        ccipRouterClient: i_mockCCIPRouterClient,
        wrappedNativeToken: s_mockWrappedNativeToken
      })
    );

    (s_authority, s_authorityPk) = makeAddrAndKey("authority");

    BaseAuction.ConstructorParams memory params = BaseAuction.ConstructorParams({
      adminRoleTransferDelay: DEFAULT_ADMIN_TRANSFER_DELAY,
      admin: i_owner,
      minPriceMultiplier: MIN_PRICE_MULTIPLIER,
      verifierProxy: i_mockStreamsVerifierProxy,
      minBidUsdValue: MIN_BID_USD_VALUE,
      linkToken: i_mockLink,
      assetOut: i_mockLink,
      assetOutReceiver: i_receiver,
      feeAggregator: address(s_feeAggregator),
      feedInfos: new PriceManager.ApplyFeedInfoUpdateParams[](4)
    });

    params.feedInfos[0] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: i_asset1,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_asset1dataStreamsFeedId,
        usdDataFeed: AggregatorV3Interface(i_asset1UsdFeed),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: 1 hours
      })
    });
    params.feedInfos[1] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: i_asset2,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_asset2dataStreamsFeedId,
        usdDataFeed: AggregatorV3Interface(i_asset2UsdFeed),
        dataStreamsFeedDecimals: 8,
        stalenessThreshold: 1 hours
      })
    });
    params.feedInfos[2] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: i_asset3,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_asset3dataStreamsFeedId,
        usdDataFeed: AggregatorV3Interface(i_asset3UsdFeed),
        dataStreamsFeedDecimals: 24,
        stalenessThreshold: 1 hours
      })
    });
    params.feedInfos[3] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: i_mockLink,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_mockLinkdataStreamsFeedId,
        usdDataFeed: AggregatorV3Interface(i_mockLinkUSDFeed),
        dataStreamsFeedDecimals: 18,
        stalenessThreshold: 1 hours
      })
    });

    s_auction = new GPV2CompatibleAuction(params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);

    s_auctionBidder = new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), address(s_auction));

    s_workflowRouter = new WorkflowRouter(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner);

    // ================================================================================================
    // │                                        Role Granting                                         │
    // ================================================================================================

    _changePrank(i_owner);

    s_feeAggregator.grantRole(Roles.PAUSER_ROLE, i_pauser);
    s_feeAggregator.grantRole(Roles.UNPAUSER_ROLE, i_unpauser);
    s_feeAggregator.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);

    s_auction.grantRole(Roles.PRICE_ADMIN_ROLE, i_priceAdmin);
    s_auction.grantRole(Roles.ASSET_ADMIN_ROLE, i_assetAdmin);
    s_auction.grantRole(Roles.PAUSER_ROLE, i_pauser);
    s_auction.grantRole(Roles.UNPAUSER_ROLE, i_unpauser);
    s_auction.grantRole(Roles.AUCTION_WORKER_ROLE, i_auctionAdmin);

    s_auctionBidder.grantRole(Roles.PAUSER_ROLE, i_pauser);

    s_workflowRouter.grantRole(Roles.FORWARDER_ROLE, i_forwarder);
    s_workflowRouter.grantRole(Roles.PAUSER_ROLE, i_pauser);

    // ================================================================================================
    // │                                        Configuration                                         │
    // ================================================================================================

    // Set feed decimals
    vm.mockCall(i_asset1UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));
    vm.mockCall(i_asset3UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLinkUSDFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));

    // Set asset decimals
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
    vm.mockCall(i_asset3, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLink, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));

    // Set asset prices
    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(4_000e18), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_asset2UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(1e8), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_asset3UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(100e24), 0, block.timestamp, 0)
    );
    vm.mockCall(
      i_mockLinkUSDFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, int256(20e8), 0, block.timestamp, 0)
    );

    // Set asset params
    GPV2CompatibleAuction.ApplyAssetParamsUpdate[] memory assetParamsUpdates =
      new GPV2CompatibleAuction.ApplyAssetParamsUpdate[](3);
    // +10% -> -2%
    assetParamsUpdates[0] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_asset1,
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
      asset: i_asset2,
      params: BaseAuction.AssetParams({
        decimals: 6,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.05e18, // 5% starting premium
        endingPriceMultiplier: 0.99e18, // 1% minimum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    assetParamsUpdates[2] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_mockLink,
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1,
        startingPriceMultiplier: 1e18,
        endingPriceMultiplier: 1e18,
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });

    _changePrank(i_assetAdmin);
    s_auction.applyAssetParamsUpdates(assetParamsUpdates, new address[](0));
    _changePrank(i_owner);

    s_serviceProviders.push(i_serviceProvider1);
    s_serviceProviders.push(i_serviceProvider2);

    // Add contracts to the list of contracts that are PausableWithAccessControl
    s_commonContracts[CommonContracts.PAUSABLE_WITH_ACCESS_CONTROL].push(address(s_feeAggregator));
    s_commonContracts[CommonContracts.PAUSABLE_WITH_ACCESS_CONTROL].push(address(s_auction));
    s_commonContracts[CommonContracts.PRICE_MANAGER].push(address(s_auction));
    s_commonContracts[CommonContracts.BASE_AUCTION].push(address(s_auction));

    // ================================================================================================
    // │                                           Labeling                                           │
    // ================================================================================================

    vm.label(address(s_feeAggregator), "FeeAggregatorReceiver");
    vm.label(i_mockLink, "Mock LINK");
    vm.label(i_asset1, "Asset 1");
    vm.label(i_asset2, "Asset 2");
    vm.label(i_asset3, "Asset 3");
    vm.label(i_invalidAsset, "Invalid Asset");
    vm.label(i_mockCCIPRouterClient, "Mock CCIP Router Client");
    vm.label(i_asset1UsdFeed, "Asset 1 USD Feed");
    vm.label(i_asset2UsdFeed, "Asset 2 USD Feed");
    vm.label(i_asset3UsdFeed, "Asset 3 USD Feed");
    vm.label(i_mockLinkUSDFeed, "Mock LINK/USD Feed");
    vm.label(s_authority, "Authority");
  }
}
