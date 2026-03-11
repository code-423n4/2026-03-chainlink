// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Common} from "@chainlink/contracts/src/v0.8/llo-feeds/libraries/Common.sol";
import {IVerifierFeeManager} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierFeeManager.sol";
import {IVerifierProxy} from "@chainlink/contracts/src/v0.8/llo-feeds/v0.5.0/interfaces/IVerifierProxy.sol";
import {AccessControllerInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AccessControllerInterface.sol";

/// @title This contract is used to mock the VerifierProxy contract
contract MockVerifierProxy is IVerifierProxy {
  /// @inheritdoc IVerifierProxy
  function verify(
    bytes calldata,
    bytes calldata
  ) external payable returns (bytes memory verifierResponse) {
    return verifierResponse;
  }

  /// @inheritdoc IVerifierProxy
  function verifyBulk(
    bytes[] calldata unverifiedReports,
    bytes calldata
  ) external payable returns (bytes[] memory verifiedReports) {
    verifiedReports = new bytes[](unverifiedReports.length);

    for (uint256 i; i < unverifiedReports.length; ++i) {
      // Decode the unverified report.
      (, bytes memory reportData,,,) =
        abi.decode(unverifiedReports[i], (bytes32[3], bytes, bytes32[], bytes32[], bytes32));

      verifiedReports[i] = reportData;
    }

    return verifiedReports;
  }

  /// @inheritdoc IVerifierProxy
  function initializeVerifier(
    address verifierAddress
  ) external {}

  /// @inheritdoc IVerifierProxy
  function setVerifier(
    bytes32 currentConfigDigest,
    bytes32 newConfigDigest,
    Common.AddressAndWeight[] memory addressesAndWeights
  ) external {}

  /// @inheritdoc IVerifierProxy
  function unsetVerifier(
    bytes32 configDigest
  ) external {}

  /// @inheritdoc IVerifierProxy
  function getVerifier(
    bytes32
  ) external pure returns (address verifierAddress) {
    return verifierAddress;
  }

  /// @inheritdoc IVerifierProxy
  function setAccessController(
    AccessControllerInterface accessController
  ) external {}

  /// @inheritdoc IVerifierProxy
  function setFeeManager(
    IVerifierFeeManager feeManager
  ) external {}
}
