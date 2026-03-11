// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PriceManager} from "src/PriceManager.sol";
import {BasePriceManagerForkTest} from "test/fork/price-manager/BasePriceManagerForkTest.t.sol";

contract PriceManager_TransmitForkTest is BasePriceManagerForkTest {
  function setUp() external {
    _changePrank(i_priceAdmin);
  }

  function test_transmit() external performForAllContracts(CommonContracts.PRICE_MANAGER) {
    vm.expectEmit(s_contractUnderTest);
    emit PriceManager.PriceTransmitted(LINK, uint256(uint192(s_linkReport.price)));
    vm.expectEmit(s_contractUnderTest);
    emit PriceManager.PriceTransmitted(WETH, uint256(uint192(s_ethReport.price)));
    vm.expectEmit(s_contractUnderTest);
    emit PriceManager.PriceTransmitted(USDC, uint256(uint192(s_usdcReport.price)));
    PriceManager(s_contractUnderTest).transmit(s_unverifiedReports);

    (uint256 linkPrice, uint256 linkUpdatedAt, bool isLinkPriceValid) = s_auction.getAssetPrice(LINK);
    (uint256 ethPrice, uint256 ethUpdatedAt, bool isEthPriceValid) = s_auction.getAssetPrice(WETH);
    (uint256 usdcPrice, uint256 usdcUpdatedAt, bool isUsdcPriceValid) = s_auction.getAssetPrice(USDC);

    assertEq(linkPrice, uint256(uint192(s_linkReport.price)));
    assertEq(linkUpdatedAt, s_linkReport.observationsTimestamp);
    assertTrue(isLinkPriceValid);
    assertEq(ethPrice, uint256(uint192(s_ethReport.price)));
    assertEq(ethUpdatedAt, s_ethReport.observationsTimestamp);
    assertTrue(isEthPriceValid);
    assertEq(usdcPrice, uint256(uint192(s_usdcReport.price)));
    assertEq(usdcUpdatedAt, s_usdcReport.observationsTimestamp);
    assertTrue(isUsdcPriceValid);
  }
}
