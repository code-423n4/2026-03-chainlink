// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AuctionBidder} from "src/AuctionBidder.sol";

import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AuctionBidder_SetReceiverUnitTest is BaseUnitTest {
  function test_setReceiver_RevertWhen_CallerDoesNotDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_auctionBidder.setReceiver(i_receiver);
  }

  function test_setReceiver_RevertWhen_NewReceiverEqOldReceiver() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.ValueNotUpdated.selector));
    s_auctionBidder.setReceiver(address(s_auction));
  }

  function test_setReceiverToNonZeroAddress() external {
    address newReceiver = makeAddr("newReceiver");

    vm.expectEmit(address(s_auctionBidder));
    emit AuctionBidder.ReceiverSet(newReceiver);

    s_auctionBidder.setReceiver(newReceiver);

    assertEq(s_auctionBidder.getReceiver(), newReceiver);
  }

  function test_setReceiverToZeroAddress() external {
    vm.expectEmit(address(s_auctionBidder));
    emit AuctionBidder.ReceiverSet(address(0));

    s_auctionBidder.setReceiver(address(0));

    assertEq(s_auctionBidder.getReceiver(), address(0));
  }
}
