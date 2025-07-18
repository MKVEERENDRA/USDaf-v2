// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseFallbackOracle} from "./BaseFallbackOracle.sol";

contract CbbtcFallbackOracle is BaseFallbackOracle {
    // @audit-low: Hardcoded aggregator address reduces flexibility for reuse/testing. Use constructor arg if configurability is needed.

    address private constant _CBBTC_USD_AGG = 0x4710A77a0E0f4c7b0E11CDeB74acB042e62B8d22;
// @audit-low: No validation that the aggregator address is a valid contract implementing ICurvePriceAggregator.
        // @recommendation: Consider checking that _CBBTC_USD_AGG.code.length > 0 or validating interface compliance via try/catch.
    constructor() BaseFallbackOracle("cbBTC / USD", _CBBTC_USD_AGG) {}
}
