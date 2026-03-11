// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract WorkflowRouter_SetWorkflowIdsUnitTest is BaseUnitTest {
  WorkflowRouter.SetWorkflowIdParams[] private s_workflowIds;

  function setUp() external {
    s_workflowIds.push(
      WorkflowRouter.SetWorkflowIdParams({
        workflowType: WorkflowRouter.WorkflowType.PRICE_ADMIN, workflowId: PRICE_ADMIN_WORKFLOW_ID
      })
    );
    s_workflowIds.push(
      WorkflowRouter.SetWorkflowIdParams({
        workflowType: WorkflowRouter.WorkflowType.AUCTION_WORKER, workflowId: AUCTION_WORKER_WORKFLOW_ID
      })
    );
    s_workflowIds.push(
      WorkflowRouter.SetWorkflowIdParams({
        workflowType: WorkflowRouter.WorkflowType.AUCTION_BIDDER, workflowId: AUCTION_BIDDER_WORKFLOW_ID
      })
    );
  }

  function test_setWorkflowIds_RevertWhen_CallerDoesNotHaveTheDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.setWorkflowIds(s_workflowIds);
  }

  function test_setWorkflowIds_RevertWhen_WorkflowIdEqZero() external {
    s_workflowIds[0].workflowId = bytes32(0);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroValue.selector));
    s_workflowRouter.setWorkflowIds(s_workflowIds);
  }

  function test_setWorkflowIds_RevertWhen_WorkflowIdAlreadySet() external {
    s_workflowRouter.setWorkflowIds(s_workflowIds);

    vm.expectRevert(abi.encodeWithSelector(Errors.ValueNotUpdated.selector));
    s_workflowRouter.setWorkflowIds(s_workflowIds);
  }

  function test_setWorkflowIds() external {
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.WorkflowIdSet(s_workflowIds[0].workflowType, s_workflowIds[0].workflowId);
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.WorkflowIdSet(s_workflowIds[1].workflowType, s_workflowIds[1].workflowId);
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.WorkflowIdSet(s_workflowIds[2].workflowType, s_workflowIds[2].workflowId);

    s_workflowRouter.setWorkflowIds(s_workflowIds);

    assertEq(s_workflowRouter.getWorkflowId(s_workflowIds[0].workflowType), s_workflowIds[0].workflowId);
    assertEq(s_workflowRouter.getWorkflowId(s_workflowIds[1].workflowType), s_workflowIds[1].workflowId);
    assertEq(s_workflowRouter.getWorkflowId(s_workflowIds[2].workflowType), s_workflowIds[2].workflowId);
  }
}
