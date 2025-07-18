// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {AggregatorV3Interface, BaseOracle} from "./BaseOracle.sol";

abstract contract ERC4626Oracle is BaseOracle {

    uint256 public immutable PRIMARY_ORACLE_HEARTBEAT;

    AggregatorV3Interface public immutable FALLBACK_ORACLE;
    AggregatorV3Interface public immutable PRIMARY_ORACLE;

    IERC4626 public immutable TOKEN;

    constructor(string memory _description, uint256 _heartbeat, address _token, address _primary, address _fallback)
        BaseOracle(_description) {
            PRIMARY_ORACLE_HEARTBEAT = _heartbeat;
            TOKEN = IERC4626(_token);

            if (_primary != address(0)) {
                PRIMARY_ORACLE = AggregatorV3Interface(_primary);
                require(PRIMARY_ORACLE.decimals() == 8, "!primary");
            }

            if (_fallback != address(0)) {
                FALLBACK_ORACLE = AggregatorV3Interface(_fallback);
                require(FALLBACK_ORACLE.decimals() == 8, "!fallback");
            }
    }

    // assuming PRIMARY_ORACLE will never revert. If it does, the branch will be shut down
    function latestRoundData()
        external
        view
        virtual
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = PRIMARY_ORACLE.latestRoundData();
  // @audit-medium: No try-catch around primary oracle call
        // If PRIMARY_ORACLE is misbehaving or paused, this will hard-revert the entire function call.
        // Recommendation: Use a try-catch block or low-level call to handle oracle unavailability gracefully.
        // If the oracle reverts unexpectedly, it will bring down the entire system.
        // Note: The comment above says this is an acceptable tradeoff ("branch will be shut down"), but this still may
        // deserve mitigation in a production environment.       
if (_isStale(answer, updatedAt, PRIMARY_ORACLE_HEARTBEAT) && address(FALLBACK_ORACLE) != address(0)) {
            (roundId, answer, startedAt, updatedAt, answeredInRound) = FALLBACK_ORACLE.latestRoundData();
        }
        // @audit-high: Assumes TOKEN has 18 decimals without enforcing it
        // This can lead to mispricing of shares if TOKEN uses non-standard decimals.
        // Recommendation: Add an explicit check (e.g. require TOKEN.decimals() == 18) or make the conversion logic dynamic based on TOKEN.decimals().
        // assumes that `TOKEN` has 18 decimals
        answer = answer * int256(TOKEN.convertToAssets(_WAD)) / int256(_WAD);
  // @audit-info: Assumes convertToAssets() will never revert
        // If TOKEN is misconfigured, this could revert or return a misleading value.
        // Recommendation: Consider guarding or validating TOKEN behavior in constructor.
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
