// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract BaseAuction_SetMinBidUsdValueUnitTest is BaseUnitTest {
  BaseAuction private s_baseAuction;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    _changePrank(i_assetAdmin);
  }

  function test_setMinBidUsdValue_RevertWhen_CallerDoesNotHaveASSET_ADMIN_ROLE()
    external
    whenCallerIsNotAssetManager
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.ASSET_ADMIN_ROLE)
    );
    s_baseAuction.setMinBidUsdValue(MIN_BID_USD_VALUE + 1);
  }

  function test_setMinBidUsdValue_RevertWhen_MinBidUsdValueEqZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.InvalidZeroValue.selector);
    s_baseAuction.setMinBidUsdValue(0);
  }

  function test_setMinBidUsdValue_RevertWhen_MinBidUsdValueEqCurrentValue()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.ValueNotUpdated.selector);
    s_baseAuction.setMinBidUsdValue(MIN_BID_USD_VALUE);
  }

  function test_setMinBidUsdValue_UpdatesMinBidUsdValue()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    uint88 newMinBidUsdValue = MIN_BID_USD_VALUE + 1;

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.MinBidUsdValueSet(newMinBidUsdValue);

    s_baseAuction.setMinBidUsdValue(newMinBidUsdValue);

    vm.expectRevert(Errors.ValueNotUpdated.selector);
    s_baseAuction.setMinBidUsdValue(newMinBidUsdValue);
  }
}
