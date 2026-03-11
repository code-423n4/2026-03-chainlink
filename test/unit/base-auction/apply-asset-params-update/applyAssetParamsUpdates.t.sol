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

contract BaseAuction_ApplyAssetParamsUpdatesUnitTest is BaseUnitTest {
  BaseAuction private s_baseAuction;

  BaseAuction.ApplyAssetParamsUpdate[] private s_assetParamsUpdates;
  BaseAuction.AssetParams private s_emptyAssetParams;

  modifier givenAuctionIsLive(
    address asset
  ) {
    // Start auction for asset1
    Common.AssetAmount[] memory assetAmounts = new Common.AssetAmount[](1);
    assetAmounts[0].asset = asset;
    assetAmounts[0].amount = 1 ether;

    _changePrank(i_auctionAdmin);

    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));
    vm.mockCall(address(asset), IERC20.balanceOf.selector, abi.encode(1 ether));
    vm.mockCall(address(asset), IERC20.allowance.selector, abi.encode(0));
    s_baseAuction.performUpkeep(abi.encode(assetAmounts, new address[](0)));

    _changePrank(i_assetAdmin);
    _;
  }

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    s_assetParamsUpdates.push(
      BaseAuction.ApplyAssetParamsUpdate({asset: i_asset1, params: s_baseAuction.getAssetParams(i_asset1)})
    );
    s_assetParamsUpdates.push(
      BaseAuction.ApplyAssetParamsUpdate({asset: i_asset2, params: s_baseAuction.getAssetParams(i_asset2)})
    );

    _changePrank(i_assetAdmin);
  }

  function test_applyAssetParamsUpdates_RevertWhen_CallerDoesNotHaveTheASSET_ADMIN_ROLE()
    external
    whenCallerIsNotAssetManager
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, i_owner, Roles.ASSET_ADMIN_ROLE)
    );

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_EmpytLists()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.expectRevert(Errors.EmptyList.selector);

    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_RemovedAssetHasLiveAuction()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Try to remove asset1 while auction is live
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = i_asset1;

    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, removedAssets);
  }

  function test_applyAssetParamsUpdates_RevertWhen_RemovedAssetIsAssetOutAndLiveAuctionExists()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Try to remove asset1 while it's the asset out of a live auction
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = i_mockLink;

    vm.expectRevert(BaseAuction.LiveAuction.selector);
    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, removedAssets);
  }

  function test_applyAssetParamsUpdates_RevertWhen_RemovedAssetParamsNotSet()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = i_asset1;

    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);

    vm.expectRevert(abi.encodeWithSelector(BaseAuction.AssetParamsNotSet.selector, i_asset1));

    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);
  }

  function test_applyAssetParamsUpdates_RevertWhen_AssetIsNotAllowlisted()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_assetParamsUpdates[0].asset = makeAddr("non-allowlisted asset");

    vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotAllowlisted.selector, s_assetParamsUpdates[0].asset));

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_LiveAuction()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Try to update asset1 params while auction is live
    vm.expectRevert(BaseAuction.LiveAuction.selector);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_UpdatedAssetIsAssetOutAndLiveAuctionExists()
    external
    givenAuctionIsLive(i_asset1)
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Try to update asset1 params while it's the asset out of a live auction
    s_assetParamsUpdates[0].asset = i_mockLink;

    vm.expectRevert(BaseAuction.LiveAuction.selector);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_InvalidDecimals()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));

    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAssetDecimals.selector, i_asset1, 18, 6));

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_AuctionDurationEqZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_assetParamsUpdates[0].params.auctionDuration = 0;

    vm.expectRevert(Errors.InvalidZeroValue.selector);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_MinAuctionSizeUsdEqZero()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_assetParamsUpdates[0].params.minAuctionSizeUsd = 0;

    vm.expectRevert(Errors.InvalidZeroValue.selector);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_EndingPriceMultiplierLtMaxDiscount()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_assetParamsUpdates[0].params.endingPriceMultiplier = 0.97e18;

    vm.expectRevert(
      abi.encodeWithSelector(BaseAuction.InvalidEndingPriceMultiplier.selector, i_asset1, 0.97e18, MIN_PRICE_MULTIPLIER)
    );

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_RevertWhen_StartingPriceMultiplierLtEndingPriceMultiplier()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    s_assetParamsUpdates[0].params.startingPriceMultiplier = 0.98e18;
    s_assetParamsUpdates[0].params.endingPriceMultiplier = 1.1e18;

    vm.expectRevert(
      abi.encodeWithSelector(
        BaseAuction.StartingPriceMultiplierLowerThanEndingPriceMultiplier.selector, i_asset1, 0.98e18, 1.1e18
      )
    );

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));
  }

  function test_applyAssetParamsUpdates_Adds() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(s_assetParamsUpdates[0].asset, s_assetParamsUpdates[0].params);
    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(s_assetParamsUpdates[1].asset, s_assetParamsUpdates[1].params);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));

    BaseAuction.AssetParams memory asset1Params = s_baseAuction.getAssetParams(i_asset1);
    BaseAuction.AssetParams memory asset2Params = s_baseAuction.getAssetParams(i_asset2);

    _assertAssetParamsEq(s_assetParamsUpdates[0].params, asset1Params);
    _assertAssetParamsEq(s_assetParamsUpdates[1].params, asset2Params);
  }

  function test_applyAssetParamsUpdates_Updates() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));

    s_assetParamsUpdates[0].params.minAuctionSizeUsd = uint96(MIN_SWAP_SIZE * 2);

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(s_assetParamsUpdates[0].asset, s_assetParamsUpdates[0].params);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));

    BaseAuction.AssetParams memory asset1Params = s_baseAuction.getAssetParams(i_asset1);

    _assertAssetParamsEq(s_assetParamsUpdates[0].params, asset1Params);
  }

  function test_applyAssetParamsUpdates_UpdateAssetOut() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_assetParamsUpdates.pop();
    s_assetParamsUpdates[0].asset = i_mockLink;
    s_assetParamsUpdates[0].params.minAuctionSizeUsd = 100e18;

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(i_mockLink, s_assetParamsUpdates[0].params);
    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));

    BaseAuction.AssetParams memory assetOutParams = s_baseAuction.getAssetParams(i_mockLink);
    _assertAssetParamsEq(s_assetParamsUpdates[0].params, assetOutParams);
  }

  function test_applyAssetParamsUpdates_Removes() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, new address[](0));

    address[] memory removedAssets = new address[](1);
    removedAssets[0] = i_asset1;

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsRemoved(i_asset1);

    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);

    _assertAssetParamsEq(s_baseAuction.getAssetParams(i_asset1), s_emptyAssetParams);
  }

  function test_applyAssetParamsUpdates_AddsAndRemoves() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    // Add asset1
    BaseAuction.ApplyAssetParamsUpdate[] memory newAssetParamsUpdates = new BaseAuction.ApplyAssetParamsUpdate[](1);
    newAssetParamsUpdates[0] = s_assetParamsUpdates[0];

    s_baseAuction.applyAssetParamsUpdates(newAssetParamsUpdates, new address[](0));

    // Remove asset1 and add asset1 & asset2
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = i_asset1;

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsRemoved(i_asset1);
    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(i_asset1, s_assetParamsUpdates[0].params);
    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AssetParamsUpdated(i_asset2, s_assetParamsUpdates[1].params);

    s_baseAuction.applyAssetParamsUpdates(s_assetParamsUpdates, removedAssets);

    BaseAuction.AssetParams memory asset1Params = s_baseAuction.getAssetParams(i_asset1);
    BaseAuction.AssetParams memory asset2Params = s_baseAuction.getAssetParams(i_asset2);

    _assertAssetParamsEq(s_assetParamsUpdates[0].params, asset1Params);
    _assertAssetParamsEq(s_assetParamsUpdates[1].params, asset2Params);
  }

  function _assertAssetParamsEq(
    BaseAuction.AssetParams memory a,
    BaseAuction.AssetParams memory b
  ) internal pure {
    assertEq(a.decimals, b.decimals);
    assertEq(a.auctionDuration, b.auctionDuration);
    assertEq(a.endingPriceMultiplier, b.endingPriceMultiplier);
    assertEq(a.minAuctionSizeUsd, b.minAuctionSizeUsd);
  }
}
