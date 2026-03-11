// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC165, IReceiver} from "@chainlink/contracts/src/v0.8/keystone/interfaces/IReceiver.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";
import {IAuctionBidder} from "src/interfaces/IAuctionBidder.sol";
import {IBaseAuction} from "src/interfaces/IBaseAuction.sol";
import {IPriceManager} from "src/interfaces/IPriceManager.sol";

import {Caller} from "src/Caller.sol";
import {PausableWithAccessControl} from "src/PausableWithAccessControl.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Roles} from "src/libraries/Roles.sol";

contract WorkflowRouter is PausableWithAccessControl, IReceiver, ITypeAndVersion {
  /// @notice This error is thrown when the workflow ID extracted from the metadata does not correspond to any of the
  /// accepted workflow types.
  /// @param workflowId The unauthorized workflow ID.
  error UnauthorizedWorkflow(bytes32 workflowId);
  /// @notice This error is thrown when an invalid auction contract is provided.
  error InvalidAuctionContract(address auction);
  /// @notice This error is thrown when an invalid auction bidder contract is provided.
  error InvalidAuctionBidder(address auctionBidder);

  /// @notice This event is emitted when the auction contract is set.
  /// @param auction The address of the auction contract.
  event AuctionSet(address indexed auction);
  /// @notice This event is emitted when the auction bidder contract is set.
  /// @param auctionBidder The address of the auction bidder contract.
  event AuctionBidderSet(address indexed auctionBidder);
  /// @notice This event is emitted when a workflow ID is set for a specific workflow type.
  /// @param workflowType The type of the workflow.
  /// @param workflowId The unique identifier of the workflow.
  event WorkflowIdSet(WorkflowType indexed workflowType, bytes32 indexed workflowId);

  /// @notice Enum representing different workflow types
  enum WorkflowType {
    PRICE_ADMIN,
    AUCTION_WORKER,
    AUCTION_BIDDER
  }

  /// @notice Parameters to initialize the contract.
  struct ConstructorParams {
    address admin; // ───────────────────╮ The initial contract admin.
    uint48 adminRoleTransferDelay; // ───╯ The min seconds before the admin address can be transferred.
    address auction; //                    The Auction contract.
    address auctionBidder; //              The Auction Bidder contract.
    SetWorkflowIdParams[] workflowIds; //  The workflow IDs to set for specific workflow types.
  }

  /// @notice Parameters to set a workflow ID for a specific workflow type.
  struct SetWorkflowIdParams {
    WorkflowType workflowType; // The type of the workflow.
    bytes32 workflowId; // The unique identifier of the workflow.
  }

  /// @inheritdoc ITypeAndVersion
  string public constant override typeAndVersion = "WorkflowRouter 1.0.0-dev";

  /// @notice The Auction contract.
  address private s_auction;
  /// @notice The Auction Bidder contract.
  IAuctionBidder private s_auctionBidder;

  /// @notice Mapping of workflow types to their unique identifiers.
  mapping(WorkflowType workflowType => bytes32 workflowId) private s_workflowIds;

  constructor(
    ConstructorParams memory params
  ) PausableWithAccessControl(params.adminRoleTransferDelay, params.admin) {
    _setAuction(params.auction);
    _setAuctionBidder(params.auctionBidder);

    if (params.workflowIds.length > 0) {
      _setWorkflowIds(params.workflowIds);
    }
  }

  /// @inheritdoc IReceiver
  /// @dev precondition - the contract must not be paused.
  /// @dev precondition - the caller must have the FORWARDER_ROLE.
  /// @dev precondition - the workflow ID extracted from the metadata must correspond to a supported workflow type.
  function onReport(
    bytes calldata metadata,
    bytes calldata report
  ) external whenNotPaused onlyRole(Roles.FORWARDER_ROLE) {
    // Metadata structure:
    // - Offset 32, size 32: workflow_id (bytes32)
    // - Offset 64, size 10: workflow_name (bytes10)
    // - Offset 74, size 20: workflow_owner (address)
    bytes32 workflowId = bytes32(metadata[:32]);
    if (workflowId == bytes32(0)) {
      revert Errors.InvalidZeroValue();
    }

    if (workflowId == s_workflowIds[WorkflowType.PRICE_ADMIN]) {
      bytes[] memory unverifiedReports = abi.decode(report, (bytes[]));
      IPriceManager(s_auction).transmit(unverifiedReports);
    } else if (workflowId == s_workflowIds[WorkflowType.AUCTION_WORKER]) {
      IBaseAuction(s_auction).performUpkeep(report);
    } else if (workflowId == s_workflowIds[WorkflowType.AUCTION_BIDDER]) {
      (address assetIn, uint256 amount, Caller.Call[] memory solution) =
        abi.decode(report, (address, uint256, Caller.Call[]));
      s_auctionBidder.bid(assetIn, amount, solution);
    } else {
      revert UnauthorizedWorkflow(workflowId);
    }
  }

  // ================================================================================================
  // │                                        Configuration                                         │
  // ================================================================================================

  /// @notice Sets the auction contract.
  /// @dev precondition - the caller must have the DEFAULT_ADMIN_ROLE.
  /// @param auction The address of the auction contract.
  function setAuction(
    address auction
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setAuction(auction);
  }

  /// @notice Internal function to set the auction contract.
  /// @dev precondition - the auction address must not be zero.
  /// @dev precondition - the auction contract must implement the IBaseAuction and IPriceManager interfaces.
  /// @param auction The address of the auction contract.
  function _setAuction(
    address auction
  ) internal {
    if (auction == address(0)) {
      revert Errors.InvalidZeroAddress();
    }
    if (!(IERC165(auction).supportsInterface(type(IBaseAuction).interfaceId)
          && IERC165(auction).supportsInterface(type(IPriceManager).interfaceId))) {
      revert InvalidAuctionContract(auction);
    }
    if (address(s_auction) == auction) {
      revert Errors.ValueNotUpdated();
    }

    s_auction = auction;

    emit AuctionSet(auction);
  }

  /// @notice Sets the auction bidder contract.
  /// @dev precondition - the caller must have the DEFAULT_ADMIN_ROLE.
  /// @param auctionBidder The address of the auction bidder contract.
  function setAuctionBidder(
    address auctionBidder
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setAuctionBidder(auctionBidder);
  }

  /// @notice Internal function to set the auction bidder contract.
  /// @dev precondition - the auction bidder address must not be zero.
  /// @dev precondition - the auction bidder contract must implement the IAuctionBidder interface.
  /// @param auctionBidder The address of the auction bidder contract.
  function _setAuctionBidder(
    address auctionBidder
  ) internal {
    if (auctionBidder == address(0)) {
      revert Errors.InvalidZeroAddress();
    }
    if (!IERC165(auctionBidder).supportsInterface(type(IAuctionBidder).interfaceId)) {
      revert InvalidAuctionBidder(auctionBidder);
    }
    if (address(s_auctionBidder) == auctionBidder) {
      revert Errors.ValueNotUpdated();
    }

    s_auctionBidder = IAuctionBidder(auctionBidder);

    emit AuctionBidderSet(auctionBidder);
  }

  /// @notice Sets workflow IDs for specific workflow types.
  /// @dev precondition - the caller must have the DEFAULT_ADMIN_ROLE.
  function setWorkflowIds(
    SetWorkflowIdParams[] memory params
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setWorkflowIds(params);
  }

  /// @dev precondition - the new workflow IDs must not be zero.
  /// @dev precondition - the new workflow id must be different than the one already set.
  function _setWorkflowIds(
    SetWorkflowIdParams[] memory params
  ) internal {
    for (uint256 i = 0; i < params.length; ++i) {
      if (params[i].workflowId == bytes32(0)) {
        revert Errors.InvalidZeroValue();
      }
      if (s_workflowIds[params[i].workflowType] == params[i].workflowId) {
        revert Errors.ValueNotUpdated();
      }

      s_workflowIds[params[i].workflowType] = params[i].workflowId;

      emit WorkflowIdSet(params[i].workflowType, params[i].workflowId);
    }
  }

  // ================================================================================================
  // │                                           Getters                                            │
  // ================================================================================================

  /// @notice Getter function to retrieve the auction contract.
  /// @return auction The address of the auction contract.
  function getAuction() external view returns (address auction) {
    return s_auction;
  }

  /// @notice Getter function to retrieve the auction bidder contract.
  /// @return auctionBidder The address of the auction bidder contract.
  function getAuctionBidder() external view returns (IAuctionBidder auctionBidder) {
    return s_auctionBidder;
  }

  /// @notice Getter function to retrieve the workflow ID for a specific workflow type.
  /// @param workflowType The type of the workflow.
  /// @return workflowId The unique identifier of the workflow.
  function getWorkflowId(
    WorkflowType workflowType
  ) external view returns (bytes32 workflowId) {
    return s_workflowIds[workflowType];
  }

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(PausableWithAccessControl, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId) || interfaceId == type(IReceiver).interfaceId;
  }
}
