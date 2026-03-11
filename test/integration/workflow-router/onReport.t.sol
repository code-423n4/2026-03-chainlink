// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {WorkflowRouter} from "src/WorkflowRouter.sol";

import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract WorkflowRouter_OnReportIntegrationTest is BaseIntegrationTest, PriceManagerHelper {
  PriceManagerHelper.AssetPrice[] private s_assetPrices;

  function setUp() external {
    _changePrank(i_assetAdmin);

    // Set asset prices
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockWETH), price: 4_000e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockUSDC), price: 1e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockLINK), price: 20e18}));

    _transmitAssetPrices(s_auction, s_assetPrices);

    deal(address(s_mockWETH), address(s_feeAggregator), 100 ether);

    _changePrank(i_forwarder);
  }

  function test_onReport_RevertWhen_ContractIsPaused() external givenContractIsPaused(address(s_workflowRouter)) {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_workflowRouter.onReport(abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)), bytes(""));
  }

  function test_onReport_RevertWhen_CallerDoesNotHaveFORWARDER_ROLE() external whenCallerIsNotForwarder {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.FORWARDER_ROLE)
    );
    s_workflowRouter.onReport(abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)), bytes(""));
  }

  function test_onReport_RevertWhen_ZeroWorkflowId() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroValue.selector));
    s_workflowRouter.onReport(abi.encodePacked(bytes32(0), bytes10(0), bytes20(0)), bytes(""));
  }

  function test_onReport_RevertWhen_UnauthorizedWorkflow() external {
    bytes32 unauthorizedWorkflowId = bytes32("unauthorized_workflow_id");

    vm.expectRevert(abi.encodeWithSelector(WorkflowRouter.UnauthorizedWorkflow.selector, unauthorizedWorkflowId));
    s_workflowRouter.onReport(abi.encodePacked(unauthorizedWorkflowId, bytes10(0), bytes20(0)), bytes(""));
  }

  function test_onReport() external {
    (bool upkeepNeeded, bytes memory performData) = s_auction.checkUpkeep("");
    assertTrue(upkeepNeeded);

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionStarted(address(s_mockWETH));

    s_workflowRouter.onReport(abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)), performData);

    assertEq(s_auction.getAuctionStart(address(s_mockWETH)), block.timestamp);
  }
}
