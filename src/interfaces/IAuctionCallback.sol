// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAuctionCallback {
  /// @notice The auction callback function which executes the solving logic.
  /// @param from The address of the caller of the auction contract's bid function.
  /// @param asset The address of the asset being auctioned.
  /// @param amountOut The amount of asset's being sold to the auction.
  /// @param data The auction callback data originally passed from the bid function.
  function auctionCallback(
    address from,
    address asset,
    uint256 amountOut,
    bytes calldata data
  ) external;
}
