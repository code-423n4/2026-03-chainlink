// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";

import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IReceiver} from "@chainlink/contracts/src/v0.8/keystone/interfaces/IReceiver.sol";

contract WorkflowRouter_ConstructorUnitTest is BaseUnitTest {
  WorkflowRouter.ConstructorParams private s_constructorParams;

  function setUp() external {
    s_constructorParams.admin = i_owner;
    s_constructorParams.adminRoleTransferDelay = DEFAULT_ADMIN_TRANSFER_DELAY;
    s_constructorParams.auction = address(s_auction);
    s_constructorParams.auctionBidder = address(s_auctionBidder);
    s_constructorParams.workflowIds
      .push(
        WorkflowRouter.SetWorkflowIdParams({
          workflowType: WorkflowRouter.WorkflowType.PRICE_ADMIN, workflowId: PRICE_ADMIN_WORKFLOW_ID
        })
      );
    s_constructorParams.workflowIds
      .push(
        WorkflowRouter.SetWorkflowIdParams({
          workflowType: WorkflowRouter.WorkflowType.AUCTION_WORKER, workflowId: AUCTION_WORKER_WORKFLOW_ID
        })
      );
  }

  function test_constructor_RevertWhen_AuctionIsZeroAddress() external {
    s_constructorParams.auction = address(0);

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor_RevertWhen_AuctionContractDoesNotSupportIBaseAuctionInterface() external {
    s_constructorParams.auction = address(s_workflowRouter);

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.InvalidAuctionContract.selector, s_constructorParams.auction));
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor_RevertWhen_AuctionContractDoesNotSupportIPriceManagerInterface() external {
    s_constructorParams.auction = address(s_workflowRouter);

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.InvalidAuctionContract.selector, s_constructorParams.auction));
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor_RevertWhen_AuctionBidderIsZeroAddress() external {
    s_constructorParams.auctionBidder = address(0);

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor_RevertWhen_AuctionBidderContractDoesNotSupportIAuctionBidderInterface() external {
    s_constructorParams.auctionBidder = address(s_workflowRouter);

    vm.expectRevert(
      abi.encodeWithSelector(WorkflowRouter.InvalidAuctionBidder.selector, s_constructorParams.auctionBidder)
    );
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor_RevertWhen_WorkflowIdEqZero() external {
    s_constructorParams.workflowIds[0].workflowId = bytes32(0);

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroValue.selector));
    new WorkflowRouter(s_constructorParams);
  }

  function test_constructor() external {
    vm.expectEmit();
    emit WorkflowRouter.AuctionSet(address(s_auction));
    vm.expectEmit();
    emit WorkflowRouter.WorkflowIdSet(
      s_constructorParams.workflowIds[0].workflowType, s_constructorParams.workflowIds[0].workflowId
    );
    vm.expectEmit();
    emit WorkflowRouter.WorkflowIdSet(
      s_constructorParams.workflowIds[1].workflowType, s_constructorParams.workflowIds[1].workflowId
    );
    WorkflowRouter workflowRouter = new WorkflowRouter(s_constructorParams);

    assertEq(address(workflowRouter.getAuction()), s_constructorParams.auction);
    assertEq(
      workflowRouter.getWorkflowId(s_constructorParams.workflowIds[0].workflowType),
      s_constructorParams.workflowIds[0].workflowId
    );
    assertEq(
      workflowRouter.getWorkflowId(s_constructorParams.workflowIds[1].workflowType),
      s_constructorParams.workflowIds[1].workflowId
    );
    assertTrue(workflowRouter.supportsInterface(type(IReceiver).interfaceId));
    assertEq(workflowRouter.typeAndVersion(), "WorkflowRouter 1.0.0-dev");
  }
}
