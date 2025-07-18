// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface, BaseOracle} from "./BaseOracle.sol";

contract SusdeOracle is BaseOracle {
   // @audit-info Constant heartbeat is set but never validated in this contract.
    // This might be used by the parent `BaseOracle` to check staleness.
    uint256 private constant _CL_SUSDE_USD_HEARTBEAT = _24_HOURS;
  // @audit-high No fallback oracle is used here. If Chainlink fails, this will break.
    // @recommendation Consider implementing a fallback oracle mechanism or graceful error fallback.
    AggregatorV3Interface public constant CL_SUSDE_USD_PRICE_FEED = AggregatorV3Interface(0xFF3BC18cCBd5999CE63E788A1c250a88626aD099);

    constructor() BaseOracle("sUSDe / USD") {}

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
  // @audit-low No validation of returned answer (e.g., negative prices, outdated timestamp).
        // @recommendation Validate `answer > 0` and `updatedAt` within heartbeat to prevent stale or invalid prices.
        (roundId, answer, startedAt, updatedAt, answeredInRound) = CL_SUSDE_USD_PRICE_FEED.latestRoundData();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
