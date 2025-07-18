// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable, Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {AggregatorV3Interface, BaseOracle} from "../BaseOracle.sol";

interface ICurvePriceAggregator {
    function price() external view returns (uint256);
}

abstract contract BaseFallbackOracle is BaseOracle, Ownable2Step {

    bool public useFallback;

    uint256 internal constant _PRECISION_DIFF = 1e10;

    ICurvePriceAggregator public immutable AGG;
// @audit-info
// Purpose: This flag lets the oracle be turned off permanently by the owner.
// This avoids returning potentially stale or manipulated prices later in time.
// No issue, but track usage and risk tolerance of disabling it.


    address private constant _OWNER = 0xce352181C0f0350F1687e1a44c45BC9D96ee738B;
// @audit-low
// Hardcoding the owner address reduces flexibility.
// If address rotation is ever needed (e.g., due to key compromise), upgrade is needed.
// ✅ Recommendation: Consider passing `_OWNER` as a constructor argument for flexibility.


    constructor(string memory _description, address _agg) BaseOracle(_description) {
        _transferOwnership(_OWNER);
        useFallback = true;
        AGG = ICurvePriceAggregator(_agg);
    }
// @audit-info
// Only the owner can disable fallback; once disabled, the oracle returns zero price.
// This is intentional but could cause issues for consumers relying on a live fallback.
// ✅ Suggestion: Consider emitting an event to signal fallback has been disabled.


    function latestRoundData()
        public
        view
        virtual
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        if (!useFallback) return (0, 0, 0, 0, 0);
        return (0, int256(AGG.price() / _PRECISION_DIFF), 0, block.timestamp, 0);
    }

// @audit-medium
// The `AGG.price()` call is assumed to be trustworthy, but no checks are made.
// If AGG misbehaves (e.g., returns 0 or extreme values), it can silently affect the system.
// ✅ Recommendation: Add sanity bounds (e.g., min/max price check) or emit warnings if outside expected range.

// @audit-low
// Returning 0s for roundId, startedAt, and answeredInRound is not standard Chainlink oracle format.
// ✅ Recommendation: Return meaningful values or document consumers should not rely on those fields.

// @audit-info
// Precision scaling is done via `_PRECISION_DIFF = 1e10`.
// Assumes AGG returns 1e28-based price which gets scaled down to 1e18.
// ✅ Suggestion: Add comments or constants explaining what format AGG returns.
    function disableFallback() external onlyOwner {
        useFallback = false;
    }
}
