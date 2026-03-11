// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "src/libraries/Roles.sol";

import {IVerifierProxy} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {PriceManager} from "src/PriceManager.sol";

abstract contract PriceManagerHelper is Test {
  struct AssetPrice {
    address asset;
    uint256 price;
  }

  function _transmitAssetPrices(
    PriceManager priceManager,
    AssetPrice[] memory assetPrices
  ) internal {
    bytes[] memory unverifiedReports = new bytes[](assetPrices.length);
    bytes[] memory verifiedReports = new bytes[](assetPrices.length);

    bytes32[3] memory context = [bytes32(0), bytes32(0), bytes32(0)];
    bytes32[] memory rs = new bytes32[](2);
    bytes32[] memory ss = new bytes32[](2);
    bytes32 rawVs;

    for (uint256 i = 0; i < assetPrices.length; ++i) {
      PriceManager.ReportV3 memory report;
      report.dataStreamsFeedId = priceManager.getFeedInfo(assetPrices[i].asset).dataStreamsFeedId;
      report.price = int192(uint192(assetPrices[i].price));
      report.observationsTimestamp = uint32(block.timestamp);

      unverifiedReports[i] = abi.encode(context, abi.encode(report), rs, ss, rawVs);
      verifiedReports[i] = abi.encode(report);
    }

    IVerifierProxy streamsVerifierProxy = priceManager.getStreamsVerifierProxy();
    IERC20 link = priceManager.getLinkToken();

    if (address(streamsVerifierProxy).code.length == 0) {
      vm.mockCall(
        address(streamsVerifierProxy),
        abi.encodeWithSelector(IVerifierProxy.verifyBulk.selector, unverifiedReports, abi.encode(link)),
        abi.encode(verifiedReports)
      );
    }

    (, address msgSender,) = vm.readCallers();
    address priceAdmin = priceManager.getRoleMember(Roles.PRICE_ADMIN_ROLE, 0);

    vm.stopPrank();
    vm.startPrank(priceAdmin);

    priceManager.transmit(unverifiedReports);

    vm.stopPrank();
    vm.startPrank(msgSender);
  }
}
