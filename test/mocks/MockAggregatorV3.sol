// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title This contracts is used to mock the Chainlink AggregatorV3 contract and allow transmitting
/// new answers
contract MockAggregatorV3 is AggregatorV3Interface {
  int256 private s_latestAnswer;
  uint256 private s_updatedAt;

  function transmit(
    int256 _answer
  ) external {
    s_latestAnswer = _answer;
    s_updatedAt = block.timestamp;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "MockAggregatorV3";
  }

  function version() external pure returns (uint256) {
    return 3;
  }

  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (_roundId, s_latestAnswer, s_updatedAt, s_updatedAt, uint80(0));
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), s_latestAnswer, s_updatedAt, s_updatedAt, uint80(0));
  }

  function test_mockAggregatorV3Test() public {}
}
