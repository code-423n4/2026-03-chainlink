// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AuctionBidder} from "src/AuctionBidder.sol";
import {IAuctionCallback} from "src/interfaces/IAuctionCallback.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

contract AuctionBidder_ConstructorUnitTest is BaseUnitTest {
  function test_constructor_RevertWhen_AuctionIsZeroAddress() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(0), i_receiver);
  }

  function test_constructor_WithReceiverNeqAddressZero() external {
    vm.expectEmit();
    emit AuctionBidder.AuctionContractSet(address(s_auction));
    vm.expectEmit();
    emit AuctionBidder.ReceiverSet(i_receiver);

    AuctionBidder auctionBidder =
      new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), i_receiver);

    assertEq(address(auctionBidder.getAuction()), address(s_auction));
    assertEq(auctionBidder.getReceiver(), i_receiver);
    assertEq(auctionBidder.typeAndVersion(), "AuctionBidder 1.0.0-dev");
    assertTrue(auctionBidder.supportsInterface(type(IAuctionCallback).interfaceId));
  }

  function test_constructor_WithReceiverEqAddressZero() external {
    vm.expectEmit();
    emit AuctionBidder.AuctionContractSet(address(s_auction));

    AuctionBidder auctionBidder =
      new AuctionBidder(DEFAULT_ADMIN_TRANSFER_DELAY, i_owner, address(s_auction), address(0));

    assertEq(address(auctionBidder.getAuction()), address(s_auction));
    assertEq(auctionBidder.getReceiver(), address(0));
    assertEq(auctionBidder.typeAndVersion(), "AuctionBidder 1.0.0-dev");
    assertTrue(auctionBidder.supportsInterface(type(IAuctionCallback).interfaceId));
  }
}
