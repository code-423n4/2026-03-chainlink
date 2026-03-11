// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {GPV2CompatibleAuction} from "src/GPV2CompatibleAuction.sol";

import {Errors} from "src/libraries/Errors.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

contract GPV2CompatibleAuction_ConstructorUnitTest is BaseUnitTest {
  BaseAuction.ConstructorParams private s_params;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_params.admin = i_owner;
    s_params.adminRoleTransferDelay = DEFAULT_ADMIN_TRANSFER_DELAY;
    s_params.verifierProxy = i_mockStreamsVerifierProxy;
    s_params.minPriceMultiplier = MIN_PRICE_MULTIPLIER;
    s_params.minBidUsdValue = MIN_BID_USD_VALUE;
    s_params.linkToken = i_mockLink;
    s_params.assetOut = i_mockLink;
    s_params.assetOutReceiver = i_receiver;
    s_params.feeAggregator = address(s_feeAggregator);
  }

  function test_constructor_RevertWhen_VaultRelayerEqAddressZero() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));

    new GPV2CompatibleAuction(s_params, address(0), i_mockGPV2Settlement);
  }

  function test_constructor_RevertWhen_SettlementEqAddressZero() external {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidZeroAddress.selector));

    new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, address(0));
  }

  function test_constructor_Success() external {
    vm.expectEmit();
    emit GPV2CompatibleAuction.GPV2VaultRelayerSet(i_mockGPV2VaultRelayer);
    vm.expectEmit();
    emit GPV2CompatibleAuction.GPV2SettlementSet(i_mockGPV2Settlement);
    GPV2CompatibleAuction auction = new GPV2CompatibleAuction(s_params, i_mockGPV2VaultRelayer, i_mockGPV2Settlement);

    assertEq(auction.getGPV2VaultRelayer(), i_mockGPV2VaultRelayer);
    assertEq(address(auction.getGPV2Settlement()), i_mockGPV2Settlement);
  }
}
