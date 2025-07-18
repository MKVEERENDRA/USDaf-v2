// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseFallbackOracle} from "./BaseFallbackOracle.sol";

contract TbtcFallbackOracle is BaseFallbackOracle {
 // @audit-low: Hardcoded aggregator address reduces flexibility and hinders testing or reuse across environments.
    // @recommendation: Accept the aggregator address as a constructor argument to make the contract more configurable.
    address private constant _TBTC_USD_AGG = 0xbeF434E2aCF0FBaD1f0579d2376fED0d1CfC4217;
       // @audit-low: No validation that `_TBTC_USD_AGG` is a valid contract or implements the expected interface.
        // @recommendation: Add runtime check like `require(_TBTC_USD_AGG.code.length > 0, "Invalid aggregator address");`
    constructor() BaseFallbackOracle("tBTC / USD", _TBTC_USD_AGG) {}
}
