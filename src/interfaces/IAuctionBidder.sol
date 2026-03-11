// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Caller} from "src/Caller.sol";

interface IAuctionBidder {
  /// @notice Bids on the auction contract and optionally executes arbitrary pre-bid logic.
  /// @param assetIn The address of the asset to bid with.
  /// @param amount The amount of the asset to bid.
  /// @param solution The list of calls to execute to solve the bid.
  function bid(
    address assetIn,
    uint256 amount,
    Caller.Call[] calldata solution
  ) external;
}
