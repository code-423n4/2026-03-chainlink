// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {Caller} from "src/Caller.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";
import {GPv2Order} from "@cowprotocol/libraries/GPv2Order.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract GPV2CompatibleAuction_IsValidSignatureIntegrationTest is BaseIntegrationTest, PriceManagerHelper {
  GPv2Order.Data private s_order;
  bytes32 private s_orderId;

  function setUp() external {
    s_order = GPv2Order.Data({
      sellToken: IERC20(address(s_mockUSDC)),
      buyToken: IERC20(address(s_mockLINK)),
      receiver: address(s_auction),
      sellAmount: 100_000e6,
      // Asset 2 price = $1
      // Link price = $20
      // Elapsed time = 0
      // Starting price multiplier = 1.05 (5% premium)
      // GPV2CompatibleAuction price = $100,000 * 1.05 / $20 = 5,250 LINK
      buyAmount: 5_250e18,
      validTo: uint32(block.timestamp),
      appData: bytes32(0),
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    deal(address(s_mockUSDC), address(s_feeAggregator), s_order.sellAmount);

    // Start auction
    _changePrank(i_auctionAdmin);
    (, bytes memory performData) = s_auction.checkUpkeep("");
    s_auction.performUpkeep(performData);
  }

  function test_isValidSignature_RevertWhen_ReentrantCallFromBid() external {
    Caller.Call[] memory solution = new Caller.Call[](1);
    solution[0] = Caller.Call({
      target: address(s_auction),
      data: abi.encodeWithSelector(GPV2CompatibleAuction.isValidSignature.selector, s_orderId, abi.encode(s_order))
    });
    vm.expectRevert(Errors.ReentrantCall.selector);
    _changePrank(i_forwarder);
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_BIDDER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(
        address(s_auctionBidder),
        abi.encodeWithSelector(s_auctionBidder.bid.selector, address(s_mockUSDC), s_order.sellAmount, solution)
      )
    );
  }

  function test_isValidSignature_RevertWhen_ContractIsPaused() external givenContractIsPaused(address(s_auction)) {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InvalidOrderId() external {
    s_orderId = bytes32("invalidOrderId");

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.InvalidOrderId.selector, s_orderId));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InvalidGPV2CompatibleAuction() external {
    s_order.sellToken = IERC20(address(s_mockWETH));
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAuction.selector, address(s_order.sellToken)));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_BuyTokenNeqAssetOut() external {
    s_order.buyToken = IERC20(address(s_mockWETH));
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(
      abi.encodeWithSelector(GPV2CompatibleAuction.InvalidBuyToken.selector, address(s_order.buyToken), s_mockLINK)
    );
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InvalidReceiver() external {
    s_order.receiver = address(this);
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(
      abi.encodeWithSelector(GPV2CompatibleAuction.InvalidReceiver.selector, s_order.receiver, address(s_auction))
    );
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_ZeroSellAmount() external {
    s_order.sellAmount = 0;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(Errors.InvalidZeroAmount.selector);
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InsufficientAssetInBalance() external {
    s_order.sellAmount = s_order.sellAmount + 1;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(
      abi.encodeWithSelector(
        GPV2CompatibleAuction.InsufficientAssetInBalance.selector,
        address(s_mockUSDC),
        s_order.sellAmount,
        s_order.sellAmount - 1
      )
    );
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_BuyAmountLtGPV2CompatibleAuctionPrice() external {
    s_order.buyAmount = s_order.buyAmount - 1;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(
      abi.encodeWithSelector(
        GPV2CompatibleAuction.InsufficientBuyAmount.selector, s_order.buyAmount, s_order.buyAmount + 1
      )
    );
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_ExpiredOrder() external {
    vm.warp(s_order.validTo + 1);

    vm.expectRevert(
      abi.encodeWithSelector(GPV2CompatibleAuction.ExpiredOrder.selector, s_order.validTo, block.timestamp)
    );
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_AuctionDurationElapsed() external {
    vm.warp(block.timestamp + s_auction.getAssetParams(address(s_mockUSDC)).auctionDuration + 1);

    // Refresh prices
    s_mockLinkUsdFeed.transmit(int192(20e8));
    s_mockUsdcUsdFeed.transmit(int192(1e8));

    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAuction.selector, address(s_order.sellToken)));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_InvalidFeeAmount() external {
    s_order.feeAmount = 1;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.InvalidFeeAmount.selector));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_InvalidOrderKind() external {
    s_order.kind = GPv2Order.KIND_BUY;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.InvalidOrderKind.selector, s_order.kind));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_OrderNotPartiallyFillable() external {
    s_order.partiallyFillable = false;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.OrderNotPartiallyFillable.selector));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InvalidSellTokenBalance() external {
    s_order.sellTokenBalance = GPv2Order.BALANCE_INTERNAL;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.InvalidTokenBalanceMarker.selector));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature_RevertWhen_InvalidBuyTokenBalance() external {
    s_order.buyTokenBalance = GPv2Order.BALANCE_INTERNAL;
    s_orderId = GPv2Order.hash(s_order, s_mockGPV2Settlement.domainSeparator());

    vm.expectRevert(abi.encodeWithSelector(GPV2CompatibleAuction.InvalidTokenBalanceMarker.selector));
    s_auction.isValidSignature(s_orderId, abi.encode(s_order));
  }

  function test_isValidSignature() external view {
    bytes4 magicValue = s_auction.isValidSignature(s_orderId, abi.encode(s_order));

    assertEq(magicValue, IERC1271.isValidSignature.selector);
  }
}
