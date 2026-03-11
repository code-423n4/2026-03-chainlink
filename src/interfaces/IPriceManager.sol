// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPriceManager {
  /// @notice Transmits Data Streams reports (schema v3) and updates asset prices.
  /// @dev precondition - the unverifiedReports list must not be empty.
  /// @dev precondition - the caller must have the PRICE_ADMIN_ROLE.
  /// @dev precondition - the report's feed id must be allowlisted.
  /// @param unverifiedReports list of full payload returned by Data Streams API.
  function transmit(
    bytes[] calldata unverifiedReports
  ) external;
}
