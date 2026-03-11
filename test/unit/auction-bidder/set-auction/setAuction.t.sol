// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseAuction} from "src/interfaces/IBaseAuction.sol";

import {AuctionBidder} from "src/AuctionBidder.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract AuctionBidder_SetAuctionUnitTest is BaseUnitTest {
  address private immutable i_newAuction = makeAddr("newAuction");

  function setUp() external {
    vm.mockCall(
      i_newAuction,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IBaseAuction).interfaceId),
      abi.encode(true)
    );
  }

  function test_setAuction_RevertWhen_CallerDoesNotDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_auctionBidder.setAuction(i_newAuction);
  }

  function test_setAuction_RevertWhen_NewAuctionIsZeroAddress() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    s_auctionBidder.setAuction(address(0));
  }

  function test_setAuction_RevertWhen_AuctionContractDoesNotSupportIBaseAuctionInterface() external {
    vm.mockCall(
      i_newAuction,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IBaseAuction).interfaceId),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(AuctionBidder.InvalidAuctionContract.selector, i_newAuction));
    s_auctionBidder.setAuction(i_newAuction);
  }

  function test_setAuction_RevertWhen_NewAuctionEqOldAuction() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.ValueNotUpdated.selector));
    s_auctionBidder.setAuction(address(s_auction));
  }

  function test_setAuction() external {
    vm.expectEmit(address(s_auctionBidder));
    emit AuctionBidder.AuctionContractSet(i_newAuction);

    s_auctionBidder.setAuction(i_newAuction);

    assertEq(address(s_auctionBidder.getAuction()), i_newAuction);
  }
}
