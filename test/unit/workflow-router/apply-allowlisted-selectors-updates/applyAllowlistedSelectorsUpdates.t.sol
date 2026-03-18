// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract WorkflowRouter_ApplyAllowlistedSelectorsUpdatesUnitTest is BaseUnitTest {
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

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE()
    external
    whenCallerIsNotAdmin
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), new bytes4[](0), new bytes4[](0)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_EmptyList() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.EmptyList.selector));
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), new bytes4[](0), new bytes4[](0)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_RemovedSelectorWorkflowIdIsNotAllowlisted() external {
    bytes32 nonAllowlistedWorkflowId = keccak256("nonAllowlistedWorkflowId");
    bytes4[] memory removes = new bytes4[](1);
    removes[0] = s_auction.performUpkeep.selector;

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.WorkflowIdNotAllowlisted.selector, nonAllowlistedWorkflowId));
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      nonAllowlistedWorkflowId, address(s_auction), removes, new bytes4[](1)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_RemovedSelectorTargetNotAllowlisted() external {
    address nonAllowlistedTarget = address(s_feeAggregator);
    bytes4[] memory removes = new bytes4[](1);
    removes[0] = s_auction.performUpkeep.selector;

    vm.expectRevert(
      abi.encodeWithSelector(
        WorkflowRouter.TargetNotAllowlisted.selector, AUCTION_WORKER_WORKFLOW_ID, nonAllowlistedTarget
      )
    );
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, nonAllowlistedTarget, removes, new bytes4[](1)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_SelectorNotAllowlisted() external {
    bytes4[] memory removes = new bytes4[](1);
    removes[0] = s_auction.performUpkeep.selector;

    vm.expectRevert(
      abi.encodeWithSelector(
        WorkflowRouter.SelectorNotAllowlisted.selector, PRICE_ADMIN_WORKFLOW_ID, address(s_auction), removes[0]
      )
    );
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      PRICE_ADMIN_WORKFLOW_ID, address(s_auction), removes, new bytes4[](0)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_RevertWhen_SelectorEqZero() external {
    vm.expectRevert(Errors.InvalidZeroValue.selector);
    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), new bytes4[](0), new bytes4[](1)
    );
  }

  function test_applyAllowlistedSelectorsUpdates_Removes() external {
    bytes4[] memory removes = new bytes4[](1);
    removes[0] = s_auction.performUpkeep.selector;

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(AUCTION_WORKER_WORKFLOW_ID, address(s_auction), removes[0]);

    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), removes, new bytes4[](0)
    );

    bytes4[] memory allowlistedSelectors =
      s_workflowRouter.getAllowlistedSelectors(AUCTION_WORKER_WORKFLOW_ID, address(s_auction));

    assertEq(allowlistedSelectors.length, 1);
    assertEq(allowlistedSelectors[0], bytes32(s_auction.invalidateOrders.selector));
  }

  function test_applyAllowlistedSelectorsUpdates_Adds() external {
    bytes4[] memory adds = new bytes4[](1);
    adds[0] = s_auction.transmit.selector;

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorAllowlisted(AUCTION_WORKER_WORKFLOW_ID, address(s_auction), adds[0]);

    s_workflowRouter.applyAllowlistedSelectorsUpdates(
      AUCTION_WORKER_WORKFLOW_ID, address(s_auction), new bytes4[](0), adds
    );

    bytes4[] memory allowlistedSelectors =
      s_workflowRouter.getAllowlistedSelectors(AUCTION_WORKER_WORKFLOW_ID, address(s_auction));

    assertEq(allowlistedSelectors.length, 3);
    assertEq(allowlistedSelectors[0], bytes32(s_auction.performUpkeep.selector));
    assertEq(allowlistedSelectors[1], bytes32(s_auction.invalidateOrders.selector));
    assertEq(allowlistedSelectors[2], bytes32(s_auction.transmit.selector));
  }

  function test_applyAllowlistedSelectorsUpdates_MixedScenario() external {
    bytes4[] memory removes = new bytes4[](1);
    removes[0] = s_auction.performUpkeep.selector;

    bytes4[] memory adds = new bytes4[](1);
    adds[0] = s_auction.transmit.selector;

    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorRemovedFromAllowlist(AUCTION_WORKER_WORKFLOW_ID, address(s_auction), removes[0]);
    vm.expectEmit(address(s_workflowRouter));
    emit WorkflowRouter.SelectorAllowlisted(AUCTION_WORKER_WORKFLOW_ID, address(s_auction), adds[0]);

    s_workflowRouter.applyAllowlistedSelectorsUpdates(AUCTION_WORKER_WORKFLOW_ID, address(s_auction), removes, adds);

    bytes4[] memory allowlistedSelectors =
      s_workflowRouter.getAllowlistedSelectors(AUCTION_WORKER_WORKFLOW_ID, address(s_auction));

    assertEq(allowlistedSelectors.length, 2);
    assertEq(allowlistedSelectors[0], bytes32(s_auction.invalidateOrders.selector));
    assertEq(allowlistedSelectors[1], bytes32(s_auction.transmit.selector));
  }
}
