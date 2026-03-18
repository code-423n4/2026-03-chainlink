// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IGPV2Settlement} from "src/interfaces/IGPV2Settlement.sol";

import {BasePriceManagerForkTest} from "test/fork/price-manager/BasePriceManagerForkTest.t.sol";

import {GPv2Authentication} from "@cowprotocol/interfaces/GPv2Authentication.sol";
import {IERC20} from "@cowprotocol/interfaces/IERC20.sol";
import {GPv2Interaction} from "@cowprotocol/libraries/GPv2Interaction.sol";
import {GPv2Order} from "@cowprotocol/libraries/GPv2Order.sol";
import {GPv2Trade} from "@cowprotocol/libraries/GPv2Trade.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

contract BaseGPV2CompatibleAuctionForkTest is BasePriceManagerForkTest {
  uint256 internal constant USDC_AMOUNT = 100_000e6;
  uint256 internal constant WETH_AMOUNT = 10e18;

  address internal immutable i_solver = makeAddr("solver");
  GPv2Authentication internal immutable i_gpv2Authentication = GPv2Authentication(GP_V2_ALLOWLIST_AUTHENTICATION);
  IGPV2Settlement internal immutable i_gpv2Settlement = IGPV2Settlement(GP_V2_SETTLEMENT);

  IERC20[] internal s_tokens;
  uint256[] internal s_clearingPrices;
  GPv2Trade.Data[] internal s_trades;
  GPv2Interaction.Data[][3] internal s_interactions;
  GPv2Order.Data internal s_usdcOrder;
  uint256 internal s_minBuyAmount;

  constructor() {
    // We warp back to avoid price staleness issues. This way the prices with a future timestamp are transmitted
    // successfully and once we skip to bring the auction price down, the prices are still fresh.
    vm.warp(block.timestamp - s_auction.getAssetParams(USDC).auctionDuration);

    deal(USDC, address(s_feeAggregator), USDC_AMOUNT);
    deal(WETH, address(s_feeAggregator), WETH_AMOUNT);

    _changePrank(i_forwarder);

    // 1. Transmit prices
    s_workflowRouter.onReport(
      abi.encodePacked(PRICE_ADMIN_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.transmit.selector, s_unverifiedReports))
    );

    // 2. Start auctions
    (, bytes memory performData) = s_auction.checkUpkeep("");
    s_workflowRouter.onReport(
      abi.encodePacked(AUCTION_WORKER_WORKFLOW_ID, bytes10(0), bytes20(0)),
      abi.encode(address(s_auction), abi.encodeWithSelector(s_auction.performUpkeep.selector, performData))
    );

    // 3.Skip to end of auctions
    skip(s_auction.getAssetParams(USDC).auctionDuration);

    // 4. Allowlist solver onto the CowProtocol authentication contract
    address manager = i_gpv2Authentication.manager();
    _changePrank(manager);
    i_gpv2Authentication.addSolver(i_solver);

    // 5. Build settle args
    // Get the minimum buy amount from the auction
    s_minBuyAmount = s_auction.getAssetOutAmount(USDC, USDC_AMOUNT, block.timestamp);

    // Create the GPv2Order.Data struct
    s_usdcOrder = GPv2Order.Data({
      sellToken: IERC20(USDC),
      buyToken: IERC20(LINK),
      receiver: address(s_auction),
      sellAmount: USDC_AMOUNT,
      buyAmount: s_minBuyAmount,
      validTo: uint32(block.timestamp + 1 hours),
      appData: bytes32(0),
      feeAmount: 0,
      kind: GPv2Order.KIND_SELL,
      partiallyFillable: true,
      sellTokenBalance: GPv2Order.BALANCE_ERC20,
      buyTokenBalance: GPv2Order.BALANCE_ERC20
    });

    s_trades.push(
      GPv2Trade.Data({
        sellTokenIndex: 0,
        buyTokenIndex: 1,
        receiver: address(s_auction),
        sellAmount: USDC_AMOUNT,
        buyAmount: s_minBuyAmount,
        validTo: s_usdcOrder.validTo,
        appData: bytes32(0),
        feeAmount: 0,
        flags: 0x42, // EIP-1271 (0x40) | partially fillable (0x02)
        executedAmount: USDC_AMOUNT,
        // For EIP-1271, CoW expects `trade.signature` to be tightly packed as:
        //   abi.encodePacked(owner, signatureBytes)
        // where `owner` is the contract that implements IERC1271 (the auction),
        // and `signatureBytes` is forwarded as-is to IERC1271.isValidSignature.
        signature: abi.encodePacked(address(s_auction), abi.encode(s_usdcOrder))
      })
    );

    // Build the tokens array
    s_tokens.push(IERC20(USDC));
    s_tokens.push(IERC20(LINK));

    // Build the clearing prices array to make the clearing price exactly match the order's limit:
    //   minBuyAmount == USDC_AMOUNT * price[USDC] / price[LINK]
    // => price[LINK] = USDC_AMOUNT * price[USDC] / minBuyAmount
    s_clearingPrices.push(1e18); // arbitrary scale for USDC
    s_clearingPrices.push(USDC_AMOUNT * s_clearingPrices[0] / s_minBuyAmount);

    // The settlement flow is:
    // 1. Settlement calls vaultRelayer.transferFromAccounts() which transfers USDC
    //    from auction contract to settlement contract (USDC is now in settlement contract)
    // 2. Post-interactions execute: Approve Uniswap and swap USDC to LINK
    //    (USDC is in settlement contract, so we can approve and swap directly)
    // 3. Settlement transfers LINK from settlement contract to receiver
    bytes memory swapPath =
      bytes.concat(bytes20(USDC), bytes3(uint24(3000)), bytes20(WETH), bytes3(uint24(3000)), bytes20(LINK));

    // First, approve Uniswap Router to spend USDC from the settlement contract
    // Use hardcoded selector for approve(address,uint256) = 0x095ea7b3
    s_interactions[1].push(
      GPv2Interaction.Data({
        target: USDC, value: 0, callData: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_ROUTER, USDC_AMOUNT)
      })
    );

    // Then, swap USDC to LINK and send LINK to the settlement contract
    s_interactions[1].push(
      GPv2Interaction.Data({
        target: UNISWAP_ROUTER,
        value: 0,
        callData: abi.encodeWithSelector(
          IV3SwapRouter.exactInput.selector,
          IV3SwapRouter.ExactInputParams({
            path: swapPath, recipient: address(i_gpv2Settlement), amountIn: USDC_AMOUNT, amountOutMinimum: 0
          })
        )
      })
    );

    vm.label(i_solver, "Solver");
    vm.label(address(i_gpv2Settlement), "GPv2Settlement");
    vm.label(address(i_gpv2Authentication), "GPv2Authentication");
  }
}
