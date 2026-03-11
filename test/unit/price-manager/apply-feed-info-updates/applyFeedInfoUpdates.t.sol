// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IVerifierProxy} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {PriceManager} from "src/PriceManager.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PriceManager_ApplyFeedInfoUpdatesUnitTest is BaseUnitTest {
  address private immutable i_asset4 = makeAddr("asset4");
  address private immutable i_asset5 = makeAddr("asset5");
  address private immutable i_asset4UsdFeed = makeAddr("asset4UsdFeed");
  address private immutable i_asset5UsdFeed = makeAddr("asset5UsdFeed");
  bytes32 private immutable i_asset4dataStreamsFeedId = _generateDataStreamsFeedId("asset4dataStreamsFeedId");
  bytes32 private immutable i_asset5dataStreamsFeedId = _generateDataStreamsFeedId("asset5dataStreamsFeedId");

  PriceManager.ApplyFeedInfoUpdateParams[] private s_feedInfoUpdates;
  PriceManager.FeedInfo[] private s_feedInfos;
  PriceManager.FeedInfo private s_emptyFeedInfo;
  PriceManager.ReportV3 private s_asset1Report;

  bytes[] private s_unverifiedReports;

  modifier givenAuctionIsLive(
    address asset
  ) {
    BaseAuction.AssetParams memory assetParams = s_auction.getAssetParams(asset);

    (uint256 assetPrice,,) = s_auction.getAssetPrice(asset);
    uint256 requiredAssetBalance =
      (uint256(assetParams.minAuctionSizeUsd) * 10 ** assetParams.decimals) / uint256(assetPrice);

    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0] = Common.AssetAmount({asset: asset, amount: requiredAssetBalance});
    (, address msgSender,) = vm.readCallers();

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));

    // Deal min balance to the auction contract to prevent auction end from low balance.
    vm.mockCall(
      asset, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_auction)), abi.encode(requiredAssetBalance)
    );

    s_auction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    _changePrank(msgSender);
    _;
  }

  function setUp() external {
    _changePrank(i_assetAdmin);

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager.FeedInfo({
      dataStreamsFeedId: i_asset4dataStreamsFeedId,
      usdDataFeed: AggregatorV3Interface(i_asset4UsdFeed),
      dataStreamsFeedDecimals: 18,
      stalenessThreshold: STALENESS_THRESHOLD
    });
    PriceManager.FeedInfo memory asset5FeedInfo = PriceManager.FeedInfo({
      dataStreamsFeedId: i_asset5dataStreamsFeedId,
      usdDataFeed: AggregatorV3Interface(i_asset5UsdFeed),
      dataStreamsFeedDecimals: 8,
      stalenessThreshold: STALENESS_THRESHOLD
    });

    s_feedInfoUpdates.push(PriceManager.ApplyFeedInfoUpdateParams({asset: i_asset4, feedInfo: asset4FeedInfo}));
    s_feedInfoUpdates.push(PriceManager.ApplyFeedInfoUpdateParams({asset: i_asset5, feedInfo: asset5FeedInfo}));
    s_feedInfos.push(asset4FeedInfo);
    s_feedInfos.push(asset5FeedInfo);

    vm.mockCall(i_asset4UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset5UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(8));

    vm.label(i_asset4, "Asset 4");
    vm.label(i_asset5, "Asset 5");
    vm.label(i_asset4UsdFeed, "Asset 4 USD Feed");
    vm.label(i_asset5UsdFeed, "Asset 5 USD Feed");
  }

  function test_applyFeedInfoUpdates_RevertWhen_CallerDoesNotHaveASSET_ADMIN_ROLE()
    external
    whenCallerIsNotAssetManager
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.ASSET_ADMIN_ROLE)
    );

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_EmptyList()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    vm.expectRevert(Errors.EmptyList.selector);

    PriceManager(s_contractUnderTest)
      .applyFeedInfoUpdates(new PriceManager.ApplyFeedInfoUpdateParams[](0), new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_RemovedFeedIsNotAllowlisted()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    address[] memory removes = new address[](1);
    removes[0] = i_asset4;

    vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotAllowlisted.selector, removes[0]));

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, removes);
  }

  function test_applyFeedInfoUpdates_RevertWhen_AssetEqAddressZero()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].asset = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_DataStreamsFeedIdEqZeroAndUsdDataFeedEqAddressZero()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = bytes32(0);
    s_feedInfoUpdates[0].feedInfo.usdDataFeed = AggregatorV3Interface(address(0));

    vm.expectRevert(Errors.InvalidZeroValue.selector);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_StalenessThresholdEqZero()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.stalenessThreshold = 0;

    vm.expectRevert(
      abi.encodeWithSelector(Errors.InvalidZeroValue.selector, s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId)
    );

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_FeedDecimalsEqZero()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedDecimals = 0;

    vm.expectRevert(
      abi.encodeWithSelector(PriceManager.InvalidFeedDecimals.selector, s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId)
    );

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_InvalidFeedVersion()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId =
      bytes32(bytes.concat(bytes2(0x0001), bytes30(keccak256("invaliddataStreamsFeedId"))));

    vm.expectRevert(
      abi.encodeWithSelector(
        PriceManager.InvalidFeedVersion.selector, s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId, 1
      )
    );

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_DataStreamsFeedCrossAssetRotationWithoutDataFeed()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    // First configure feeds for asset4 and asset5 without a Data Feed support for asset 5
    s_feedInfoUpdates[1].feedInfo.usdDataFeed = AggregatorV3Interface(address(0));
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    // We want to assign data streams feed of asset5 to asset4
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = s_feedInfos[1].dataStreamsFeedId;
    s_feedInfoUpdates.pop();
    s_feedInfos[0].dataStreamsFeedId = s_feedInfos[1].dataStreamsFeedId;
    s_feedInfos[1].dataStreamsFeedId = bytes32(0);
    s_feedInfos[1].dataStreamsFeedDecimals = 0;

    // This should clear the data streams feed data of asset5 while reassigning it asset4. But since asset5 doesn't have
    // a data feed, the rotation should be blocked to avoid leaving asset5 without any price feed support
    vm.expectRevert(Errors.InvalidZeroValue.selector);
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_RemovingAssetOutWithLiveAuction()
    external
    givenAuctionIsLive(i_asset1)
  {
    address[] memory removes = new address[](1);
    removes[0] = i_asset1;
    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_auction.applyFeedInfoUpdates(new PriceManager.ApplyFeedInfoUpdateParams[](0), removes);
  }

  function test_applyFeedInfoUpdates_RevertWhen_RemovedAssetHasLiveAuction() external givenAuctionIsLive(i_asset1) {
    address[] memory removes = new address[](1);
    removes[0] = i_asset1;
    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_auction.applyFeedInfoUpdates(new PriceManager.ApplyFeedInfoUpdateParams[](0), removes);
  }

  function test_applyFeedInfoUpdates_RevertWhen_UpdatingAssetOutFeedDuringLiveAuction()
    external
    givenAuctionIsLive(i_asset1)
  {
    s_feedInfoUpdates[0].asset = i_mockLink;
    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_auction.applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_RevertWhen_UpdatedAssetHasLiveAuction() external givenAuctionIsLive(i_asset1) {
    s_feedInfoUpdates[0].asset = i_asset1;
    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_auction.applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));
  }

  function test_applyFeedInfoUpdates_AddNewFeedsWithBothDataStreamsAndDataFeed()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset5, s_feedInfos[1]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);
    PriceManager.FeedInfo memory asset5FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset5);

    address[] memory allowlistedAssets = PriceManager(s_contractUnderTest).getAllowlistedAssets();
    address[] memory expectedAllowlistedAssets = new address[](6);
    // From BaseUnitTest setup
    expectedAllowlistedAssets[0] = i_asset1;
    expectedAllowlistedAssets[1] = i_asset2;
    expectedAllowlistedAssets[2] = i_asset3;
    expectedAllowlistedAssets[3] = i_mockLink;
    // From this test
    expectedAllowlistedAssets[4] = i_asset4;
    expectedAllowlistedAssets[5] = i_asset5;

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    _assertFeedInfoEq(asset5FeedInfo, s_feedInfos[1]);
    assertEq(allowlistedAssets, expectedAllowlistedAssets);
    assertEq(i_asset4, s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
    assertEq(i_asset5, s_auction.getAssetFromDataStreamsFeedId(i_asset5dataStreamsFeedId));
  }

  function test_applyFeedInfoUpdates_AddNewFeedsWithOnlyDataStreamsFeed()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.usdDataFeed = AggregatorV3Interface(address(0));
    s_feedInfos[0].usdDataFeed = AggregatorV3Interface(address(0));

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    assertEq(i_asset4, s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
  }

  function test_applyFeedInfoUpdates_AddNewFeedsWithOnlyDataFeed()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = bytes32(0);
    s_feedInfos[0].dataStreamsFeedId = bytes32(0);

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
  }

  function test_applyFeedInfoUpdates_UpdateExistingFeedId()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    bytes32 newFeedId = _generateDataStreamsFeedId("newFeedId");

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = newFeedId;
    s_feedInfos[0].dataStreamsFeedId = newFeedId;

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    assertEq(PriceManager(s_contractUnderTest).getAssetFromDataStreamsFeedId(newFeedId), i_asset4);
    assertEq(PriceManager(s_contractUnderTest).getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId), address(0));
  }

  function test_applyFeedInfoUpdates_UpdateExistingFeedRemoveDataStreamsSupport()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = bytes32(0);
    s_feedInfos[0].dataStreamsFeedId = bytes32(0);

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    // Mock data feed so getAssetPrice falls back to it and returns the mocked price (data streams were removed, no
    // transmit was done)
    vm.mockCall(
      i_asset4UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 2_000e18, 0, block.timestamp, 0)
    );

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);
    (uint256 price, uint256 updatedAt, bool isValid) = PriceManager(s_contractUnderTest).getAssetPrice(i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
    assertEq(price, 2_000e18);
    assertEq(updatedAt, block.timestamp);
    assertTrue(isValid);

    // Restore data streams feed id for asset4
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = i_asset4dataStreamsFeedId;
    s_feedInfos[0].dataStreamsFeedId = i_asset4dataStreamsFeedId;

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    assertEq(i_asset4, s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));

    // Verify that we are still getting the data feed price
    (price, updatedAt, isValid) = PriceManager(s_contractUnderTest).getAssetPrice(i_asset4);
    assertEq(price, 2_000e18);
    assertEq(updatedAt, block.timestamp);
    assertTrue(isValid);
  }

  function test_applyFeedInfoUpdates_UpdateExistingFeedRemoveDataFeedSupport()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    s_feedInfoUpdates[0].feedInfo.usdDataFeed = AggregatorV3Interface(address(0));
    s_feedInfos[0].usdDataFeed = AggregatorV3Interface(address(0));

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    assertEq(i_asset4, s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
  }

  function test_applyFeedInfoUpdates_DataStreamsFeedCrossAssetRotation()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    // First configure feeds for asset4 and asset5
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    // We want to assign data streams feed of asset5 to asset4 (simulating a wrong configuration)
    s_feedInfoUpdates[0].feedInfo.dataStreamsFeedId = s_feedInfos[1].dataStreamsFeedId;
    s_feedInfoUpdates.pop();
    s_feedInfos[0].dataStreamsFeedId = s_feedInfos[1].dataStreamsFeedId;
    s_feedInfos[1].dataStreamsFeedId = bytes32(0);
    s_feedInfos[1].dataStreamsFeedDecimals = 0;

    // This should clear the data streams feed data of asset5 while reassigning it asset4. So asset5 will then only
    // support data feed
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);
    PriceManager.FeedInfo memory asset5FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset5);

    assertEq(PriceManager(s_contractUnderTest).getAssetFromDataStreamsFeedId(i_asset5dataStreamsFeedId), i_asset4);

    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    _assertFeedInfoEq(asset5FeedInfo, s_feedInfos[1]);
  }

  function test_applyFeedInfoUpdates_RemoveExistingFeed()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    address[] memory removes = new address[](1);
    removes[0] = i_asset1;

    // Transmit price
    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    s_asset1Report.dataStreamsFeedId = i_asset1dataStreamsFeedId;
    s_asset1Report.price = int192(1e18);
    s_asset1Report.observationsTimestamp = uint32(block.timestamp);

    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset1Report), rs, ss, rawVs));
    bytes[] memory verifiedReports = new bytes[](1);
    verifiedReports[0] = abi.encode(s_asset1Report);

    vm.mockCall(
      i_mockStreamsVerifierProxy,
      abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, s_unverifiedReports, abi.encode(i_mockLink)),
      abi.encode(verifiedReports)
    );

    _changePrank(i_priceAdmin);
    PriceManager(s_contractUnderTest).transmit(s_unverifiedReports);

    PriceManager.FeedInfo memory asset1FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset1);
    (uint256 price, uint256 updatedAt, bool isValid) = PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    assertEq(price, 1e18);
    assertEq(updatedAt, block.timestamp);
    assertTrue(isValid);

    // Remove feed
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.AssetRemovedFromAllowlist(i_asset1);

    _changePrank(i_assetAdmin);
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(new PriceManager.ApplyFeedInfoUpdateParams[](0), removes);

    asset1FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset1);

    _assertFeedInfoEq(asset1FeedInfo, s_emptyFeedInfo);
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset1dataStreamsFeedId));

    // Restore feed for asset1
    s_feedInfoUpdates[0].asset = i_asset1;
    _changePrank(i_assetAdmin);
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, new address[](0));

    // We expect a revert here because the price data for asset1 has been removed, so it falls back to the used feed
    // which haven't mocked.
    vm.expectRevert();
    PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);
  }

  function test_applyFeedInfoUpdates_AddAndRemoveFeeds()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    address[] memory removes = new address[](4);
    removes[0] = i_asset1;
    removes[1] = i_asset2;
    removes[2] = i_asset3;
    removes[3] = i_mockLink;

    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.AssetRemovedFromAllowlist(i_asset1);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.AssetRemovedFromAllowlist(i_asset2);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.AssetRemovedFromAllowlist(i_asset3);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.AssetRemovedFromAllowlist(i_mockLink);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset4, s_feedInfos[0]);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.FeedInfoUpdated(i_asset5, s_feedInfos[1]);

    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(s_feedInfoUpdates, removes);

    PriceManager.FeedInfo memory asset1FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset1);
    PriceManager.FeedInfo memory asset2FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset2);
    PriceManager.FeedInfo memory asset3FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset3);
    PriceManager.FeedInfo memory mockLinkFeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_mockLink);
    PriceManager.FeedInfo memory asset4FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset4);
    PriceManager.FeedInfo memory asset5FeedInfo = PriceManager(s_contractUnderTest).getFeedInfo(i_asset5);

    address[] memory allowlistedAssets = PriceManager(s_contractUnderTest).getAllowlistedAssets();
    address[] memory expectedAllowlistedAssets = new address[](2);
    expectedAllowlistedAssets[0] = i_asset4;
    expectedAllowlistedAssets[1] = i_asset5;

    _assertFeedInfoEq(asset1FeedInfo, s_emptyFeedInfo);
    _assertFeedInfoEq(asset2FeedInfo, s_emptyFeedInfo);
    _assertFeedInfoEq(asset3FeedInfo, s_emptyFeedInfo);
    _assertFeedInfoEq(mockLinkFeedInfo, s_emptyFeedInfo);
    _assertFeedInfoEq(asset4FeedInfo, s_feedInfos[0]);
    _assertFeedInfoEq(asset5FeedInfo, s_feedInfos[1]);
    assertEq(allowlistedAssets, expectedAllowlistedAssets);
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset1dataStreamsFeedId));
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset2dataStreamsFeedId));
    assertEq(address(0), s_auction.getAssetFromDataStreamsFeedId(i_asset3dataStreamsFeedId));
    assertEq(i_asset4, s_auction.getAssetFromDataStreamsFeedId(i_asset4dataStreamsFeedId));
    assertEq(i_asset5, s_auction.getAssetFromDataStreamsFeedId(i_asset5dataStreamsFeedId));
  }

  function _assertFeedInfoEq(
    PriceManager.FeedInfo memory a,
    PriceManager.FeedInfo memory b
  ) internal pure {
    assertEq(a.dataStreamsFeedId, b.dataStreamsFeedId);
    assertEq(address(a.usdDataFeed), address(b.usdDataFeed));
    assertEq(a.dataStreamsFeedDecimals, b.dataStreamsFeedDecimals);
    assertEq(a.stalenessThreshold, b.stalenessThreshold);
  }
}
