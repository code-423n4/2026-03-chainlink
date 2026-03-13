# Chainlink Payment Abstraction Audit Catalyst

This audit catalyst was prepared by Zellic security researchers to accelerate competitive auditors' efficiency and effectiveness in contributing to the security of Chainlink payments in anticipation of the Code4rena competitive audit.

The protocol aggregates revenue across multiple assets and converts it into a designated settlement asset through a recurring auction mechanism. Automation infrastructure (out of scope) triggers auction lifecycle transitions and solver bids, while oracle infrastructure (also out of scope) provides pricing information required to enforce economic constraints.

## Foundational Knowledge

Auditing this protocol requires familiarity with some common EVM design patterns.

- ERC-20 approvals
- Dutch auction architecture in an EVM context
- Oracle usage and common pitfalls

## Project Overview

The protocol consists of several logical components that interact to implement automated auctioning.

### FeeAggregator
*Note: This contract is not in scope for the Code4rena audit.*

The FeeAggregator contract accumulates assets belonging to the protocol. It acts as the primary treasury holding contract for tokens awaiting liquidation. Assets may arrive through direct transfers, internal accounting systems, or cross-chain bridging. The contract exposes a privileged function allowing authorized swappers to move assets out of the aggregator for settlement.

### BaseAuction

The BaseAuction contract implements the protocol’s core auction engine. It maintains an allowlist for assets and handles auction lifecycles. Each auction sells a specific token (assetIn) in exchange for a designated settlement token (assetOut). Auctions follow a time-decaying price curve, allowing participants to purchase assets at decreasing prices until the inventory is exhausted or the auction duration expires.

### WorkflowRouter

The WorkflowRouter acts as the protocol’s automation ingress point. External automation systems submit reports to this contract, and the input is then routed to the appropriate subsystem. The router itself does not hold any funds but controls access to functions that may move funds. Access to the router requires the privileged forwarder role.

### PriceManager

The PriceManager contract maintains price information used by the auction system. It ingests Data Streams payloads and validates feed allowlisting but the actual cryptographic verification of the submitted reports is delegated to an external contract which is not in scope. 

### AuctionBidder

The AuctionBidder contract is an optional solver helper that participates in auctions programmatically. It allows the protocol or an external solver to:

- Execute a bid
- Perform custom logic during the callback
- Source the settlement asset required for payment

### Asset Flow

The lifecycle of assets in the protocol can be summarized as follows:

1. Revenue tokens are accumulated in FeeAggregator
2. Auctions are triggered automatically for eligible assets
3. Auction tokens move from FeeAggregator to the auction contract
4. Bidders purchase assets using the settlement token assetOut
5. After settlement, tokens are transferred to the designated receiver

## Security Considerations

The following issue classes are particularly relevant when auditing this system. Importantly, note that the roles assigned to automation infrastructure are considered trusted.

### Asset custody and transfer privileges

The Auction contract is able to pull tokens from the FeeAggregator in order to start auctions. It's also responsible for handling payouts to auction bidders and transferring the settlement token assetOut to the designated receiver address. Security of this contract is critical because it not only holds a privileged role in the FeeAggregator but also acts as escrow for asset flow during auctions. Flaws in logic here could lead to a severe loss of funds for the protocol.

### Auction economic correctness

The auction system relies on price data and configuration parameters to enforce fair trading conditions. This includes fresh oracle data from price feeds and intended behavior of the auction mechanism. It's important to verify that bid calculations use correct decimals and price functions behave as intended.

### Callback execution risks

Bid settlement allows optional execution of arbitrary logic through callbacks. This introduces potential risks such as reentrancy and misuse of token approval. The auction contract must enforce that callbacks cannot violate protocol invariants.
