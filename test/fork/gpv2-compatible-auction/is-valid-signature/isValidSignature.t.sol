// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {
  BaseGPV2CompatibleAuctionForkTest
} from "test/fork/gpv2-compatible-auction/BaseGPV2CompatibleAuctionForkTest.t.sol";

import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";

contract GPV2CompatibleAuction_IsValidSignatureForkTest is BaseGPV2CompatibleAuctionForkTest {
  function test_isValidSignature() external {
    _changePrank(i_solver);
    i_gpv2Settlement.settle(s_tokens, s_clearingPrices, s_trades, s_interactions);

    // CowProtocol rounds up
    uint256 expectedLinkBalance = USDC_AMOUNT * s_clearingPrices[0] / s_clearingPrices[1] + 1;

    assertEq(IERC20(USDC).balanceOf(address(s_auction)), 0);
    assertEq(IERC20(LINK).balanceOf(address(s_auction)), expectedLinkBalance);
  }
}
