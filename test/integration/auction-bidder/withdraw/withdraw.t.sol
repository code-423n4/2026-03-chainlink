// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AuctionBidder_WithdrawIntegrationTest is BaseIntegrationTest {
  Common.AssetAmount[] private s_assetsToWithdraw;

  function setUp() external {
    deal(address(s_mockLINK), address(s_auctionBidder), 1e18);

    s_assetsToWithdraw.push(Common.AssetAmount({asset: address(s_mockLINK), amount: 1e18}));
  }

  function test_withdraw_RevertWhen_CallerDoesNotDEFAULT_ADMIN_ROLE() external whenCallerIsNotAdmin {
    Common.AssetAmount[] memory assetsToWithdraw = new Common.AssetAmount[](1);
    assetsToWithdraw[0] = Common.AssetAmount({asset: address(s_mockLINK), amount: 1e18});

    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_auctionBidder.withdraw(assetsToWithdraw, i_receiver);
  }

  function test_withdraw_RevertWhen_ToEqAddressZero() external {
    Common.AssetAmount[] memory assetsToWithdraw = new Common.AssetAmount[](1);
    assetsToWithdraw[0] = Common.AssetAmount({asset: address(s_mockLINK), amount: 1e18});

    vm.expectRevert(Errors.InvalidZeroAddress.selector);
    s_auctionBidder.withdraw(assetsToWithdraw, address(0));
  }

  function test_withdraw() external {
    s_auctionBidder.withdraw(s_assetsToWithdraw, i_receiver);

    assertEq(s_mockLINK.balanceOf(i_receiver), s_assetsToWithdraw[0].amount);
    assertEq(s_mockLINK.balanceOf(address(s_auctionBidder)), 0);
  }
}
