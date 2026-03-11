// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IBaseAuction} from "src/interfaces/IBaseAuction.sol";
import {IPriceManager} from "src/interfaces/IPriceManager.sol";

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract WorkflowRouter_SetAuctionUnitTest is BaseUnitTest {
  address private immutable i_newAuction = makeAddr("newAuction");

  function setUp() external {
    vm.mockCall(
      i_newAuction,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IBaseAuction).interfaceId),
      abi.encode(true)
    );
    vm.mockCall(
      i_newAuction,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IPriceManager).interfaceId),
      abi.encode(true)
    );
  }

  function test_setAuction_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.setAuction(i_newAuction);
  }

  function test_setAuction_RevertWhen_NewAuctionIsZeroAddress() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    s_workflowRouter.setAuction(address(0));
  }

  function test_setAuction_RevertWhen_AuctionContractDoesNotSupportIBaseAuctionInterface() external {
    vm.mockCall(
      i_newAuction,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IBaseAuction).interfaceId),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.InvalidAuctionContract.selector, i_newAuction));
    s_workflowRouter.setAuction(i_newAuction);
  }

  function test_setAuction_RevertWhen_NewAuctionEqOldAuction() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.ValueNotUpdated.selector));
    s_workflowRouter.setAuction(address(s_auction));
  }

  function test_setAuction() external {
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.AuctionSet(i_newAuction);

    s_workflowRouter.setAuction(i_newAuction);

    assertEq(s_workflowRouter.getAuction(), i_newAuction);
  }
}
