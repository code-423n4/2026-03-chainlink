// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {Caller} from "src/Caller.sol";
import {PriceManager} from "src/PriceManager.sol";
import {BasePriceManagerForkTest} from "test/fork/price-manager/BasePriceManagerForkTest.t.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

contract WorkflowRouter_OnReportForkTest is BasePriceManagerForkTest {
  uint256 private constant USDC_AMOUNT = 100_000e6;

  function setUp() external {
    // We warp back to avoid price staleness issues. This way the prices with a future timestamp are transmitted
    // successfully and once we skip to bring the auction price down, the prices are still fresh.
    vm.warp(block.timestamp - s_auction.getAssetParams(USDC).auctionDuration);

    deal(USDC, address(s_feeAggregator), USDC_AMOUNT);

    _changePrank(i_forwarder);
  }

  function test_onReport_Transmit() external {
    vm.expectEmit(address(s_auction));
    emit PriceManager.PriceTransmitted(LINK, uint256(uint192(s_linkReport.price)));
    vm.expectEmit(address(s_auction));
    emit PriceManager.PriceTransmitted(WETH, uint256(uint192(s_ethReport.price)));
    vm.expectEmit(address(s_auction));
    emit PriceManager.PriceTransmitted(USDC, uint256(uint192(s_usdcReport.price)));
    s_workflowRouter.onReport(
      abi.encodePacked(PRICE_ADMIN_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.transmit.selector, s_unverifiedReports))
    );

    (uint256 linkPrice, uint256 linkUpdatedAt, bool isLinkPriceValid) = s_auction.getAssetPrice(LINK);
    (uint256 ethPrice, uint256 ethUpdatedAt, bool isEthPriceValid) = s_auction.getAssetPrice(WETH);
    (uint256 usdcPrice, uint256 usdcUpdatedAt, bool isUsdcPriceValid) = s_auction.getAssetPrice(USDC);

    assertEq(linkPrice, uint256(uint192(s_linkReport.price)));
    assertEq(linkUpdatedAt, s_linkReport.observationsTimestamp);
    assertTrue(isLinkPriceValid);
    assertEq(ethPrice, uint256(uint192(s_ethReport.price)));
    assertEq(ethUpdatedAt, s_ethReport.observationsTimestamp);
    assertTrue(isEthPriceValid);
    assertEq(usdcPrice, uint256(uint192(s_usdcReport.price)));
    assertEq(usdcUpdatedAt, s_usdcReport.observationsTimestamp);
    assertTrue(isUsdcPriceValid);
  }

  function test_onReport_PerformUpkeep() external {
    // 1. Transmit prices
    s_workflowRouter.onReport(
      abi.encodePacked(PRICE_ADMIN_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.transmit.selector, s_unverifiedReports))
    );

    (, bytes memory performData) = s_auction.checkUpkeep("");

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(USDC);

    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.performUpkeep.selector, performData))
    );

    assertEq(s_auction.getAuctionStart(USDC), block.timestamp);
    assertEq(IERC20(USDC).balanceOf(address(s_auction)), USDC_AMOUNT);
    assertEq(IERC20(USDC).balanceOf(address(s_feeAggregator)), 0);
  }

  function test_onReport_Bid() external {
    // 1. Transmit prices
    s_workflowRouter.onReport(
      abi.encodePacked(PRICE_ADMIN_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.transmit.selector, s_unverifiedReports))
    );
    // 2. Start auction
    (, bytes memory performData) = s_auction.checkUpkeep("");
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.performUpkeep.selector, performData))
    );
    // 3.Skip to end of auction
    skip(s_auction.getAssetParams(USDC).auctionDuration);
    // 4. Push solution to bidder
    Caller.Call[] memory solution = new Caller.Call[](2);
    // Approve USDC to Uniswap Router
    solution[0] =
      Caller.Call({target: USDC, data: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_ROUTER, USDC_AMOUNT)});
    // Swap USDC to WETH and send to Auction
    solution[1] = Caller.Call({
      target: UNISWAP_ROUTER,
      data: abi.encodeWithSelector(
        IV3SwapRouter.exactInput.selector,
        IV3SwapRouter.ExactInputParams({
          path: bytes.concat(bytes20(USDC), bytes3(uint24(3000)), bytes20(WETH), bytes3(uint24(3000)), bytes20(LINK)),
          recipient: address(s_auctionBidder),
          amountIn: USDC_AMOUNT,
          amountOutMinimum: 0
        })
      )
    });

    // At the forked block, the Uniswap V3 swap yields 5609.110129934100732375 LINK
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_BIDDER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(
        address(s_auctionBidder), abi.encodeWithSelector(s_auctionBidder.bid.selector, USDC, USDC_AMOUNT, solution)
      )
    );
    assertEq(IERC20(LINK).balanceOf(address(s_auction)), 5_609.110129934100732375e18);
    assertEq(IERC20(LINK).balanceOf(address(s_auctionBidder)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auction)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auctionBidder)), 0);
  }
}
