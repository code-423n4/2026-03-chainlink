// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract BaseAuction_SetAssetOutReceiverUnitTest is BaseUnitTest {
  BaseAuction private s_baseAuction;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);
  }

  function test_setAssetOutReceiver_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE()
    external
    whenCallerIsNotAdmin
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );

    s_baseAuction.setAssetOutReceiver(i_receiver);
  }

  function test_setAssetOutReceiver_RevertWhen_LiveAuction()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Start auction for asset1
    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0].asset = i_asset1;
    assetAmounts[0].amount = 1 ether;

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));
    vm.mockCall(address(i_asset1), IERC20.balanceOf.selector, abi.encode(1 ether));
    vm.mockCall(address(i_asset1), IERC20.allowance.selector, abi.encode(0));
    s_baseAuction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    _changePrank(i_owner);

    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_baseAuction.setAssetOutReceiver(makeAddr("newReceiver"));
  }

  function test_setAssetOutReceiver_RevertWhen_AssetOutReceiverEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    s_baseAuction.setAssetOutReceiver(address(0));
  }

  function test_setAssetOutReceiver_RevertWhen_AssetOutReceiverEqCurrentValue()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    address currentAssetOutReceiver = s_baseAuction.getAssetOutReceiver();

    vm.expectRevert(Errors.ValueNotUpdated.selector);
    s_baseAuction.setAssetOutReceiver(currentAssetOutReceiver);
  }

  function test_setAssetOutReceiver() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    address newReceiver = makeAddr("newReceiver");

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetOutReceiverSet(newReceiver);

    s_baseAuction.setAssetOutReceiver(newReceiver);

    assertEq(s_baseAuction.getAssetOutReceiver(), newReceiver);
  }
}
