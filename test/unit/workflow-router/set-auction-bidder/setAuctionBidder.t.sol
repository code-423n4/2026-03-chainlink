// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IAuctionBidder} from "src/interfaces/IAuctionBidder.sol";
import {IPriceManager} from "src/interfaces/IPriceManager.sol";

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract WorkflowRouter_SetAuctionBidderUnitTest is BaseUnitTest {
  address private immutable i_newAuctionBidder = makeAddr("newAuctionBidder");

  function setUp() external {
    vm.mockCall(
      i_newAuctionBidder,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IAuctionBidder).interfaceId),
      abi.encode(true)
    );
    vm.mockCall(
      i_newAuctionBidder,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IPriceManager).interfaceId),
      abi.encode(true)
    );
  }

  function test_setAuctionBidder_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.setAuctionBidder(i_newAuctionBidder);
  }

  function test_setAuctionBidder_RevertWhen_NewAuctionIsZeroAddress() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    s_workflowRouter.setAuctionBidder(address(0));
  }

  function test_setAuctionBidder_RevertWhen_AuctionContractDoesNotSupportIAuctionBidderInterface() external {
    vm.mockCall(
      i_newAuctionBidder,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IAuctionBidder).interfaceId),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.InvalidAuctionBidder.selector, i_newAuctionBidder));
    s_workflowRouter.setAuctionBidder(i_newAuctionBidder);
  }

  function test_setAuctionBidder_RevertWhen_NewAuctionEqOldAuction() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.ValueNotUpdated.selector));
    s_workflowRouter.setAuctionBidder(address(s_auctionBidder));
  }

  function test_setAuctionBidder() external {
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.AuctionBidderSet(i_newAuctionBidder);

    s_workflowRouter.setAuctionBidder(i_newAuctionBidder);

    assertEq(address(s_workflowRouter.getAuctionBidder()), i_newAuctionBidder);
  }
}
