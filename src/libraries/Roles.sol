// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Library for payment abstraction contract roles IDs to use with the OpenZeppelin AccessControl contracts.
library Roles {
  /// @notice This is the ID for the pauser role, which is given to the addresses that can pause and
  /// the contract.
  /// @dev Hash: 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  /// @notice This is the ID for the unpauser role, which is given to the addresses that can unpause
  /// the contract.
  /// @dev Hash: 0x427da25fe773164f88948d3e215c94b6554e2ed5e5f203a821c9f2f6131cf75a
  bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
  /// @notice This is the ID for the asset admin role, which is given to the addresses that can:
  /// - Add and remove assets from the allowlist
  /// - Set the swap parameters for an asset
  /// @dev Hash: 0x5e608239aadc5f1e750186f22bbac828160fb6191c4a7b9eee6b9432b1eac59e
  bytes32 public constant ASSET_ADMIN_ROLE = keccak256("ASSET_ADMIN_ROLE");
  /// @notice This is the ID for the bridger role, which is given to addresses that are able to
  /// bridge assets
  /// @dev Hash: 0xc809a7fd521f10cdc3c068621a1c61d5fd9bb3f1502a773e53811bc248d919a8
  bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");
  /// @notice This is the ID for earmark manager role, which is given to addresses that are able to
  /// set earmarks
  /// @dev Hash: 0xa1ccbd74bc39a2421c04f3b35fcdea6a99019423855b3e642ec1ef8e448afb97
  bytes32 public constant EARMARK_MANAGER_ROLE = keccak256("EARMARK_MANAGER_ROLE");
  /// @notice This is the ID for the withdrawer role, which is given to addresses that are able to able to withdraw non
  /// allowlisted assets
  /// @dev Hash: 0x10dac8c06a04bec0b551627dad28bc00d6516b0caacd1c7b345fcdb5211334e4
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
  /// @notice This is the ID for the swapper role, which is given to addresses that are able to
  /// call the transferForSwap function on the FeeAggregator contract
  /// @dev Hash: 0x724f6a44d576143e18c60911798b2b15551ca96bd8f7cb7524b8fa36253a26d8
  bytes32 public constant SWAPPER_ROLE = keccak256("SWAPPER_ROLE");
  /// @notice This is the ID for the payment validator role, which is given to addresses that are able to
  /// sign payment requests off-chain
  /// @dev Hash: 0xa04d4bae570effd1b0024bf8c7251040ba88950a58517fa84a34199781f19fb0
  bytes32 public constant PAYMENT_VALIDATOR_ROLE = keccak256("PAYMENT_VALIDATOR_ROLE");
  /// @notice This is the ID for the price admin role, which is given to addresses that are able to
  /// submit verified reports that update asset prices.
  /// @dev Hash: 0xa84abcdbbbe6d3064a118960a591ebcfeb4901477f8843988e1c9d9365bbf7ac
  bytes32 public constant PRICE_ADMIN_ROLE = keccak256("PRICE_ADMIN_ROLE");
  /// @notice This is the ID for the forwarder role, which is given to addresses that are able to
  /// to call upkeep functions.
  /// @dev Hash: 0x3fb90a982568460bdf5505b984928e3c942db3525e60c25e39051cacec08b60f
  bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");
  /// @notice This is the ID for the auction admin role, which is given to addresses that are able to
  /// call the auction's performUpkeep function.
  /// @dev Hash: 0x925d33ab4eec65fbd2286e55927010dd34c8348211723bc6d952b323ce456334
  bytes32 public constant AUCTION_WORKER_ROLE = keccak256("AUCTION_WORKER_ROLE");
  /// @notice This is the ID for the bidder role, which is given to addresses that are able to call the bidder's solve
  /// function.
  /// @dev Hash: 0xfe75b903b42451ab1e1bae25aa3093a034a04d4e7afcf46082c14302e309e584
  bytes32 public constant AUCTION_BIDDER_ROLE = keccak256("AUCTION_BIDDER_ROLE");
  /// @notice This is the ID for the order worker role, which is given to addresses that are able to call the auction's
  /// invalidateOrders function.
  /// @dev Hash: 0xa0e9ebc8333a8b9c6c09d582fbbae15a71536f8a18b8630a58ee34e8fa1306f6
  bytes32 public constant ORDER_MANAGER_ROLE = keccak256("ORDER_MANAGER_ROLE");
}
