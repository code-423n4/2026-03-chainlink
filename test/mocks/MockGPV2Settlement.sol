// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IGPV2Settlement} from "src/interfaces/IGPV2Settlement.sol";

import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";
import {GPv2Interaction} from "@cowprotocol/libraries/GPv2Interaction.sol";
import {GPv2Trade} from "@cowprotocol/libraries/GPv2Trade.sol";

contract MockGPV2Settlement is IGPV2Settlement {
  /// @dev The EIP-712 domain type hash used for computing the domain
  /// separator.
  bytes32 private constant DOMAIN_TYPE_HASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @dev The EIP-712 domain name used for computing the domain separator.
  bytes32 private constant DOMAIN_NAME = keccak256("Gnosis Protocol");

  /// @dev The EIP-712 domain version used for computing the domain separator.
  bytes32 private constant DOMAIN_VERSION = keccak256("v2");
  bytes32 private immutable i_domainSeparator;

  constructor() {
    // NOTE: Currently, the only way to get the chain ID in solidity is
    // using assembly.
    uint256 chainId;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      chainId := chainid()
    }

    i_domainSeparator = keccak256(abi.encode(DOMAIN_TYPE_HASH, DOMAIN_NAME, DOMAIN_VERSION, chainId, address(this)));
  }

  function domainSeparator() external view returns (bytes32) {
    return i_domainSeparator;
  }

  function manager() external pure returns (address) {
    return address(0);
  }

  function settle(
    IERC20[] calldata tokens,
    uint256[] calldata clearingPrices,
    GPv2Trade.Data[] calldata trades,
    GPv2Interaction.Data[][3] calldata interactions
  ) external override {}

  function invalidateOrder(
    bytes calldata orderUid
  ) external override {}
}
