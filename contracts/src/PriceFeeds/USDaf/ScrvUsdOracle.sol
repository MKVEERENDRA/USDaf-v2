// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Oracle} from "./ERC4626Oracle.sol";

contract ScrvUsdOracle is ERC4626Oracle {

    // @audit-info: Heartbeat is set to 24 hours. Acceptable if the price feed updates infrequently (e.g., low-volatility stablecoin).
    // @recommendation: Document reasoning for this value. Consider making it configurable if future tokens differ in update frequency.
    uint256 private constant _CL_CRVUSD_USD_HEARTBEAT = _24_HOURS;

    // @audit-low: Hardcoded Chainlink price feed reduces flexibility and reusability.
    // @recommendation: Pass feed address via constructor if reuse or test deployment is expected.
    address private constant _CL_CRVUSD_USD_PRICE_FEED = 0xEEf0C605546958c1f899b6fB336C20671f9cD49F;

    // @audit-low: Hardcoded vault address (scrvUSD). Limits reuse and testing across networks.
    // @recommendation: Consider parameterizing the token address or using a factory to deploy variants.
    address private constant _SCRVUSD = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367;

    constructor(address _fallback)
        // @audit-low: No validation on `_fallback` (e.g., is it a contract, is fallback logic safe).
        // @recommendation: Add runtime check: `require(_fallback.code.length > 0, "Invalid fallback");`
        ERC4626Oracle(
            "scrvUSD / USD", // description
            _CL_CRVUSD_USD_HEARTBEAT,
            _SCRVUSD,
            _CL_CRVUSD_USD_PRICE_FEED,
            _fallback
        ) {}
}
