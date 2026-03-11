// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PriceManager} from "src/PriceManager.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IVerifierProxy} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract PriceManager_TransmitUnitTest is BaseUnitTest {
  uint256 private constant ASSET_1_PRICE = 1e18;
  uint256 private constant ASSET_2_PRICE = 1e8;
  uint256 private constant ASSET_3_PRICE = 1e24;

  address private immutable i_mockFeeManager = makeAddr("mockFeeManager");

  PriceManager.ReportV3 private s_asset1Report;
  PriceManager.ReportV3 private s_asset2Report;
  PriceManager.ReportV3 private s_asset3Report;

  bytes[] private s_unverifiedReports;

  modifier whenCallerIsNotPriceAdmin() {
    _changePrank(i_owner);
    _;
  }

  function setUp() public {
    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    s_asset1Report.dataStreamsFeedId = i_asset1dataStreamsFeedId;
    s_asset1Report.price = int192(uint192(ASSET_1_PRICE));
    s_asset1Report.observationsTimestamp = uint32(block.timestamp);

    s_asset2Report.dataStreamsFeedId = i_asset2dataStreamsFeedId;
    s_asset2Report.price = int192(uint192(ASSET_2_PRICE));
    s_asset2Report.observationsTimestamp = uint32(block.timestamp);

    s_asset3Report.dataStreamsFeedId = i_asset3dataStreamsFeedId;
    s_asset3Report.price = int192(uint192(ASSET_3_PRICE));
    s_asset3Report.observationsTimestamp = uint32(block.timestamp);

    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset1Report), rs, ss, rawVs));
    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset2Report), rs, ss, rawVs));
    s_unverifiedReports.push(abi.encode(context, abi.encode(s_asset3Report), rs, ss, rawVs));

    bytes[] memory verifiedReports = new bytes[](3);
    verifiedReports[0] = abi.encode(s_asset1Report);
    verifiedReports[1] = abi.encode(s_asset2Report);
    verifiedReports[2] = abi.encode(s_asset3Report);

    vm.mockCall(
      i_mockStreamsVerifierProxy,
      abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, s_unverifiedReports, abi.encode(i_mockLink)),
      abi.encode(verifiedReports)
    );

    _changePrank(i_priceAdmin);
  }

  function test_transmit_RevertWhen_CallerDoesNotHavePRICE_ADMIN_ROLE()
    external
    whenCallerIsNotPriceAdmin
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.PRICE_ADMIN_ROLE)
    );
    PriceManager(s_contractUnderTest).transmit(s_unverifiedReports);
  }

  function test_transmit_RevertWhen_EmptyReportList() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    vm.expectRevert(Errors.EmptyList.selector);

    PriceManager(s_contractUnderTest).transmit(new bytes[](0));
  }

  function test_transmit_RevertWhen_FeedIsNotAllowlisted()
    external
    performForAllContracts(CommonContracts.PRICE_MANAGER)
  {
    PriceManager.ReportV3 memory invalidReportData = s_asset1Report;
    invalidReportData.dataStreamsFeedId =
      bytes32(bytes.concat(bytes2(0x0003), bytes30(keccak256("invaliddataStreamsFeedId"))));
    invalidReportData.price = int192(uint192(ASSET_1_PRICE));
    invalidReportData.observationsTimestamp = uint32(block.timestamp);

    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    bytes[] memory invalidUnverifiedReports = new bytes[](1);
    invalidUnverifiedReports[0] = abi.encode(context, abi.encode(invalidReportData), rs, ss, rawVs);

    vm.expectRevert(
      abi.encodeWithSelector(PriceManager.FeedNotAllowlisted.selector, invalidReportData.dataStreamsFeedId)
    );
    PriceManager(s_contractUnderTest).transmit(invalidUnverifiedReports);
  }

  function test_transmit_RevertWhen_PriceEqZero() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    s_asset1Report.price = int192(0);

    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    bytes[] memory invalidUnverifiedReports = new bytes[](1);
    invalidUnverifiedReports[0] = abi.encode(context, abi.encode(s_asset1Report), rs, ss, rawVs);

    bytes[] memory verifiedReports = new bytes[](1);
    verifiedReports[0] = abi.encode(s_asset1Report);

    vm.mockCall(
      i_mockStreamsVerifierProxy,
      abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, invalidUnverifiedReports, abi.encode(i_mockLink)),
      abi.encode(verifiedReports)
    );

    vm.expectRevert(Errors.ZeroFeedData.selector);
    PriceManager(s_contractUnderTest).transmit(invalidUnverifiedReports);
  }

  function test_transmit_RevertWhen_StalePrice() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    s_asset1Report.observationsTimestamp = uint32(block.timestamp - 2 days);

    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    bytes[] memory invalidUnverifiedReports = new bytes[](1);
    invalidUnverifiedReports[0] = abi.encode(context, abi.encode(s_asset1Report), rs, ss, rawVs);

    bytes[] memory verifiedReports = new bytes[](1);
    verifiedReports[0] = abi.encode(s_asset1Report);

    vm.mockCall(
      i_mockStreamsVerifierProxy,
      abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, invalidUnverifiedReports, abi.encode(i_mockLink)),
      abi.encode(verifiedReports)
    );

    vm.expectRevert(Errors.StaleFeedData.selector);
    PriceManager(s_contractUnderTest).transmit(invalidUnverifiedReports);
  }

  function test_transmit() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.PriceTransmitted(i_asset1, 1e18);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.PriceTransmitted(i_asset2, 1e18);
    vm.expectEmit(address(PriceManager(s_contractUnderTest)));
    emit PriceManager.PriceTransmitted(i_asset3, 1e18);

    PriceManager(s_contractUnderTest).transmit(s_unverifiedReports);

    (uint256 asset1Price, uint256 asset1UpdatedAt, bool isAsset1PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset1);
    (uint256 asset2Price, uint256 asset2UpdatedAt, bool isAsset2PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset2);
    (uint256 asset3Price, uint256 asset3UpdatedAt, bool isAsset3PriceValid) =
      PriceManager(s_contractUnderTest).getAssetPrice(i_asset3);

    assertEq(asset1Price, 1e18);
    assertEq(asset1UpdatedAt, block.timestamp);
    assertTrue(isAsset1PriceValid);
    assertEq(asset2Price, 1e18);
    assertEq(asset2UpdatedAt, block.timestamp);
    assertTrue(isAsset2PriceValid);
    assertEq(asset3Price, 1e18);
    assertEq(asset3UpdatedAt, block.timestamp);
    assertTrue(isAsset3PriceValid);
  }
}
