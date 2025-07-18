// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseFallbackOracle} from "./BaseFallbackOracle.sol";

contract TbtcFallbackOracle is BaseFallbackOracle {
 // @audit-low: Hardcoded aggregator address makes the contract less flexible and harder to reuse or test in other environments.
    // @recommendation: Consider passing the aggregator address via constructor parameters for better configurability.
    address private constant _TBTC_USD_AGG = 0xbeF434E2aCF0FBaD1f0579d2376fED0d1CfC4217;
    // @audit-low: No validation that the aggregator address is a valid contract implementing the ICurvePriceAggregator interface.
        // @recommendation: Add a sanity check using `require(_CRVUSD_USD_AGG.code.length > 0)` or try/catch validation.
    constructor() BaseFallbackOracle("tBTC / USD", _TBTC_USD_AGG) {}
}
