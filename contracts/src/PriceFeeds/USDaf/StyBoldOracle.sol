// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Oracle, IERC4626} from "./ERC4626Oracle.sol";

contract StyBoldOracle is ERC4626Oracle {

    address private constant _STAKED_YEARN_BOLD = 0x23346B04a7f55b8760E5860AA5A77383D63491cD; // st-yBOLD

    IERC4626 public immutable NON_STAKED_TOKEN; // yBOLD

    constructor()
        ERC4626Oracle(
            "st-yBOLD / USD",   // description
            uint256(0),         // @audit-high: Heartbeat is set to 0 — disables staleness checks completely.
                                // @impact: If fallback is later added, this disables auto-switching on stale data.
                                // @recommendation: Set a non-zero heartbeat to detect stale prices if feed added later.
            _STAKED_YEARN_BOLD, // token
            address(0),         // @audit-high: No primary price feed — price is computed only via internal logic.
                                // @impact: Entire price logic is dependent on convertToAssets() for both vaults.
                                // @recommendation: Consider adding Chainlink BOLD/USD feed or backup oracle.
            address(0)          // @audit-high: No fallback price feed configured.
                                // @recommendation: Add a TWAP oracle, DEX price, or admin-set fallback in case convert logic fails.
        ) {
            // @audit-ok: Non-staked yBOLD vault is stored for price composition.
            NON_STAKED_TOKEN = IERC4626(TOKEN.asset());
        }

    /// @notice Computes st-yBOLD price using nested convertToAssets() calls.
    /// @audit-medium: Assumes both ERC4626 vaults (st-yBOLD and yBOLD) are solvent and correctly reporting conversion ratios.
    /// @risk: If either vault manipulates or misreports `convertToAssets()`, this oracle returns an invalid price.
    /// @recommendation: Add sanity checks, oracles, or vault validation logic to mitigate trust assumptions.
    /// @audit-info: Returns USD value of 1e18 st-yBOLD tokens in terms of underlying USD-backed asset.
    function latestRoundData()
        external
        view
        virtual
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            0,
            int256(NON_STAKED_TOKEN.convertToAssets(TOKEN.convertToAssets(10 ** decimals()))),
            0,
            block.timestamp,
            0
        );
    }
}
