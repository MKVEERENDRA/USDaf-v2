// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "../../Dependencies/AggregatorV3Interface.sol";

abstract contract BaseOracle is AggregatorV3Interface {

    string public description;
 // @audit-low - Constants are defined but not used within this contract.
    // `_WAD`, `_24_HOURS`, and `_1_HOUR` may indicate dead code unless used in child contracts.
    // Recommend: remove or ensure they are utilized in extended contracts.

    uint256 internal constant _WAD = 1e18;
    uint256 internal constant _24_HOURS = 86400 * 2; // actually 48 hours
    uint256 internal constant _1_HOUR = 3600 * 24; // actually 24 hours

    constructor(string memory _description) {
        description = _description;
    }

    function decimals() public pure virtual returns (uint8) {
        return 8;
    }

    function latestRoundData()
        external
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {}

    function _isStale(
        int256 answer,
        uint256 updatedAt,
        uint256 heartbeat
    ) internal view virtual returns (bool) {
        bool stale = updatedAt + heartbeat <= block.timestamp;
  // @audit-low - The staleness check uses `<= block.timestamp` which can be slightly inaccurate if the clock is skewed.
        // Not a major issue, but in high-precision systems, rounding errors could matter.

        // @audit-low - The condition `answer <= 0` might be overstrict for assets that can be priced near 0 due to volatility or error.
        // Recommend: allow tighter bounds to be configurable by governance if this is used for diverse asset types.
        return stale || answer <= 0;
    }
}
