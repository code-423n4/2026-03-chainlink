// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";
import {PriceManager} from "src/PriceManager.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {
  IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract BaseAuction_ConstructorUnitTest is BaseUnitTest {
  BaseAuction.ConstructorParams private s_params;
  PriceManager.FeedInfo[] private s_feedInfos;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_params.admin = i_owner;
    s_params.adminRoleTransferDelay = DEFAULT_ADMIN_TRANSFER_DELAY;
    s_params.verifierProxy = i_mockStreamsVerifierProxy;
    s_params.minPriceMultiplier = MIN_PRICE_MULTIPLIER;
    s_params.minBidUsdValue = MIN_BID_USD_VALUE;
    s_params.linkToken = i_mockLink;
    s_params.assetOut = i_mockLink;
    s_params.assetOutReceiver = i_receiver;
    s_params.feeAggregator = address(s_feeAggregator);

    PriceManager.FeedInfo memory asset1FeedInfo = PriceManager.FeedInfo({
      dataStreamsFeedId: i_asset1dataStreamsFeedId,
      usdDataFeed: AggregatorV3Interface(i_asset1UsdFeed),
      dataStreamsFeedDecimals: 18,
      stalenessThreshold: STALENESS_THRESHOLD
    });
    PriceManager.FeedInfo memory asset2FeedInfo = PriceManager.FeedInfo({
      dataStreamsFeedId: i_asset2dataStreamsFeedId,
      usdDataFeed: AggregatorV3Interface(i_asset2UsdFeed),
      dataStreamsFeedDecimals: 8,
      stalenessThreshold: STALENESS_THRESHOLD
    });

    s_params.feedInfos.push(PriceManager.ApplyFeedInfoUpdateParams({asset: i_asset1, feedInfo: asset1FeedInfo}));
    s_params.feedInfos.push(PriceManager.ApplyFeedInfoUpdateParams({asset: i_asset2, feedInfo: asset2FeedInfo}));
    s_feedInfos.push(asset1FeedInfo);
    s_feedInfos.push(asset2FeedInfo);
  }

  function test_constructor_RevertWhen_AdminEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.admin = address(0);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, address(0))
    );

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_LinkTokenEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.linkToken = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_VerifierProxyEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.verifierProxy = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_AssetOutEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.assetOut = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_AssetOutReceiverEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.assetOutReceiver = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_FeeAggregatorEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.feeAggregator = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_MaxDiscountEqZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_params.minPriceMultiplier = 0;

    vm.expectRevert(Errors.InvalidZeroValue.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_GPV2VaultRelayerEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, address(0), i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_GPV2SettlementEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, address(0));
  }

  function test_constructor_WithFeedsInfos() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectEmit();
    emit PriceManager.FeedInfoUpdated(i_asset1, s_feedInfos[0]);
    vm.expectEmit();
    emit PriceManager.FeedInfoUpdated(i_asset2, s_feedInfos[1]);
    vm.expectEmit();
    emit PriceManager.VerifierProxySet(i_mockStreamsVerifierProxy);
    vm.expectEmit();
    emit BaseAuction.MinBidUsdValueSet(s_params.minBidUsdValue);
    vm.expectEmit();
    emit BaseAuction.AssetOutSet(s_params.assetOut);
    vm.expectEmit();
    emit BaseAuction.AssetOutReceiverSet(s_params.assetOutReceiver);
    vm.expectEmit();
    emit BaseAuction.FeeAggregatorSet(address(s_feeAggregator));
    vm.expectEmit();
    emit BaseAuction.MinPriceMultiplierSet(s_params.minPriceMultiplier);

    GPV2CompatibleAuction auction = new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);

    PriceManager.FeedInfo memory feedInfo1 = auction.getFeedInfo(i_asset1);
    PriceManager.FeedInfo memory feedInfo2 = auction.getFeedInfo(i_asset2);

    assertEq(address(auction.getStreamsVerifierProxy()), i_mockStreamsVerifierProxy);
    assertEq(feedInfo1.dataStreamsFeedDecimals, 18);
    assertEq(feedInfo2.dataStreamsFeedDecimals, 8);
    assertEq(BaseAuction(s_contractUnderTest).getMinPriceMultiplier(), s_params.minPriceMultiplier);
    assertEq(address(BaseAuction(s_contractUnderTest).getAssetOut()), s_params.assetOut);
    assertEq(BaseAuction(s_contractUnderTest).getAssetOutReceiver(), s_params.assetOutReceiver);
    assertEq(address(BaseAuction(s_contractUnderTest).getFeeAggregator()), s_params.feeAggregator);
  }

  function test_constructor_WithoutFeedsInfos() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_params.feedInfos.pop();
    s_params.feedInfos.pop();

    vm.expectEmit();
    emit PriceManager.VerifierProxySet(i_mockStreamsVerifierProxy);

    GPV2CompatibleAuction auction = new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);

    assertEq(address(auction.getStreamsVerifierProxy()), i_mockStreamsVerifierProxy);
  }
}
