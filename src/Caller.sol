// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Errors} from "src/libraries/Errors.sol";

/// @title Caller Contract.
/// @notice This abstract contract provides functionality to perform low-level calls to other contracts and handle
/// errors
abstract contract Caller {
  error LowLevelCallFailed();

  struct Call {
    address target; // The address to be called.
    bytes data; // The lowlevel call data.
  }

  /// @notice Perfoms a low-level call to a target address with the provided data and bubbles up revert messages.
  /// @param target The address to call.
  /// @param data The call data to send to the target.
  /// @return returnData The data returned from the call.
  function _call(
    address target,
    bytes memory data
  ) internal returns (bytes memory returnData) {
    // If the caller has specified data.
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory response) = target.call(data);

    // Check if the call was successful or not.
    if (!success) {
      // If there is return data, the call reverted with a reason or a custom error, which we bubble up.
      if (response.length > 0) {
        assembly {
          // The length of the data is at `response`, while the actual data is at `response + 32`.
          let returndataSize := mload(response)
          revert(add(response, 32), returndataSize)
        }
      } else {
        revert LowLevelCallFailed();
      }
    }

    return response;
  }

  /// @notice Performs multiple low-level calls to target addresses with the provided data.
  /// @param calls An array of Call structs containing target addresses and call data.
  /// @return returnData An array of bytes containing the data returned from each call.
  function _multiCall(
    Call[] memory calls
  ) internal returns (bytes[] memory) {
    if (calls.length == 0) {
      revert Errors.EmptyList();
    }

    bytes[] memory returnData = new bytes[](calls.length);

    for (uint256 i = 0; i < calls.length; ++i) {
      returnData[i] = _call(calls[i].target, calls[i].data);
    }

    return returnData;
  }
}
