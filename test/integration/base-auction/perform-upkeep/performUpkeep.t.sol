// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseAuction} from "src/BaseAuction.sol";
import {Caller} from "src/Caller.sol";
import {Common} from "src/libraries/Common.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseIntegrationTest} from "test/integration/BaseIntegrationTest.t.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Vm} from "forge-std/Vm.sol";

contract BaseAuction_PerformUpkeepIntegrationTest is BaseIntegrationTest, PriceManagerHelper {
  uint256 private constant USDC_AUCTIONED_AMOUNT = 100_000e6; // $100,000 worth of USDC
  PriceManagerHelper.AssetPrice[] private s_assetPrices;

  BaseAuction private s_baseAuction;
  bytes private s_performData;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    // Set asset prices
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockWETH), price: 4_000e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockUSDC), price: 1e18}));
    s_assetPrices.push(PriceManagerHelper.AssetPrice({asset: address(s_mockLINK), price: 20e18}));

    _changePrank(i_priceAdmin);
    _transmitAssetPrices(s_baseAuction, s_assetPrices);

    // Prepare auction
    deal(address(s_mockUSDC), address(s_feeAggregator), USDC_AUCTIONED_AMOUNT); // $100,000 worth of USDC

    _changePrank(i_auctionAdmin);
    (, s_performData) = s_baseAuction.checkUpkeep("");
    s_baseAuction.performUpkeep(s_performData);

    deal(address(s_mockLINK), address(s_auctionBidder), 5_250e18); // $105,000 worth of LINK
  }

  function test_performUpkeep_RevertWhen_ContractIsPaused()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
    givenContractIsPaused(address(s_baseAuction))
  {
    vm.expectRevert(Pausable.EnforcedPause.selector);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), new address[](0)));
  }

  function test_performUpkeep_RevertWhen_NoAssetOutParams()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // End running aution to remove asset out params
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    // Remove asset out params.
    _changePrank(i_assetAdmin);
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = s_baseAuction.getAssetOut();
    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);

    vm.expectRevert(BaseAuction.MissingAssetOutParams.selector);
    s_baseAuction.checkUpkeep("");
  }

  function test_performUpkeep_RevertWhen_EligibleAssetsAndInvalidAssetOutPrice()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Force end the running auction to reconfigure
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    _changePrank(i_auctionAdmin);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    // Attempt new auction for USDC with stale asset out price
    deal(address(s_mockUSDC), address(s_baseAuction), USDC_AUCTIONED_AMOUNT); // $100,000 worth of USDC
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");
    assertTrue(upkeepNeeded);
    skip(s_baseAuction.getFeedInfo(address(s_mockLINK)).stalenessThreshold + 1);

    vm.expectRevert(Errors.StaleFeedData.selector);
    s_baseAuction.performUpkeep(performData);
  }

  function test_performUpkeep_RevertWhen_AssetOutParamsNotSet()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // End running aution to remove asset out params
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    _changePrank(i_assetAdmin);
    address[] memory removedAssets = new address[](1);
    removedAssets[0] = address(s_mockLINK);
    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removedAssets);

    _changePrank(i_auctionAdmin);
    vm.expectRevert(BaseAuction.MissingAssetOutParams.selector);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), new address[](0)));
  }

  function test_performUpkeep_RevertWhen_EligibleAssetHasLiveAuction()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Attempt to start a new auction for USDC while the previous one is still live
    deal(address(s_mockUSDC), address(s_feeAggregator), USDC_AUCTIONED_AMOUNT); // $100,000 worth of USDC

    Common.AssetAmount[] memory eligibleAssets = new Common.AssetAmount[](1);
    eligibleAssets[0] = Common.AssetAmount({asset: address(s_mockUSDC), amount: USDC_AUCTIONED_AMOUNT});

    _changePrank(i_auctionAdmin);
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.LiveAuction.selector, address(s_mockUSDC)));
    s_baseAuction.performUpkeep(abi.encode(eligibleAssets, new address[](0)));
  }

  function test_performUpkeep_RevertWhen_EligibleAssetParamsNotSet()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Force end the running auction to reconfigure
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    // Remove the asset params for the eligible asset to cause the revert in performUpkeep
    address[] memory removes = new address[](1);
    removes[0] = address(s_mockUSDC);
    _changePrank(i_assetAdmin);
    s_baseAuction.applyAssetParamsUpdates(new BaseAuction.ApplyAssetParamsUpdate[](0), removes);

    // Set the fee aggregator to the base auction to ensure that the upkeep process reaches the point of checking the
    // eligible asset params (else it reverts on transferForSwap)
    _changePrank(i_owner);
    s_baseAuction.setFeeAggregator(address(s_baseAuction));

    Common.AssetAmount[] memory eligibleAssets = new Common.AssetAmount[](1);
    eligibleAssets[0] = Common.AssetAmount({asset: address(s_mockUSDC), amount: 1});
    _changePrank(i_auctionAdmin);
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.AssetParamsNotSet.selector, address(s_mockUSDC)));
    s_baseAuction.performUpkeep(abi.encode(eligibleAssets, new address[](0)));
  }

  function test_performUpkeep_RevertWhen_AmountBelowMinAuctionSize()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // End running auction to attempt restart with insufficient amount
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    deal(address(s_mockUSDC), address(s_feeAggregator), 1);

    Common.AssetAmount[] memory eligibleAssets = new Common.AssetAmount[](1);
    eligibleAssets[0] = Common.AssetAmount({asset: address(s_mockUSDC), amount: 1});

    _changePrank(i_auctionAdmin);
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.AmountBelowMinAuctionSize.selector, 1e12, MIN_AUCTION_SIZE_USD));
    s_baseAuction.performUpkeep(abi.encode(eligibleAssets, new address[](0)));
  }

  function test_performUpkeep_RevertWhen_InvalidAuction()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = s_baseAuction.getAssetOut();

    _changePrank(i_auctionAdmin);
    vm.expectRevert(abi.encodeWithSelector(BaseAuction.InvalidAuction.selector, address(s_mockLINK)));
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));
  }

  function test_performUpkeep_SingleAssetOutTransferWhenFeeAggregatorEqBaseAuction()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    // Force end the running auction to reconfigure
    Common.AssetAmount[] memory eligibleAssets = new Common.AssetAmount[](0);
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    s_baseAuction.performUpkeep(abi.encode(eligibleAssets, endedAuctions));

    // Set the fee aggregator to the base auction to ensure that the upkeep process reaches the point of checking the
    // eligible asset params (else it reverts on transferForSwap)
    _changePrank(i_owner);
    s_baseAuction.setFeeAggregator(address(s_baseAuction));

    // Restart auction for USDC
    deal(address(s_mockUSDC), address(s_baseAuction), USDC_AUCTIONED_AMOUNT); // $100,000 worth of USDC
    _changePrank(i_auctionAdmin);
    (bool upkeepNeeded, bytes memory performData) = s_baseAuction.checkUpkeep("");
    s_baseAuction.performUpkeep(performData);

    _changePrank(i_auctionBidder);

    Caller.Call[] memory solution = new Caller.Call[](1);
    solution[0] = Caller.Call({
      target: address(s_mockUSDC),
      data: abi.encodeWithSelector(IERC20.approve.selector, address(s_mockUniswapRouter), USDC_AUCTIONED_AMOUNT)
    });

    vm.expectEmit(address(s_auction));
    emit BaseAuction.AuctionBidSettled(address(s_auctionBidder), address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, 5_250e18);

    s_auctionBidder.bid(address(s_mockUSDC), USDC_AUCTIONED_AMOUNT, solution);

    (upkeepNeeded, performData) = s_baseAuction.checkUpkeep("");

    assertTrue(upkeepNeeded);

    (eligibleAssets, endedAuctions) = abi.decode(performData, (Common.AssetAmount[], address[]));

    assertEq(s_mockUSDC.balanceOf(address(s_baseAuction)), 0);
    assertEq(s_mockLINK.balanceOf(address(s_baseAuction)), 5_250e18);

    assertEq(eligibleAssets.length, 1);
    assertEq(eligibleAssets[0].asset, address(s_mockLINK));
    assertEq(endedAuctions.length, 1);
    assertEq(endedAuctions[0], address(s_mockUSDC));

    _changePrank(i_auctionAdmin);

    vm.recordLogs();
    s_baseAuction.performUpkeep(performData);

    Vm.Log[] memory logs = vm.getRecordedLogs();

    assertEq(logs.length, 3);
    // First event should be the asset out transfer
    assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
    // Second event should be the approval revocation
    assertEq(logs[1].topics[0], keccak256("Approval(address,address,uint256)"));
    // Third event should be the AuctionEnded
    assertEq(logs[2].topics[0], keccak256("AuctionEnded(address)"));
  }

  function test_performUpkeep_ForceEndAuctionWithStaleAssetOutPrice()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    skip(s_baseAuction.getFeedInfo(address(s_mockLINK)).stalenessThreshold + 1);
    address[] memory endedAuctions = new address[](1);
    endedAuctions[0] = address(s_mockUSDC);
    _changePrank(i_auctionAdmin);

    vm.expectEmit(address(s_baseAuction));
    emit BaseAuction.AuctionEnded(address(s_mockUSDC));
    s_baseAuction.performUpkeep(abi.encode(new Common.AssetAmount[](0), endedAuctions));

    assertEq(s_baseAuction.getAuctionStart(address(s_mockUSDC)), 0);
    assertEq(IERC20(address(s_mockUSDC)).balanceOf(address(s_baseAuction)), 0);
    assertEq(IERC20(address(s_mockUSDC)).balanceOf(address(s_feeAggregator)), USDC_AUCTIONED_AMOUNT);
  }
}
