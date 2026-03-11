// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBaseAuction {
  /// @notice method that is simulated by auction manager to see if any work actually
  /// needs to be performed.
  /// @param checkData Unused parameter, only for CLA backward compatibility.
  /// @return upkeepNeeded boolean to indicate whether the auction manager should call
  /// performUpkeep or not.
  /// @return performData bytes that the workflow should call performUpkeep with, if
  /// upkeep is needed. If you would like to encode data to decode later, try
  /// `abi.encode`.
  function checkUpkeep(
    bytes calldata checkData
  ) external returns (bool upkeepNeeded, bytes memory performData);

  /// @notice method that is actually executed by the auction manager.
  /// The data returned by the checkUpkeep simulation will be passed into
  /// this method to actually be executed.
  /// @param performData is the data which was passed back from the checkData
  /// simulation. If it is encoded, it can easily be decoded into other types by
  /// calling `abi.decode`. This data should not be trusted, and should be
  /// validated against the contract's current state.
  function performUpkeep(
    bytes calldata performData
  ) external;

  /// @notice Allows a user to bid in an active auction for a specific asset.
  /// @param asset The address of the asset being auctioned.
  /// @param amount The amount of the asset being auctioned.
  /// @param data The optional data to be sent to the receiver as part of the callback
  function bid(
    address asset,
    uint256 amount,
    bytes calldata data
  ) external;

  /// @notice Getter function to retrieve the asset out address.
  /// @return assetOut The address of the asset out.
  function getAssetOut() external view returns (address assetOut);

  // @notice Getter function to compute the current auction price for a given asset and amount at a specific timestamp.
  /// @param assetIn The address of the asset.
  /// @param amount The amount of the asset.
  /// @param timestamp The timestamp at which to compute the auction price.
  /// @return assetOutAmount The computed auction price in terms of the asset out.
  function getAssetOutAmount(
    address assetIn,
    uint256 amount,
    uint256 timestamp
  ) external view returns (uint256 assetOutAmount);
}
