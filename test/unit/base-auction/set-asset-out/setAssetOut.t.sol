// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract BaseAuctionAuction_SetAssetOutUnitTest is BaseUnitTest {
  BaseAuction private s_baseAuction;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    _changePrank(i_assetAdmin);
  }

  function test_setAssetOut_RevertWhen_CallerDoesNotHaveASSET_ADMIN_ROLE()
    external
    whenCallerIsNotAssetManager
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.ASSET_ADMIN_ROLE)
    );

    s_baseAuction.setAssetOut(i_asset1);
  }

  function test_setAssetOut_RevertWhen_LiveAuction() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    // Start auction for asset1
    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0].asset = i_asset1;
    assetAmounts[0].amount = 1 ether;

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));
    vm.mockCall(address(i_asset1), IERC20.balanceOf.selector, abi.encode(1 ether));
    vm.mockCall(address(i_asset1), IERC20.allowance.selector, abi.encode(0));
    s_baseAuction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    _changePrank(i_assetAdmin);
    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_baseAuction.setAssetOut(i_asset1);
  }

  function test_setAssetOut_RevertWhen_AssetOutEqAddressZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroAddress.selector);

    s_baseAuction.setAssetOut(address(0));
  }

  function test_setAssetOut_RevertWhen_AssetOutEqCurrentValue()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    address currentAssetOut = s_baseAuction.getAssetOut();

    vm.expectRevert(Errors.ValueNotUpdated.selector);
    s_baseAuction.setAssetOut(currentAssetOut);
  }

  function test_setAssetOut() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(8));

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetOutSet(i_asset1);

    s_baseAuction.setAssetOut(i_asset1);

    assertEq(s_baseAuction.getAssetOut(), i_asset1);
    assertEq(s_baseAuction.getAssetParams(i_mockLink).decimals, 0);
  }
}
