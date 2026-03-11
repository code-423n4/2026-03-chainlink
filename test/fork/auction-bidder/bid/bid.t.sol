// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Caller} from "src/Caller.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BasePriceManagerForkTest} from "test/fork/price-manager/BasePriceManagerForkTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

contract AuctionBidder_BidForkTest is BasePriceManagerForkTest {
  uint256 private constant USDC_AMOUNT = 100_000e6;

  IV3SwapRouter private immutable i_uniswapRouter = IV3SwapRouter(UNISWAP_ROUTER);

  Caller.Call[] private s_solution;

  modifier whenCallerIsNotAuctionBidder() {
    _changePrank(i_owner);
    _;
  }

  function setUp() external {
    // We warp back to avoid price staleness issues. This way the prices with a future timestamp are transmitted
    // successfully and once we skip to bring the auction price down, the prices are still fresh.
    vm.warp(block.timestamp - s_auction.getAssetParams(USDC).auctionDuration);

    // We set the receiver to another address than the auction contract to make the accounting tests easier. This way
    // outstanding amounts end up on a separate address.
    s_auctionBidder.setReceiver(i_receiver);

    _changePrank(i_priceAdmin);
    s_auction.transmit(s_unverifiedReports);

    deal(USDC, address(s_feeAggregator), 100_000e6);

    _changePrank(i_auctionAdmin);
    (, bytes memory performData) = s_auction.checkUpkeep("");
    s_auction.performUpkeep(performData);

    s_solution.push(
      Caller.Call({target: USDC, data: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_ROUTER, USDC_AMOUNT)})
    );
    s_solution.push(
      Caller.Call({
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
      })
    );

    skip(s_auction.getAssetParams(USDC).auctionDuration);

    _changePrank(i_auctionBidder);
  }

  function test_solve_RevertWhen_ContractIsPaused() external givenContractIsPaused(address(s_auctionBidder)) {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_auctionBidder.bid(USDC, USDC_AMOUNT, s_solution);
  }

  function test_solve_RevertWhen_CallerDoesNotHaveAuctionBidderRole() external whenCallerIsNotAuctionBidder {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.AUCTION_BIDDER_ROLE
      )
    );
    s_auctionBidder.bid(USDC, USDC_AMOUNT, s_solution);
  }

  function test_solve_WithOutstandingAmount() external {
    // LINK/USD price is $17.730725215735380000
    // USDC/USD price is $0.999941200000000000
    // Price multiplier = startingPriceMultiplier - (startingPriceMultiplier - endingPriceMultiplier)
    //                  = 1.05 - (1.05 - 0.99)
    //                  = 1.05 - 0.06
    //                  = 0.99
    // End of Auctioned usd value = 100,000 * 0.9999412 * 0.99 = $98,994.1788
    // End of auction LINK value = 98,994.1788 / 17.730725215735380000 = 5,583.199648943080563226 LINK -> rounded up
    // At the forked block, the Uniswap V3 swap yields 5609.110129934100732375 LINK
    // Outstanding amount = 5,609.110129934100732375 - 5,583.199648943080563226 = 25.910480991020169149
    vm.expectEmit(LINK);
    emit IERC20.Transfer(address(s_auctionBidder), i_receiver, 25.910480991020169149e18);

    s_auctionBidder.bid(USDC, USDC_AMOUNT, s_solution);

    assertEq(IERC20(LINK).balanceOf(address(s_auction)), 5_583.199648943080563226e18);
    assertEq(IERC20(LINK).balanceOf(i_receiver), 25.910480991020169149e18);
    assertEq(IERC20(LINK).balanceOf(address(s_auctionBidder)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auction)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auctionBidder)), 0);
  }

  function test_solve_WithoutOutstandingAmount() external {
    // To avoid an outstanding amount, we add a transfer call to the solution that sends the exact outstanding amount to
    // the another address.
    s_solution.push(
      Caller.Call({
        target: LINK, data: abi.encodeWithSelector(IERC20.transfer.selector, address(this), 25.910480991020169149e18)
      })
    );

    s_auctionBidder.bid(USDC, USDC_AMOUNT, s_solution);

    assertEq(IERC20(LINK).balanceOf(address(s_auction)), 5_583.199648943080563226e18);
    assertEq(IERC20(LINK).balanceOf(i_receiver), 0);
    assertEq(IERC20(LINK).balanceOf(address(s_auctionBidder)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auction)), 0);
    assertEq(IERC20(USDC).balanceOf(address(s_auctionBidder)), 0);
  }
}
