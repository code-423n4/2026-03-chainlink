// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Caller} from "src/Caller.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

contract AuctionBidder_AuctionCallbackUnitTest is BaseUnitTest {
  function setUp() external {
    _changePrank(address(s_auction));
  }

  function test_auctionCallback_RevertWhen_InvalidCaller() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.AccessForbidden.selector));
    _changePrank(i_owner);
    s_auctionBidder.auctionCallback(address(s_auctionBidder), i_asset1, 1 ether, "data");
  }

  function test_auctionCallback_RevertWhen_InvalidAuctionContractCaller() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.AccessForbidden.selector));
    s_auctionBidder.auctionCallback(i_owner, i_asset1, 1 ether, "data");
  }

  function test_auctionCallback_RevertWhen_EmptyCalls() external {
    vm.expectRevert(Errors.EmptyList.selector);
    _changePrank(address(s_auction));
    s_auctionBidder.auctionCallback(address(s_auctionBidder), i_asset1, 1 ether, abi.encode(new Caller.Call[](0)));
  }
}
