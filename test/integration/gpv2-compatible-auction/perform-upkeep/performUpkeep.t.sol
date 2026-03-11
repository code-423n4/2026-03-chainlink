// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {Roles} from "src/libraries/Roles.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract GPV2CompatibleAuction_PerformUpkeepIntegrationTest is BaseIntegrationTest, PriceManagerHelper {
  PriceManagerHelper.AssetPrice[] private s_assetPrices;

  modifier givenSufficientAssetBalance(
    address asset,
    bool withFeeAggregator
  ) {
    _dealSufficientAssetBalance(asset, withFeeAggregator);
    _;
  }

  modifier whenCallerIsNotAuctionAdmin() {
    _changePrank(i_owner);
    _;
  }

  function setUp() external {
    _changePrank(i_assetAdmin);

    // Set asset prices
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockWETH), price: 4_000e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockUSDC), price: 1e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockLINK), price: 20e18}));

    _transmitAssetPrices(s_auction, s_assetPrices);

    _changePrank(i_auctionAdmin);
  }

  function test_performUpkeep_RevertWhen_CallerDoesNotHaveAUCTION_WORKER_ROLE() external whenCallerIsNotAuctionAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.AUCTION_WORKER_ROLE
      )
    );

    s_auction.performUpkeep("");
  }

  function test_performUpkeep_WithFeeAggregatorAndEligibleAssets()
    external
    givenSufficientAssetBalance(address(s_mockWETH), true)
    givenSufficientAssetBalance(address(s_mockUSDC), true)
  {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    assertEq(s_mockWETH.balanceOf(address(s_auction)), 0.25 ether);
    assertEq(s_mockWETH.balanceOf(address(s_feeAggregator)), 0 ether);
    assertEq(s_mockUSDC.balanceOf(address(s_auction)), 1_000e6);
    assertEq(s_mockUSDC.balanceOf(address(s_feeAggregator)), 0);
    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), block.timestamp);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), block.timestamp);
  }

  function test_performUpkeep_WithoutFeeAggregatorAndEligibleAssets()
    external
    givenSufficientAssetBalance(address(s_mockWETH), false)
    givenSufficientAssetBalance(address(s_mockUSDC), false)
  {
    _changePrank(i_owner);
    s_auction.setFeeAggregator(address(s_auction));
    _changePrank(i_auctionAdmin);

    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    assertEq(s_mockWETH.balanceOf(address(s_auction)), 0.25 ether);
    assertEq(s_mockUSDC.balanceOf(address(s_auction)), 1_000e6);
    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), block.timestamp);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), block.timestamp);
  }

  function test_performUpkeep_WithAssetOutEligibleAsset()
    external
    givenSufficientAssetBalance(address(s_mockLINK), true)
  {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    s_auction.performUpkeep(performData);

    assertEq(s_mockLINK.balanceOf(address(s_auction)), 0);
    assertEq(s_mockLINK.balanceOf(address(s_feeAggregator)), 0);
    assertEq(s_mockLINK.balanceOf(s_auction.getAssetOutReceiver()), 50 ether);
    assertEq(s_auction.getAuctionStart(address(s_mockLINK)), 0);
  }

  function test_performUpkeep_EndedAuctionsWithFeeAggregatorAndNoResiduals()
    external
    givenSufficientAssetBalance(address(s_mockWETH), true)
    givenSufficientAssetBalance(address(s_mockUSDC), true)
  {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    deal(address(s_mockWETH), address(s_auction), 0);
    deal(address(s_mockUSDC), address(s_auction), 0);
    deal(address(s_mockLINK), address(s_auction), 100 ether);

    (upkeepNeeded, performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), 0);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), 0);
    assertEq(s_mockLINK.balanceOf(address(s_auction)), 0);
    assertEq(s_mockLINK.balanceOf(address(s_reserves)), 100 ether);
  }

  function test_performUpkeep_EndedAuctionsWithFeeAggregatorAndResiduals()
    external
    givenSufficientAssetBalance(address(s_mockWETH), true)
    givenSufficientAssetBalance(address(s_mockUSDC), true)
  {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");
    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    deal(address(s_mockWETH), address(s_auction), 0.125 ether);
    deal(address(s_mockUSDC), address(s_auction), 500e6);
    deal(address(s_mockLINK), address(s_auction), 100 ether);
    skip(1 days + 1);

    (upkeepNeeded, performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockUSDC));
    s_auction.performUpkeep(performData);

    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), 0);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), 0);
    assertEq(s_mockWETH.balanceOf(address(s_auction)), 0);
    assertEq(s_mockUSDC.balanceOf(address(s_auction)), 0);
    assertEq(s_mockWETH.balanceOf(address(s_feeAggregator)), 0.125 ether);
    assertEq(s_mockUSDC.balanceOf(address(s_feeAggregator)), 500e6);
    assertEq(s_mockLINK.balanceOf(address(s_reserves)), 100 ether);
  }

  function test_performUpkeep_EndedAuctionsWithoutFeeAggregatorAndNoResiduals()
    external
    givenSufficientAssetBalance(address(s_mockWETH), false)
    givenSufficientAssetBalance(address(s_mockUSDC), false)
  {
    _changePrank(i_owner);
    s_auction.setFeeAggregator(address(s_auction));
    _changePrank(i_auctionAdmin);

    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");
    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));

    s_auction.performUpkeep(performData);

    deal(address(s_mockWETH), address(s_auction), 0.125 ether);
    deal(address(s_mockUSDC), address(s_auction), 500e6);
    skip(1 days + 1);

    (upkeepNeeded, performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockWETH));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockUSDC));
    s_auction.performUpkeep(performData);

    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), 0);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), 0);
    assertEq(s_mockWETH.balanceOf(address(s_auction)), 0.125 ether);
    assertEq(s_mockUSDC.balanceOf(address(s_auction)), 500e6);
  }

  function test_performUpkeep_WithEligibleAssetsAndEndedAuctions()
    external
    givenSufficientAssetBalance(address(s_mockWETH), true)
  {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");
    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));

    s_auction.performUpkeep(performData);

    // Skip to auction end
    skip(1 days + 1);

    _dealSufficientAssetBalance(address(s_mockUSDC), true);
    // Refresh asset prices
    _transmitAssetPrices(s_auction, s_assetPrices);

    (upkeepNeeded, performData) = s_auction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockUSDC));
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionEnded(address(s_mockWETH));

    s_auction.performUpkeep(performData);

    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), 0);
    assertEq(s_auction.getAuctionStart(address(s_mockUSDC)), block.timestamp);
    assertEq(s_mockWETH.balanceOf(address(s_auction)), 0);
    assertEq(s_mockUSDC.balanceOf(address(s_auction)), 1_000e6);
  }

  function _dealSufficientAssetBalance(
    address asset,
    bool withFeeAggregator
  ) private {
    (uint256 assetPrice,,) = s_auction.getAssetPrice(asset);
    uint8 assetDecimals = IERC20Metadata(asset).decimals();
    uint256 minGPV2CompatibleAuctionBalance = (MIN_AUCTION_SIZE_USD * 10 ** assetDecimals) / assetPrice;
    address to = withFeeAggregator ? address(s_feeAggregator) : address(s_auction);

    deal(asset, to, minGPV2CompatibleAuctionBalance);
  }
}
