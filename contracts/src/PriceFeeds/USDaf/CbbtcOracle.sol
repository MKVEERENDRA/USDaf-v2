// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface, BaseOracle} from "./BaseOracle.sol";

contract CbbtcOracle is BaseOracle {

    AggregatorV3Interface public immutable FALLBACK_ORACLE;

  
    // @audit-info: Heartbeat is set to 48 hours (2 days)
    // @audit-low: Long heartbeat makes the oracle tolerant to stale data. Consider whether 48h is appropriate based on asset volatility.
    uint256 private constant _CL_CBBTC_USD_HEARTBEAT = _24_HOURS;

    // @audit-info: Hardcoded Chainlink feed
    // @audit-low: Hardcoded oracle address can be deprecated or manipulated if Chainlink rotates feeds.
    //             Consider making this upgradable or at least emit an event if feed is stale too long.
    AggregatorV3Interface public constant CL_CBBTC_USD_PRICE_FEED = AggregatorV3Interface(0x2665701293fCbEB223D11A08D826563EDcCE423A);

    constructor(address _fallback) BaseOracle("cbBTC / USD") {
        FALLBACK_ORACLE = AggregatorV3Interface(_fallback);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = CL_CBBTC_USD_PRICE_FEED.latestRoundData();

        // @audit-info: Checks for staleness before using fallback
        // @audit-low: No logging when falling back — difficult to detect failover on-chain
        // @audit-suggestion: Emit an event when fallback is used to help monitoring and debugging.
        if (_isStale(answer, updatedAt, _CL_CBBTC_USD_HEARTBEAT) && address(FALLBACK_ORACLE) != address(0)) {
            (roundId, answer, startedAt, updatedAt, answeredInRound) = FALLBACK_ORACLE.latestRoundData();
 // @audit-medium: No check whether fallback data is *also* stale or invalid.
            // @impact: Fallback may silently return stale/invalid data too.
            // @mitigation: Add `_isStale` check to fallback oracle response as well.
        }
  // @audit-low: Function is marked `view` but calls external contracts.
        //             If external oracle reverts, it bubbles up — no try/catch fallback.
        // @impact: If both oracles revert, this function will revert and dependent contracts may break.
        // @mitigation: Use try/catch for more graceful failure, or return sentinel value like `0`.
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
