// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Oracle} from "./ERC4626Oracle.sol";

contract SfrxUsdOracle is ERC4626Oracle {

    // @audit-info: Sets the acceptable delay for Chainlink price feed updates to 24 hours.
    // @audit-low: A 24-hour heartbeat might be too lenient for time-sensitive pricing. Price feed can remain stale for a full day before fallback triggers.
    // @recommendation: Consider reducing heartbeat to 1-6 hours depending on sfrxUSD volatility and liquidity needs.
    uint256 private constant _CL_SFRXUSD_USD_HEARTBEAT = _24_HOURS;

    // @audit-info: Chainlink feed address for sfrxUSD/USD.
    // @audit-medium: If Chainlink feed is deprecated or replaced, price will silently become unreliable unless fallback is triggered.
    // @recommendation: Add a method to update this feed address via governance or deploy upgradeable proxy pattern.
    address private constant _CL_SFRXUSD_USD_PRICE_FEED = 0x9B4a96210bc8D9D55b1908B465D8B0de68B7fF83;

    // @audit-info: sfrxUSD vault token address.
    // @audit-ok: Correctly hardcoded.
    address private constant _SFRXUSD = 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6;

    constructor()
        ERC4626Oracle(
            "sfrxUSD / USD",           // description
            _CL_SFRXUSD_USD_HEARTBEAT, // heartbeat
            _SFRXUSD,                  // token
            _CL_SFRXUSD_USD_PRICE_FEED,// primary Chainlink feed
            address(0)                 // @audit-high: No fallback oracle provided. If Chainlink fails or returns stale data, pricing will fail.
                                       // @recommendation: Provide a reliable on-chain fallback (e.g. DEX TWAP or other feed) to ensure redundancy.
        ) {}
}
