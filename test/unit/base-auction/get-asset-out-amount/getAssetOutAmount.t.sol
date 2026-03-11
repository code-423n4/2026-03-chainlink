// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IFeeAggregator} from "src/interfaces/IFeeAggregator.sol";

import {BaseAuction} from "src/BaseAuction.sol";
import {PriceManagerHelper} from "test/helpers/PriceManagerHelper.t.sol";
import {BaseUnitTest} from "test/unit/BaseUnitTest.t.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseAuction_GetAssetOutAmount is BaseUnitTest, PriceManagerHelper {
  uint256 private constant AUCTION_VALUE = 1_000_000e18; // $1,000,000

  BaseAuction private s_baseAuction;

  mapping(address asset => uint256 amount) private s_baseAuctionedAmounts;

  function setUp() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    s_baseAuction = BaseAuction(s_contractUnderTest);

    // Set asset decimals
    vm.mockCall(i_asset1, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
    vm.mockCall(i_asset2, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
    vm.mockCall(i_asset3, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(24));
    vm.mockCall(i_mockLink, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));

    // Set asset params
    BaseAuction.ApplyAssetParamsUpdate[] memory assetParamsUpdates = new BaseAuction.ApplyAssetParamsUpdate[](4);
    // +10% -> -2%
    assetParamsUpdates[0] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_asset1,
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.1e18, // 10% starting premium
        endingPriceMultiplier: 0.98e18, // 2% maximum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    // +5% -> -1%
    assetParamsUpdates[1] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_asset2,
      params: BaseAuction.AssetParams({
        decimals: 6,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.05e18, // 5% starting premium
        endingPriceMultiplier: 0.99e18, // 1% maximum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    // +2% -> -0.5%
    assetParamsUpdates[2] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_asset3,
      params: BaseAuction.AssetParams({
        decimals: 24,
        auctionDuration: 1 days,
        startingPriceMultiplier: 1.02e18, // 2% starting premium
        endingPriceMultiplier: 0.985e18, // 0.5% maximum discount
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });
    assetParamsUpdates[3] = BaseAuction.ApplyAssetParamsUpdate({
      asset: i_mockLink,
      params: BaseAuction.AssetParams({
        decimals: 18,
        auctionDuration: 1,
        startingPriceMultiplier: 1e18,
        endingPriceMultiplier: 1e18,
        minAuctionSizeUsd: MIN_AUCTION_SIZE_USD
      })
    });

    _changePrank(i_assetAdmin);
    s_baseAuction.applyAssetParamsUpdates(assetParamsUpdates, new address[](0));

    // Set asset prices
    PriceManagerHelper.AssetPrice[] memory assetPrices = new PriceManagerHelper.AssetPrice[](4);
    assetPrices[0] = PriceManagerHelper.AssetPrice({asset: i_asset1, price: 4_000e18}); // $4,000
    assetPrices[1] = PriceManagerHelper.AssetPrice({asset: i_asset2, price: 1e8}); // $1
    assetPrices[2] = PriceManagerHelper.AssetPrice({asset: i_asset3, price: 100e24}); // $100
    assetPrices[3] = PriceManagerHelper.AssetPrice({asset: i_mockLink, price: 20e18}); // $20

    _changePrank(i_priceAdmin);
    _transmitAssetPrices(s_baseAuction, assetPrices);

    // Fund FeeAggregator with $1M worth of each auctionable asset
    s_baseAuctionedAmounts[i_asset1] = _dealAssetValue(address(i_asset1), AUCTION_VALUE);
    s_baseAuctionedAmounts[i_asset2] = _dealAssetValue(address(i_asset2), AUCTION_VALUE);
    s_baseAuctionedAmounts[i_asset3] = _dealAssetValue(address(i_asset3), AUCTION_VALUE);
    _dealAssetValue(address(i_mockLink), 0);

    // Start auctions for all auctionable assets
    vm.mockCall(address(s_feeAggregator), IFeeAggregator.transferForSwap.selector, abi.encode(true));

    vm.mockCall(
      address(i_asset1),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)),
      abi.encode(s_baseAuctionedAmounts[i_asset1])
    );
    vm.mockCall(
      address(i_asset2),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)),
      abi.encode(s_baseAuctionedAmounts[i_asset2])
    );
    vm.mockCall(
      address(i_asset3),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_baseAuction)),
      abi.encode(s_baseAuctionedAmounts[i_asset3])
    );
    vm.mockCall(
      address(i_asset1),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );
    vm.mockCall(
      address(i_asset2),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );
    vm.mockCall(
      address(i_asset3),
      abi.encodeWithSelector(IERC20.allowance.selector, address(s_baseAuction), i_mockGPV2VaultRelayer),
      abi.encode(0)
    );

    _changePrank(i_auctionAdmin);
    (, bytes memory performData) = s_baseAuction.checkUpkeep("");
    s_baseAuction.performUpkeep(performData);
  }

  function test_getAssetOutAmount_WhenInvalidAuction() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    assertEq(s_baseAuction.getAssetOutAmount(address(i_mockLink), 1e18, block.timestamp), 0);
  }

  function test_getAssetOutAmount_WhenAuctionEnded() external performForAllContracts(CommonContracts.BASE_AUCTION) {
    skip(s_baseAuction.getAssetParams(i_asset1).auctionDuration + 1);

    assertEq(s_baseAuction.getAssetOutAmount(address(i_asset1), 1e18, block.timestamp), 0);
  }

  function test_getAssetOutAmount_WhenTimestampLtAuctionStart()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    uint256 assetOutAmount = s_baseAuction.getAssetOutAmount(address(i_asset1), 1e18, 0);

    assertEq(assetOutAmount, 0);
  }

  function test_getAssetOutAmount_WithHigherAmountThanAvailableInAuction()
    external
    performForAllContracts(CommonContracts.BASE_AUCTION)
  {
    uint256 assetOutAmount =
      s_baseAuction.getAssetOutAmount(address(i_asset1), s_baseAuctionedAmounts[i_asset1] + 1, block.timestamp);

    // Asset 1 price = $4,000
    // Total auction value = $1,000,000
    // Initial price multiplier = 1.1e18 (10% premium)
    // Auction value * initial price multiplier = $1,100,000
    // Asset out price = $20
    // Auction value / asset out price = $1,100,000 / $20 = 55,000
    assertEq(assetOutAmount, 55_000e18);
  }

  function testFuzz_getAssetOutAmount(
    uint256 timeElapsed,
    uint256 amount
  ) external performForAllContracts(CommonContracts.BASE_AUCTION) {
    timeElapsed = bound(timeElapsed, 0, s_baseAuction.getAssetParams(i_asset1).auctionDuration);
    skip(timeElapsed);

    uint256 asset1Amount = bound(amount, _getMinAuctionSizeBalance(i_asset1), s_baseAuctionedAmounts[i_asset1]);
    uint256 asset2Amount = bound(amount, _getMinAuctionSizeBalance(i_asset2), s_baseAuctionedAmounts[i_asset2]);
    uint256 asset3Amount = bound(amount, _getMinAuctionSizeBalance(i_asset3), s_baseAuctionedAmounts[i_asset3]);

    uint256 asset1assetOutAmount = s_baseAuction.getAssetOutAmount(address(i_asset1), asset1Amount, block.timestamp);
    uint256 asset2assetOutAmount = s_baseAuction.getAssetOutAmount(address(i_asset2), asset2Amount, block.timestamp);
    uint256 asset3assetOutAmount = s_baseAuction.getAssetOutAmount(address(i_asset3), asset3Amount, block.timestamp);

    // asset 1 price = $4,000
    // asset out price = $20
    // asset 1 price / asset out price = 200
    // max auction discount = 2%
    // asset 1 has 18 decimals, asset out has 18 decimals, so no adjustment needed
    assertGe(asset1assetOutAmount, 200 * asset1Amount * 98 / 100);
    // asset 2 price = $1
    // asset out price = $20
    // asset 1 price / asset out price = 0.05
    // max auction discount = 2%
    // asset 2 has 6 decimals, asset out has 18 decimals, so we need to adjust by 10**12
    assertGe(asset2assetOutAmount, 5 * asset2Amount / 100 * 98 / 100 * 10 ** 12);
    // asset 3 price = $100
    // asset out price = $20
    // asset 1 price / asset out price = 5
    // max auction discount = 2%
    // asset 3 has 24 decimals, asset out has 18 decimals, so we need to adjust by 10**6
    assertGe(asset3assetOutAmount, 5 * asset3Amount * 98 / 100 / 10 ** 6);
  }

  function _dealAssetValue(
    address asset,
    uint256 usdValue
  ) private returns (uint256 assetAmount) {
    BaseAuction.AssetParams memory assetParams = s_baseAuction.getAssetParams(asset);

    (uint256 assetPrice,,) = s_baseAuction.getAssetPrice(asset);
    assetAmount = (usdValue * 10 ** assetParams.decimals) / uint256(assetPrice);
    vm.mockCall(
      asset, abi.encodeWithSelector(IERC20.balanceOf.selector, address(s_feeAggregator)), abi.encode(assetAmount)
    );

    return assetAmount;
  }

  function _getMinAuctionSizeBalance(
    address asset
  ) private view returns (uint256) {
    BaseAuction.AssetParams memory assetParams = s_baseAuction.getAssetParams(asset);
    (uint256 assetPrice,,) = s_baseAuction.getAssetPrice(asset);
    return (assetParams.minAuctionSizeUsd * 10 ** assetParams.decimals) / uint256(assetPrice);
  }
}
