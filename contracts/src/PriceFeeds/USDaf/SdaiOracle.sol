// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Oracle} from "./ERC4626Oracle.sol";

contract SdaiOracle is ERC4626Oracle {

    uint256 private constant _CL_DAI_USD_HEARTBEAT = _1_HOUR;

    // @audit-info: This Chainlink DAI/USD aggregator is used as the primary price feed.
    // @audit-recommendation: Ensure the feed address is up-to-date and listed on Chainlink's official registry.
    address private constant _CL_DAI_USD_PRICE_FEED = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

    // @audit-info: sDAI token address (ERC4626 wrapper for DAI yield via Maker DSR).
    // @audit-recommendation: Ensure this token remains upgrade-free and immutable as expected for oracle usage.
    address private constant _SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    constructor()
        ERC4626Oracle(
            "sDAI / USD", // description

            // @audit-low: Heartbeat of 1 hour may allow stale prices to be considered valid.
            // @recommendation: Consider lowering to 15–30 minutes if tighter price freshness is required.
            _CL_DAI_USD_HEARTBEAT,

            _SDAI, // token

            // @audit-info: This is the Chainlink DAI/USD price feed used as the primary oracle.
            _CL_DAI_USD_PRICE_FEED,

            // @audit-low: No fallback oracle is configured.
            // @recommendation: Consider adding a backup feed (e.g., Maker Oracle or custom TWAP) to maintain redundancy.
            address(0)
        ) {}
}
