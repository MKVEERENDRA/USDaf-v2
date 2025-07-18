// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseFallbackOracle} from "./BaseFallbackOracle.sol";

contract WbtcFallbackOracle is BaseFallbackOracle {
   // @audit-low: Hardcoded aggregator address limits deployment flexibility and makes upgrades harder.
    // @recommendation: Allow the aggregator address to be passed in via the constructor for easier configuration and testing.
    address private constant _WBTC_USD_AGG = 0xBe83fD842DB4937C0C3d15B2aBA6AF7E854f8dcb;
 // @audit-low: No runtime check to ensure _WBTC_USD_AGG is a deployed contract and implements the expected interface (e.g., ICurvePriceAggregator).
        // @recommendation: Add validation like `require(_WBTC_USD_AGG.code.length > 0, "Invalid aggregator");`
    constructor() BaseFallbackOracle("WBTC / USD", _WBTC_USD_AGG) {}
}
