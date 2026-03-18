// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "src/libraries/Roles.sol";
import {
  BaseGPV2CompatibleAuctionForkTest
} from "test/fork/gpv2-compatible-auction/BaseGPV2CompatibleAuctionForkTest.t.sol";

import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";
import {GPv2Order} from "@cowprotocol/libraries/GPv2Order.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract GPV2CompatibleAuction_InvalidateOrdersForkTest is BaseGPV2CompatibleAuctionForkTest {
  bytes[] private s_orderUids;

  function setUp() external {
    bytes32 usdcOrderDigest = GPv2Order.hash(s_usdcOrder, i_gpv2Settlement.domainSeparator());

    GPv2Order.Data memory wethOrder = GPv2Order.Data({
      sellToken: IERC20(WETH),
      buyToken: IERC20(LINK),
      receiver: address(s_auction),
      sellAmount: WETH_AMOUNT,
      buyAmount: s_auction.getAssetOutAmount(WETH, WETH_AMOUNT, block.timestamp),
      validTo: uint32(block.timestamp + 1 hours),
      appData: bytes32(0),
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });
    bytes32 wethOrderDigest = GPv2Order.hash(wethOrder, i_gpv2Settlement.domainSeparator());

    s_orderUids.push(abi.encodePacked(usdcOrderDigest, address(s_auction), s_usdcOrder.validTo));
    s_orderUids.push(abi.encodePacked(wethOrderDigest, address(s_auction), wethOrder.validTo));

    _changePrank(i_forwarder);
  }

  function test_invalidateOrders_RevertWhen_CallerDoesNotHaveORDER_MANAGER_ROLE() external {
    _changePrank(i_owner);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.ORDER_MANAGER_ROLE
      )
    );
    s_auction.invalidateOrders(s_orderUids);
  }

  function test_invalidateOrders() external {
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.invalidateOrders.selector, s_orderUids))
    );

    // Attempting to settle should generate an overflow since the order amount is added to the filled amount which is
    // set to max uint256 in order to invalidate the order
    vm.expectRevert("SafeMath: addition overflow");
    _changePrank(i_solver);
    i_gpv2Settlement.settle(s_tokens, s_clearingPrices, s_trades, s_interactions);

    (, bytes memory result) =
      GP_V2_SETTLEMENT.staticcall(abi.encodeWithSignature("filledAmount(bytes)", s_orderUids[0]));
    uint256 usdcFilledAmount = abi.decode(result, (uint256));
    (, result) = GP_V2_SETTLEMENT.staticcall(abi.encodeWithSignature("filledAmount(bytes)", s_orderUids[1]));
    uint256 wethFilledAmount = abi.decode(result, (uint256));

    assertEq(usdcFilledAmount, type(uint256).max);
    assertEq(wethFilledAmount, type(uint256).max);
  }
}
