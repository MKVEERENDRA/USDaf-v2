// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseFallbackOracle} from "./BaseFallbackOracle.sol";

contract CrvUsdFallbackOracle is BaseFallbackOracle {
    // @audit-low: Hardcoded aggregator address makes the contract less flexible and harder to reuse or test in other environments.
    // @recommendation: Consider passing the aggregator address via constructor parameters for better configurability.
    address private constant _CRVUSD_USD_AGG = 0x18672b1b0c623a30089A280Ed9256379fb0E4E62;
  // @audit-low: No validation that the aggregator address is a valid contract implementing the ICurvePriceAggregator interface.
        // @recommendation: Add a sanity check using `require(_CRVUSD_USD_AGG.code.length > 0)` or try/catch validation.
    constructor() BaseFallbackOracle("crvUSD / USD", _CRVUSD_USD_AGG) {}
}
