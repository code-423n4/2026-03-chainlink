// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {Common} from "src/libraries/Common.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract BaseAuction_CheckUpkeepUnitTest is BaseUnitTest, PriceManagerHelper {
  BaseAuction private s_baseAuction;

  modifier givenAuctionIsLive(
    address asset
  ) {
    BaseAuction.AssetParams memory assetParams = s_baseAuction.getAssetParams(asset);

    (uint256 assetPrice,,) = s_baseAuction.getAssetPrice(asset);
    uint256 requiredAssetBalance =
      (uint256(assetParams.minAuctionSizeUsd) * 10 ** assetParams.decimals) / uint256(assetPrice);

    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0] = Common.AssetAmount({asset: asset, amount: requiredAssetBalance});
    (, address msgSender,) = vm.readCallers();

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));
    s_baseAuction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    // Deal min balance to the auction contract to prevent auction end from low balance.
    vm.mockCall(
      asset, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(requiredAssetBalance)
    );

    _changePrank(msgSender);
    _;
  }

  modifier givenAuctionHasEnded(
    address asset
  ) {
    BaseAuction.AssetParams memory assetParams = s_baseAuction.getAssetParams(asset);

    (uint256 assetPrice,,) = s_baseAuction.getAssetPrice(asset);
    uint256 requiredAssetBalance =
      (uint256(assetParams.minAuctionSizeUsd) * 10 ** assetParams.decimals) / uint256(assetPrice);

    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0] = Common.AssetAmount({asset: asset, amount: requiredAssetBalance});

    uint256 currentTimestamp = block.timestamp;
    (, address msgSender,) = vm.readCallers();

    vm.warp(block.timestamp - uint64(block.timestamp - s_baseAuction.getAssetParams(asset).auctionDuration - 1));

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));
    s_baseAuction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    vm.warp(currentTimestamp);

    _changePrank(msgSender);
    _;
  }

  modifier givenAssetSufficientBalance(
    address asset
  ) {
    BaseAuction.AssetParams memory assetParams = s_baseAuction.getAssetParams(asset);

    (uint256 assetPrice,,) = s_baseAuction.getAssetPrice(asset);
    uint256 requiredAssetBalance =
      (uint256(assetParams.minAuctionSizeUsd) * 10 ** assetParams.decimals) / uint256(assetPrice);

    // Deal min balance to the auction contract to simulate residual balance from previous auctions.
    vm.mockCall(
      asset,
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)),
      abi.encode(requiredAssetBalance / 2)
    );
    // Deal min balance to the fee aggregator to reach a total of min balance.
    vm.mockCall(
      asset,
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_feeAggregator)),
      abi.encode(requiredAssetBalance)
    );
    _;
  }

  modifier givenStaleAssetPrice(
    address asset
  ) {
    uint32 stalenessThreshold = s_baseAuction.getFeedInfo(asset).stalenessThreshold;
    skip(stalenessThreshold + 1);
    _;
  }

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    // Set asset prices
    PriceManagerHelper.AssetPrice[] memory assetPrices = new PriceManagerHelper.AssetPrice[](3);
    assetPrices[0] = PriceManagerHelper.AssetPrice({asset: i_asset1, price: 4_000e18});
    assetPrices[1] = PriceManagerHelper.AssetPrice({asset: i_asset2, price: 1e8});
    assetPrices[2] = PriceManagerHelper.AssetPrice({asset: i_mockLink, price: 20e18});

    _transmitAssetPrices(s_baseAuction, assetPrices);

    // Set asset balances to 0
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(0));
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_feeAggregator)), abi.encode(0));
    vm.mockCall(i_asset2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(0));
    vm.mockCall(i_asset2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_feeAggregator)), abi.encode(0));
    vm.mockCall(i_mockLink, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(0));
    vm.mockCall(i_mockLink, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_feeAggregator)), abi.encode(0));
    vm.mockCall(
      address(i_asset1),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );
    vm.mockCall(
      address(i_asset2),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );
    vm.mockCall(
      address(i_asset3),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );
  }

  function test_checkUpkeep_RevertWhen_ContractIsPaused()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
    givenContractIsPaused(address(s_baseAuction))
  {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_baseAuction.checkUpkeep(abi.encode(i_asset1, uint64(block.timestamp)));
  }

  function test_checkUpkeep_RevertWhen_NoAssetOutParams()
    external
    givenAssetSufficientBalance(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Remove asset out paramss.
    _changePrank(i_assetAdmin);
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = s_baseAuction.getAssetOut();
    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);

    vm.expectRevert(BaseAuction.MissingAssetOutParams.selector);
    s_baseAuction.checkUpkeep("");
  }

  function test_checkUpkeep_WithEndedAuction()
    external
    givenAuctionHasEnded(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory eligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(eligibleAssets.length, 0);
    assertEq(endedAuctions.length, 1);
    assertEq(endedAuctions[0], i_asset1);
  }

  function test_checkUpkeep_WithEndedAuctionAndInvalidAssetOutPrice()
    external
    givenStaleAssetPrice(i_mockLink)
    givenAuctionHasEnded(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep(
      abi.encode(i_asset1, uint64(block.timestamp))
    );
    (Common.AssetAmount[] memory eligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertTrue(upkeepNeeded);
    assertEq(eligibleAssets.length, 0);
    assertEq(endedAuctions.length, 1);
    assertEq(endedAuctions[0], i_asset1);
  }

  function test_checkUpkeep_GivenAuctionIsLiveWithOutstandingBalanceAndNotended()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(1e18));
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    assertEq(upkeepNeeded, false);
    assertEq(performData, "");
  }

  function test_checkUpkeep_GivenAuctionIsLiveButEnded()
    external
    givenAuctionHasEnded(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory eligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(eligibleAssets.length, 0);
    assertEq(endedAuctions.length, 1);
    assertEq(endedAuctions[0], i_asset1);
  }

  function test_checkUpkeep_GivenAuctionIsLiveWithoutOutstandingBalance()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(0));

    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory eligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(eligibleAssets.length, 0);
    assertEq(endedAuctions.length, 1);
    assertEq(endedAuctions[0], i_asset1);
  }

  function test_checkUpkeep_WithStalePrice()
    external
    givenAuctionIsLive(i_asset1)
    givenStaleAssetPrice(i_asset1)
    givenStaleAssetPrice(i_asset2)
    givenAssetSufficientBalance(i_asset2)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Refresh asset out price to prevent revert.
    vm.mockCall(
      i_mockLinkUSDFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 20e18, 0, block.timestamp, 0)
    );

    // Set asset1 balance below threshold.
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)), abi.encode(0));
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    assertEq(upkeepNeeded, false);
    assertEq(performData, "");
  }

  function test_checkUpkeep_WithInsufficientBalance() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    assertEq(upkeepNeeded, false);
    assertEq(performData, "");
  }

  function test_checkUpkeep_EligibleAssetIdxEqAllowlistedAssetsLength()
    external
    givenAssetSufficientBalance(i_asset1)
    givenAssetSufficientBalance(i_asset2)
    givenAssetSufficientBalance(i_mockLink)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory eligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(eligibleAssets.length, 3);
    assertEq(endedAuctions.length, 0);
    assertEq(eligibleAssets[0].asset, i_asset1);
    assertEq(eligibleAssets[0].amount, 0.25e18); // $1,000 / $4,000 * 1e18 = 0.25e18
    assertEq(eligibleAssets[1].asset, i_asset2);
    assertEq(eligibleAssets[1].amount, 1_000e6); // $1,000 / $1 * 1e6 = 1_000e6
    assertEq(eligibleAssets[2].asset, i_mockLink);
    assertEq(eligibleAssets[2].amount, 50e18); // $1,000 / $20 * 1e18 = 50e18
  }

  function test_checkUpkeep_endedAuctionsIdxEqAllowlistedAssetsLength()
    external
    givenAuctionHasEnded(i_asset1)
    givenAuctionHasEnded(i_asset2)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory elligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(elligibleAssets.length, 0);
    assertEq(endedAuctions.length, 2);
    assertEq(endedAuctions[0], i_asset1);
    assertEq(endedAuctions[1], i_asset2);
  }

  function test_checkUpkeep_MixedScenario()
    external
    givenAuctionIsLive(i_asset1)
    givenAuctionHasEnded(i_asset2)
    givenAssetSufficientBalance(i_mockLink)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");

    (Common.AssetAmount[] memory elligibleAssets, address[] memory endedAuctions) =
      abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(upkeepNeeded, true);
    assertEq(elligibleAssets.length, 1);
    assertEq(endedAuctions.length, 1);
    assertEq(elligibleAssets[0].asset, i_mockLink);
    assertEq(elligibleAssets[0].amount, 50e18); // $1,000 / $20 * 1e18 = 50 e18
    assertEq(endedAuctions[0], i_asset2);
  }
}
