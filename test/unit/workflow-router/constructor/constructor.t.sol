// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IReceiver} from "@chainlink/contracts/src/v0.8/keystone/interfaces/IReceiver.sol";

import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

contract WorkflowRouter_ConstructorUnitTest is BaseUnitTest {
  function test_constructor() external view {
    assertTrue(s_workflowRouter.supportsInterface(type(IReceiver).interfaceId));
    assertEq(s_workflowRouter.typeAndVersion(), "WorkflowRouter 1.0.0-dev");
  }
}
