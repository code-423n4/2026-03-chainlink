// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title ILinkAvailable Interface.
interface ILinkAvailable {
  /// @notice Returns the available LINK balance for payment.
  /// @return availableBalance The available LINK balance for payment.
  function linkAvailableForPayment() external view returns (int256 availableBalance);
}
