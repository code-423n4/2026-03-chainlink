// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";
import {GPv2Interaction} from "@cowprotocol/libraries/GPv2Interaction.sol";
import {GPv2Trade} from "@cowprotocol/libraries/GPv2Trade.sol";

/// @notice This interface is required to recompute the CowProtocol order id by calling the GPV2Settlement contract.
interface IGPV2Settlement {
  function domainSeparator() external view returns (bytes32);

  function settle(
    IERC20[] calldata tokens,
    uint256[] calldata clearingPrices,
    GPv2Trade.Data[] calldata trades,
    GPv2Interaction.Data[][3] calldata interactions
  ) external;

  function invalidateOrder(
    bytes calldata orderUid
  ) external;
}
