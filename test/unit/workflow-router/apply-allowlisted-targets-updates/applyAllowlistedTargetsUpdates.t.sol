// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract WorkflowRouter_ApplyAllowlistedTargetsUpdatesUnitTest is BaseUnitTest {
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

    // Allowlisted worfklows, targets and selectors
    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), s_allowlistedWorkflows);
  }

  function test_applyAllowlistedTargetsUpdates_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE()
    external
    whenCallerIsNotAdmin
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, new address[](0), new WorkflowRouter.TargetSelectors[](0)
    );
  }

  function test_applyAllowlistedTargetsUpdates_RevertWhen_EmptyList() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.EmptyList.selector));
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, new address[](0), new WorkflowRouter.TargetSelectors[](0)
    );
  }

  function test_applyAllowlistedTargetsUpdates_RevertWhen_RemovedTargetWorklowIdIsNotAllowlisted() external {
    bytes32 nonAllowlistedWorkflowId = keccak256("nonAllowlistedWorkflowId");

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.WorkflowIdNotAllowlisted.selector, nonAllowlistedWorkflowId));
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      nonAllowlistedWorkflowId, new address[](0), s_allowlistedWorkflows[0].targetSelectors
    );
  }

  function test_applyAllowlistedTargetsUpdates_RevertWhen_TargetNotAllowlisted() external {
    address[] memory removes = new address[](1);
    removes[0] = address(s_feeAggregator);

    vm.expectRevert(
      abi.encodeWithSelector(
        WorkflowRouter.TargetNotAllowlisted.selector, AUCTION_WORKER_WORKFLOW_ID, address(s_feeAggregator)
      )
    );
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, removes, new WorkflowRouter.TargetSelectors[](0)
    );
  }

  function test_applyAllowlistedTargetsUpdates_RevertWhen_TargetEqAddressZero() external {
    s_allowlistedWorkflows[0].targetSelectors[0].target = address(0);

    vm.expectRevert(Errors.InvalidZeroAddress.selector);
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      s_allowlistedWorkflows[0].workflowId, new address[](0), s_allowlistedWorkflows[0].targetSelectors
    );
  }

  function test_applyAllowlistedTargetsUpdates_Removes() external {
    address[] memory removes = new address[](1);
    removes[0] = address(s_auction);

    s_workflowRouter.getAllowlistedTargets(AUCTION_WORKER_WORKFLOW_ID);

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), s_auction.performUpkeep.selector
    );
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), s_auction.invalidateOrders.selector
    );
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.TargetRemovedFromAllowlist(AUCTION_WORKER_WORKFLOW_ID, address(s_auction));

    s_workflowRouter.applyAllowlistedTargetsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, removes, new WorkflowRouter.TargetSelectors[](0)
    );

    assertEq(s_workflowRouter.getAllowlistedTargets(AUCTION_WORKER_WORKFLOW_ID).length, 0);
    assertEq(s_workflowRouter.getAllowlistedSelectors(AUCTION_WORKER_WORKFLOW_ID, address(s_auction)).length, 0);
  }

  function test_applyAllowlistedTargetsUpdates_Adds() external {
    s_workflowRouter.applyAllowlistedTargetsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, new address[](0), s_allowlistedWorkflows[2].targetSelectors
    );

    address[] memory allowlistedTargets = s_workflowRouter.getAllowlistedTargets(AUCTION_WORKER_WORKFLOW_ID);

    assertEq(allowlistedTargets.length, 2);
    assertEq(allowlistedTargets[0], address(s_auction));
    assertEq(allowlistedTargets[1], address(s_auctionBidder));
  }

  function test_applyAllowlistedTargetsUpdates_MixedScenario() external {
    WorkflowRouter.TargetSelectors[] memory adds = new WorkflowRouter.TargetSelectors[](1);
    adds[0].target = address(s_feeAggregator);
    adds[0].selectors = new bytes4[](1);
    adds[0].selectors[0] = s_feeAggregator.transferForSwap.selector;

    address[] memory removes = new address[](1);
    removes[0] = address(s_auction);

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), s_auction.performUpkeep.selector
    );
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), s_auction.invalidateOrders.selector
    );
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.TargetRemovedFromAllowlist(AUCTION_WORKER_WORKFLOW_ID, address(s_auction));
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorAllowlisted(
      AUCTION_WORKER_WORKFLOW_ID, address(s_feeAggregator), s_feeAggregator.transferForSwap.selector
    );

    s_workflowRouter.applyAllowlistedTargetsUpdates(AUCTION_WORKER_WORKFLOW_ID, removes, adds);
  }
}
