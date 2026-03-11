// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {Caller} from "src/Caller.sol";
import {PriceManager} from "src/PriceManager.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract BaseAuction_BidIntegrationTest is BaseIntegrationTest, PriceManagerHelper {
  address private immutable i_auctionParticipant = makeAddr("auctionParticipant");

  uint256 private constant USDC_AUCTIONED_AMOUNT = 100_000e6; // $100,000 worth of USDC
  PriceManagerHelper.AssetPrice[] private s_assetPrices;
  Caller.Call[] private s_solution;

  BaseAuction private s_baseAuction;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    // Set asset prices
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockWETH), price: 4_000e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockUSDC), price: 1e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockLINK), price: 20e18}));

    _changePrank(i_priceAdmin);
    _transmitAssetPrices(s_baseAuction, s_assetPrices);

    // Prepare auction
    deal(address(s_mockUSDC), address(s_feeAggregator), USDC_AUCTIONED_AMOUNT); // $100,000 worth of USDC

    _changePrank(i_auctionAdmin);
    (, bytes memory performData) = s_baseAuction.checkUpkeep("");
    s_baseAuction.performUpkeep(performData);

    deal(address(s_mockLINK), address(s_auctionBidder), 5_250e18); // $105,000 worth of LINK

    _changePrank(i_auctionParticipant);
    s_mockLINK.approve(address(s_baseAuction), type(uint256).max);

    s_solution.push(
      Caller.Call({
        target: address(s_mockUSDC),
        data: abi.encodeWithSelector(IERC20.approve.selector, address(s_mockUniswapRouter), USDC_AUCTIONED_AMOUNT)
      })
    );

    _changePrank(i_auctionBidder);
  }

  function test_bid_RevertWhen_AuctionHasNotStarted() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAuction.selector, address(s_mockWETH)));
    s_auctionBidder.bid(address(s_mockWETH), 25 ether, s_solution);
  }

  function test_bid_RevertWhen_AuctionEnded() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    skip(s_baseAuction.getAssetParams(address(s_mockUSDC)).auctionDuration + 1);

    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAuction.selector, address(s_mockUSDC)));
    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, s_solution);
  }

  function test_bid_RevertWhen_Reentrancy() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    Caller.Call[] memory solution = new Caller.Call[](1);
    solution[0] = Caller.Call({
      target: address(s_baseAuction),
      data: abi.encodeWithSelector(BaseAuction.bid.selector, address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, "")
    });
    vm.expectRevert(Errors.ReentrantCall.selector);
    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, solution);
  }

  function test_bid_RevertWhen_BidValueTooLow() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.BidValueTooLow.selector, 0, MIN_BID_USD_VALUE));
    s_auctionBidder.bid(address(s_mockUSDC), 0, s_solution);
  }

  function test_bid_RevertWhen_BidAmountTooHigh() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectRevert(
      abi.encodeWithSelector(BaseAuction.BidAmountTooHigh.selector, USDC_AUCTIONED_AMOUNT + 1, USDC_AUCTIONED_AMOUNT)
    );
    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT + 1, s_solution);
  }

  function test_bid_RevertWhen_ZeroFeedData() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    // Force end running auction to clear Data Streams prices.
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    _changePrank(i_auctionAdmin);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));
    // Clear Data Streams price to force reliance on USD feed price
    _changePrank(i_priceAdmin);
    PriceManager.ApplyFeedInfoUpdateParams[] memory feedInfoUpdate = new PriceManager.ApplyFeedInfoUpdateParams[](1);
    feedInfoUpdate[0] = PriceManager.ApplyFeedInfoUpdateParams({
      asset: address(s_mockUSDC),
      feedInfo: PriceManager.FeedInfo({
        dataStreamsFeedId: bytes32(0),
        usdDataFeed: AggregatorV3Interface(address(s_mockUsdcUsdFeed)),
        dataStreamsFeedDecimals: 0,
        stalenessThreshold: STALENESS_THRESHOLD
      })
    });
    _changePrank(i_assetAdmin);
    PriceManager(s_contractUnderTest).applyFeedInfoUpdates(feedInfoUpdate, new address[](0));

    vm.mockCall(
      address(s_mockUsdcUsdFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );

    // Restart auction
    _changePrank(i_auctionAdmin);
    (, bytes memory performData) = s_baseAuction.checkUpkeep("");
    s_baseAuction.performUpkeep(performData);

    vm.mockCall(
      address(s_mockUsdcUsdFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 0, 0, block.timestamp, 0)
    );

    _changePrank(i_auctionBidder);
    vm.expectRevert(Errors.ZeroFeedData.selector);
    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, s_solution);
  }

  function test_bid_RevertWhen_StaleFeedData() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.mockCall(
      address(s_mockUsdcUsdFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );
    skip(s_baseAuction.getFeedInfo(address(s_mockUSDC)).stalenessThreshold + 1);
    vm.expectRevert(Errors.StaleFeedData.selector);

    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, s_solution);
  }

  function test_bid_RevertWhen_CallbackFailWithoutAuctionBidderError()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Using an invalid selector to force a failure without a specific error
    s_solution.push(Caller.Call({target: address(this), data: ""}));
    vm.expectRevert(Caller.LowLevelCallFailed.selector);
    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, s_solution);
  }

  function test_bid_FullAmountWithoutCallbackData() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    deal(address(s_mockLINK), address(s_auctionBidder), 5_250e18);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionBidSettled(address(s_auctionBidder), address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, 5_250e18);

    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, new Caller.Call[](0));

    assertEq(s_mockUSDC.balanceOf(address(i_auctionParticipant)), 0);
    // USDC starting price multiplier is 1.05
    // So total auction value is $105,000
    // LINK price is $20, so 105,000 / 20 = 5,250 LINK
    assertEq(s_mockLINK.balanceOf(address(s_baseAuction)), 5_250e18);
    assertEq(s_mockUSDC.balanceOf(address(s_auctionBidder)), USDC_AUCTIONED_AMOUNT);
    assertEq(s_mockLINK.balanceOf(address(i_auctionParticipant)), 0);
  }

  function test_bid_FullAuctionAmountWithCallbackData() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionBidSettled(address(s_auctionBidder), address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, 5_250e18);

    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, s_solution);

    assertEq(s_mockUSDC.balanceOf(address(i_auctionParticipant)), 0);
    // USDC starting price multiplier is 1.05
    // So total auction value is $105,000
    // LINK price is $20, so 105,000 / 20 = 5,250 LINK
    assertEq(s_mockLINK.balanceOf(address(s_baseAuction)), 5_250e18);
    assertEq(s_mockUSDC.balanceOf(address(s_auctionBidder)), USDC_AUCTIONED_AMOUNT);
    assertEq(s_mockLINK.balanceOf(address(i_auctionParticipant)), 0);
  }

  function test_bid_PartialBaseAuctionAmount() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    uint256 partialAmount = USDC_AUCTIONED_AMOUNT / 2;

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AuctionBidSettled(address(s_auctionBidder), address(s_mockUSDC), partialAmount, 2_625e18);

    s_auctionBidder.bid(address(s_mockUSDC), partialAmount, s_solution);

    // USDC starting price multiplier is 1.05
    // So total auction value is $105,000
    // LINK price is $20, so 105,000 / 20 = 5,250 LINK
    // Auction participant only bid for half the auctioned USDC, so they get half the LINK
    assertEq(s_mockUSDC.balanceOf(address(s_baseAuction)), partialAmount);
    assertEq(s_mockLINK.balanceOf(address(s_baseAuction)), 2_625e18);
    assertEq(s_mockUSDC.balanceOf(address(s_auctionBidder)), partialAmount);
    assertEq(s_mockLINK.balanceOf(address(s_reserves)), 2_625e18);
  }
}
