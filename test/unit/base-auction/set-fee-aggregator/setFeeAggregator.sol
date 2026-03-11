// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract BaseAuction_SetFeeAggregatorUnitTest is BaseUnitTest {
  address private immutable i_newFeeAggregatorReceiver = makeAddr("newFeeAggregatorReceiver");

  BaseAuction private s_baseAuction;

  function setUp() public performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    vm.mockCall(
      i_newFeeAggregatorReceiver,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IFeeAggregator).interfaceId),
      abi.encode(true)
    );
  }

  function test_setFeeAggregator_RevertWhen_CallerDoesNotHaveDEFAULT_ADMIN_ROLE()
    public
    whenCallerIsNotAdmin
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_nonOwner, DEFAULT_ADMIN_ROLE)
    );
    s_baseAuction.setFeeAggregator(i_newFeeAggregatorReceiver);
  }

  function test_setFeeAggregator_RevertWhen_LiveAuction() public performForAllContracts(CommonContracts.BASE_AUCTION) {
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
    s_baseAuction.setFeeAggregator(i_newFeeAggregatorReceiver);
  }

  function test_setFeeAggregator_RevertWhen_FeeAggregatorReceiverAddressZero()
    public
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroAddress.selector);
    s_baseAuction.setFeeAggregator(address(0));
  }

  function test_setFeeAggregator_RevertWhen_FeeAggregatorReceiverAddressNotUpdated()
    public
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.ValueNotUpdated.selector);
    s_baseAuction.setFeeAggregator(address(s_feeAggregator));
  }

  function test_setFeeAggregator_RevertWhen_FeeAggregatorDoesNotSupportIFeeAggregatorInterface()
    public
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.mockCall(
      i_newFeeAggregatorReceiver,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IFeeAggregator).interfaceId),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidFeeAggregator.selector, i_newFeeAggregatorReceiver));
    s_baseAuction.setFeeAggregator(i_newFeeAggregatorReceiver);
  }

  function test_setFeeAggregator_UpdatesFeeAggregatorReceiver()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.FeeAggregatorSet(i_newFeeAggregatorReceiver);

    s_baseAuction.setFeeAggregator(i_newFeeAggregatorReceiver);
    assertEq(address(s_baseAuction.getFeeAggregator()), i_newFeeAggregatorReceiver);
  }
}
