// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract WorkflowRouter_ApplyAllowlistedWorkflowsUpdatesUnitTest is BaseUnitTest {
  WorkflowRouter.AllowlistedWorkflow[] private s_allowlistedWorkflows;

  function setUp() external {
    s_allowlistedWorkflows.push();
    s_allowlistedWorkflows[0].workflowId = PRICE_ADMIN_WORKFLOW_ID;
    s_allowlistedWorkflows[0].targetSelectors.push();
    s_allowlistedWorkflows[0].targetSelectors[0].target = address(s_auction);
    s_allowlistedWorkflows[0].targetSelectors[0].selectors.push(s_auction.transmit.selector);

    s_allowlistedWorkflows.push();
    s_allowlistedWorkflows[1].workflowId = AUCTION_WORKER_WORKFLOW_ID;
    s_allowlistedWorkflows[1].targetSelectors.push();
    s_allowlistedWorkflows[1].targetSelectors[0].target = address(s_auction);
    s_allowlistedWorkflows[1].targetSelectors[0].selectors.push(s_auction.performUpkeep.selector);
    s_allowlistedWorkflows[1].targetSelectors[0].selectors.push(s_auction.invalidateOrders.selector);

    s_allowlistedWorkflows.push();
    s_allowlistedWorkflows[2].workflowId = AUCTION_BIDDER_WORKFLOW_ID;
    s_allowlistedWorkflows[2].targetSelectors.push();
    s_allowlistedWorkflows[2].targetSelectors[0].target = address(s_auctionBidder);
    s_allowlistedWorkflows[2].targetSelectors[0].selectors.push(s_auctionBidder.bid.selector);
  }

  function test_applyAllowlistedWorkflowsUpdates_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE()
    external
    whenCallerIsNotAdmin
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);
  }

  function test_applyAllowlistedWorkflowsUpdates_RevertWhen_EmptyList() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.EmptyList.selector));
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), new WorkflowRouter.AllowlistedWorkflow[](0));
  }

  function test_applyAllowlistedWorkflows_RevertWhen_RemovedWorklowIdIsNotAllowlisted() external {
    bytes32[] memory workflowIdsToRemove = new bytes32[](1);
    workflowIdsToRemove[0] = PRICE_ADMIN_WORKFLOW_ID;

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.WorkflowIdNotAllowlisted.selector, PRICE_ADMIN_WORKFLOW_ID));
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(workflowIdsToRemove, s_allowlistedWorkflows);
  }

  function test_applyAllowlistedWorkflowsUpdates_RevertWhen_WorkflowIdEqZero() external {
    s_allowlistedWorkflows[0].workflowId = bytes32(0);

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroValue.selector));
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);
  }

  function test_applyAllowlistedWorkflowsUpdates_Add() external {
    for (uint256 i; i < s_allowlistedWorkflows.length; ++i) {
      bytes32 workflowId = s_allowlistedWorkflows[i].workflowId;

      for (uint256 j; j < s_allowlistedWorkflows[i].targetSelectors.length; j++) {
        address target = s_allowlistedWorkflows[i].targetSelectors[j].target;

        for (uint256 k; k < s_allowlistedWorkflows[i].targetSelectors[j].selectors.length; k++) {
          bytes4 selector = s_allowlistedWorkflows[i].targetSelectors[j].selectors[k];
          vm.expectEmit(address(s_workflowRouter));
          emit WorkflowRouter.SelectorAllowlisted(workflowId, target, selector);
        }
      }
    }
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);

    _assertAllowlistedWorkflows();
  }

  function test_applyAllowlistedWorkflowsUpdates_Removes() external {
    // First add the allowlisted workflows
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);

    bytes32[] memory workflowIdsToRemove = new bytes32[](2);
    workflowIdsToRemove[0] = s_allowlistedWorkflows[1].workflowId; // AUCTION_WORKER_WORKFLOW_ID
    workflowIdsToRemove[1] = s_allowlistedWorkflows[2].workflowId; // AUCTION_BIDDER_WORKFLOW_ID
    s_allowlistedWorkflows.pop(); // AUCTION_BIDDER_WORKFLOW_ID
    s_allowlistedWorkflows.pop(); // AUCTION_WORKER_WORKFLOW_ID

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.WorkflowIdRemovedFromAllowlist(AUCTION_WORKER_WORKFLOW_ID); //

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.WorkflowIdRemovedFromAllowlist(AUCTION_BIDDER_WORKFLOW_ID);

    s_workflowRouter.applyAllowlistedWorkflowsUpdates(workflowIdsToRemove, new WorkflowRouter.AllowlistedWorkflow[](0));

    _assertAllowlistedWorkflows();

    // Assert all targets and selectors for the removed workflow id were cleaned up.
    assertEq(s_workflowRouter.getAllowlistedTargets(AUCTION_WORKER_WORKFLOW_ID).length, 0);
    assertEq(s_workflowRouter.getAllowlistedTargets(AUCTION_BIDDER_WORKFLOW_ID).length, 0);
    assertEq(s_workflowRouter.getAllowlistedSelectors(AUCTION_WORKER_WORKFLOW_ID, address(s_auction)).length, 0);
    assertEq(s_workflowRouter.getAllowlistedSelectors(AUCTION_BIDDER_WORKFLOW_ID, address(s_auctionBidder)).length, 0);
  }

  function test_applyAllowlistedWorkflowsUpdates_MixedScenario() external {
    // First add the allowlisted workflows
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);

    // Update PRICE_ADMIN_WORKFLOW_ID to have 2 selectors
    s_allowlistedWorkflows[0].targetSelectors[0].selectors.push(s_auction.checkUpkeep.selector);

    // Remove AUCTION_BIDDER_WORKFLOW_ID
    bytes32[] memory removes = new bytes32[](1);
    removes[0] = AUCTION_BIDDER_WORKFLOW_ID;
    s_allowlistedWorkflows.pop();

    // Add a new worfow id
    bytes32 newWorkflowId = keccak256("NEW_WORKFLOW");
    s_allowlistedWorkflows.push();
    s_allowlistedWorkflows[2].workflowId = newWorkflowId;
    s_allowlistedWorkflows[2].targetSelectors.push();
    s_allowlistedWorkflows[2].targetSelectors[0].target = address(s_feeAggregator);
    s_allowlistedWorkflows[2].targetSelectors[0].selectors.push(s_feeAggregator.transferForSwap.selector);

    s_workflowRouter.applyAllowlistedWorkflowsUpdates(removes, s_allowlistedWorkflows);

    _assertAllowlistedWorkflows();
  }

  function _assertAllowlistedWorkflows() private view {
    bytes32[] memory allowlistedWorkflowIds = s_workflowRouter.getAllowlistedWorkflowIds();
    assertEq(allowlistedWorkflowIds.length, s_allowlistedWorkflows.length);
    for (uint256 i; i < s_allowlistedWorkflows.length; ++i) {
      bytes32 workflowId = s_allowlistedWorkflows[i].workflowId;
      assertEq(allowlistedWorkflowIds[i], workflowId);

      address[] memory allowlistedTargets = s_workflowRouter.getAllowlistedTargets(workflowId);
      assertEq(allowlistedTargets.length, s_allowlistedWorkflows[i].targetSelectors.length);

      for (uint256 j; j < s_allowlistedWorkflows[i].targetSelectors.length; j++) {
        address target = s_allowlistedWorkflows[i].targetSelectors[j].target;
        assertEq(allowlistedTargets[j], target);

        bytes4[] memory allowlistedSelectors = s_workflowRouter.getAllowlistedSelectors(workflowId, target);
        assertEq(allowlistedSelectors.length, s_allowlistedWorkflows[i].targetSelectors[j].selectors.length);

        for (uint256 k; k < s_allowlistedWorkflows[i].targetSelectors[j].selectors.length; k++) {
          bytes4 selector = s_allowlistedWorkflows[i].targetSelectors[j].selectors[k];
          assertEq(allowlistedSelectors[k], selector);
        }
      }
    }
  }
}
