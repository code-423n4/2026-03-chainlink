// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PriceManager} from "src/PriceManager.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IVerifierProxy} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceManager_GetAssetPriceUnitTest is BaseUnitTest {
  uint256 private constant ASSET_1_PRICE = 1e18;
  uint256 private constant ASSET_2_PRICE = 1e8;
  uint256 private constant ASSET_3_PRICE = 1e24;

  PriceManager.ReportV3 private s_asset1Report;
  PriceManager.ReportV3 private s_asset2Report;
  PriceManager.ReportV3 private s_asset3Report;

  bytes[] private s_unverifiedReports;

  function setUp() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    s_asset1Report.dataStreamsFeedId = i_asset1dataStreamsFeedId;
    s_asset1Report.price = int192(uint192(ASSET_1_PRICE));
    s_asset1Report.observationsTimestamp = uint32(block.timestamp);

    s_asset2Report.dataStreamsFeedId = i_asset2dataStreamsFeedId;
    s_asset2Report.price = int192(uint192(ASSET_2_PRICE));
    s_asset2Report.observationsTimestamp = uint32(block.timestamp);

    s_asset3Report.dataStreamsFeedId = i_asset3dataStreamsFeedId;
    s_asset3Report.price = int192(uint192(ASSET_3_PRICE));
    s_asset3Report.observationsTimestamp = uint32(block.timestamp);

    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset1Report), rs, ss, rawVs));
    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset2Report), rs, ss, rawVs));
    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset3Report), rs, ss, rawVs));

    bytes[] memory verifiedReports = new bytes[](3);
    verifiedReports[0] = abi.encode(s_asset1Report);
    verifiedReports[1] = abi.encode(s_asset2Report);
    verifiedReports[2] = abi.encode(s_asset3Report);

    vm.mockCall(
      i_mockStreamsVerifierProxy,
      abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, s_unverifiedReports, abi.encode(i_mockLink)),
      abi.encode(verifiedReports)
    );

    _changePrank(i_priceAdmin);

    PriceManager(s_contractUnderTest).transmit(s_unverifiedReports);
  }

  function test_getAssetPrice_WithValidDataStreamsPrices()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);
    (uint256 asset2Price, uint256 asset2UpdatedAt, bool isAsset2PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset2);
    (uint256 asset3Price, uint256 asset3UpdatedAt, bool isAsset3PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset3);

    assertEq(asset1Price, 1e18);
    assertEq(asset2Price, 1e18);
    assertEq(asset3Price, 1e18);
    assertEq(asset1UpdatedAt, block.timestamp);
    assertEq(asset2UpdatedAt, block.timestamp);
    assertEq(asset3UpdatedAt, block.timestamp);
    assertTrue(isAsset1PriceValid);
    assertTrue(isAsset2PriceValid);
    assertTrue(isAsset3PriceValid);
  }

  function test_getAssetPrice_StaleDataStreamsPriceAndDataFeedDecimalsLt18()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    skip(STALENESS_THRESHOLD + 1);

    vm.mockCall(
      i_asset2UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_2_PRICE, 0, block.timestamp, 0)
    );

    (uint256 asset2Price, uint256 asset2UpdatedAt, bool isAsset2PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset2);

    assertEq(asset2Price, 1e18);
    assertEq(asset2UpdatedAt, block.timestamp);
    assertTrue(isAsset2PriceValid);
  }

  function test_getAssetPrice_StaleDataStreamsPriceAndDataFeedDecimalsGt18() external {
    skip(STALENESS_THRESHOLD + 1);

    vm.mockCall(
      i_asset3UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_3_PRICE, 0, block.timestamp, 0)
    );

    (uint256 asset3Price, uint256 asset3UpdatedAt, bool isAsset3PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset3);

    assertEq(asset3Price, 1e18);
    assertEq(asset3UpdatedAt, block.timestamp);
    assertTrue(isAsset3PriceValid);
  }

  function test_getAssetPrice_StaleDataStreamsPriceAndDataFeedDecimalsEq18()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    skip(STALENESS_THRESHOLD + 1);

    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_1_PRICE, 0, block.timestamp, 0)
    );

    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    assertEq(asset1Price, 1e18);
    assertEq(asset1UpdatedAt, block.timestamp);
    assertTrue(isAsset1PriceValid);
  }

  function test_getAssetPrice_WithDataStreamsAsLeastStalePrice()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    // Data Streams is stale by 1 second
    skip(STALENESS_THRESHOLD + 1);

    // Data Feed is stale by 2 seconds
    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_1_PRICE + 1, 0, block.timestamp - STALENESS_THRESHOLD - 2, 0)
    );

    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    assertEq(asset1Price, ASSET_1_PRICE);
    assertEq(asset1UpdatedAt, block.timestamp - STALENESS_THRESHOLD - 1);
    assertFalse(isAsset1PriceValid);
  }

  function test_getAssetPrice_WithDataFeedAsLeastStalePrice()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    // Data Streams is stale by 2 seconds
    skip(STALENESS_THRESHOLD + 2);

    // Data Feed is stale by 1 second
    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_1_PRICE + 1, 0, block.timestamp - STALENESS_THRESHOLD - 1, 0)
    );

    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    assertEq(asset1Price, ASSET_1_PRICE + 1);
    assertEq(asset1UpdatedAt, block.timestamp - STALENESS_THRESHOLD - 1);
    assertFalse(isAsset1PriceValid);
  }

  function test_getAssetPrice_WithDataStreamsStalenessEqDataFeedStaleness()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    // Data Streams is stale by 1 second
    skip(STALENESS_THRESHOLD + 1);

    // Data Feed is stale by 1 second
    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, ASSET_1_PRICE + 1, 0, block.timestamp - STALENESS_THRESHOLD - 1, 0)
    );

    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    // In case of staleness tie, Data Streams price should be used
    assertEq(asset1Price, ASSET_1_PRICE);
    assertEq(asset1UpdatedAt, block.timestamp - STALENESS_THRESHOLD - 1);
    assertFalse(isAsset1PriceValid);
  }

  function testFuzz_getAssetPrice(
    uint8 dataFeedDecimals
  ) external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    _changePrank(i_assetAdmin);

    dataFeedDecimals = uint8(bound(dataFeedDecimals, 1, 24));

    // Update feed info with new data feed decimals
    PriceManager.ApplyFeedInfoUpdateParams[] memory feedInfoUpdate = new PriceManager.ApplyFeedInfoUpdateParams[](1);
    feedInfoUpdate[0] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: i_asset1,
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: i_asset1dataStreamsFeedId,
        usdDataFeed: AggregatorV3Interface(i_asset1UsdFeed),
        dataStreamsFeedDecimals: dataFeedDecimals,
        stalenessThreshold: STALENESS_THRESHOLD
      })
    });
    vm.mockCall(
      i_asset1UsdFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(dataFeedDecimals)
    );
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(feedInfoUpdate, new address[](0));

    vm.mockCall(
      i_asset1UsdFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 10 ** dataFeedDecimals, 0, block.timestamp, 0)
    );
    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);

    assertEq(asset1Price, 1e18);
    assertEq(asset1UpdatedAt, block.timestamp);
    assertTrue(isAsset1PriceValid);
  }
}
