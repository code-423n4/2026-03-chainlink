// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {WorkflowRouter} from "src/WorkflowRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract WorkflowRouter_OnReportIntegrationTest is BaseUnitTest, PriceManagerHelper {
  function setUp() external {
    WorkflowRouter.AllowlistedWorkflow[] memory adds = new WorkflowRouter.AllowlistedWorkflow[](3);
    adds[0].workflowId = PRICE_ADMIN_WORKFLOW_ID;
    adds[0].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[0].targetSelectors[0].target = address(s_auction);
    adds[0].targetSelectors[0].selectors = new bytes4[](1);
    adds[0].targetSelectors[0].selectors[0] = s_auction.transmit.selector;

    adds[1].workflowId = AUCTION_WORKER_WORKFLOW_ID;
    adds[1].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[1].targetSelectors[0].target = address(s_auction);
    adds[1].targetSelectors[0].selectors = new bytes4[](2);
    adds[1].targetSelectors[0].selectors[0] = s_auction.performUpkeep.selector;
    adds[1].targetSelectors[0].selectors[1] = s_auction.invalidateOrders.selector;

    adds[2].workflowId = AUCTION_BIDDER_WORKFLOW_ID;
    adds[2].targetSelectors = new WorkflowRouter.TargetSelectors[](1);
    adds[2].targetSelectors[0].target = address(s_auctionBidder);
    adds[2].targetSelectors[0].selectors = new bytes4[](1);
    adds[2].targetSelectors[0].selectors[0] = s_auctionBidder.bid.selector;

    s_workflowRouter.applyAllowlistedWorkflowsUpdates(new bytes32[](0), adds);

    _changePrank(i_forwarder);
  }

  function test_onReport_RevertWhen_ContractIsPaused() external givenContractIsPaused(address(s_workflowRouter)) {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_workflowRouter.onReport(abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)), "");
  }

  function test_onReport_RevertWhen_CallerDoesNotHaveFORWARDER_ROLE() external whenCallerIsNotForwarder {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.FORWARDER_ROLE)
    );
    s_workflowRouter.onReport(abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)), "");
  }

  function test_onReport_RevertWhen_ZeroWorkflowId() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroValue.selector));
    s_workflowRouter.onReport(abi.encodePacked(bytes32(0), bytes10(0), bytes20(0)), "");
  }

  function test_onReport_RevertWhen_UnauthorizedWorkflow() external {
    bytes32 invalidWorkflowId = bytes32("invalidWorkflowId");

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.WorkflowIdNotAllowlisted.selector, invalidWorkflowId));
    s_workflowRouter.onReport(abi.encodePacked(invalidWorkflowId, bytes10(0), bytes20(0)), "");
  }

  function test_onReport_RevertWhen_InvalidTarget() external {
    vm.expectRevert(
      abi.encodeWithSelector(
        WorkflowRouter.TargetNotAllowlisted.selector, AUCTION_WORKER_WORKFLOW_ID, address(s_auctionBidder)
      )
    );
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auctionBidder), abi.encodeWithSelector(s_auction.performUpkeep.selector, ""))
    );
  }

  function test_onReport_RevertWhen_UnauthorizedFunctionSelector() external {
    vm.expectRevert(
      abi.encodeWithSelector(
        WorkflowRouter.SelectorNotAllowlisted.selector,
        AUCTION_WORKER_WORKFLOW_ID,
        address(s_auction),
        s_auction.transmit.selector
      )
    );
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.transmit.selector, ""))
    );
  }
}
