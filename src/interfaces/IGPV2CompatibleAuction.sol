// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGPV2CompatibleAuction {
  /// @notice Invalidates CowProtocol orders by their unique identifiers (UIDs).
  /// @param orderUids An array of bytes, where each element is the unique identifier of the order that is to be made
  /// invalid after calling this function.
  function invalidateOrders(
    bytes[] calldata orderUids
  ) external;
}
