// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface, BaseOracle} from "./BaseOracle.sol";

contract WbtcOracle is BaseOracle {

    AggregatorV3Interface public immutable FALLBACK_ORACLE;

    uint256 private constant _CL_WBTC_BTC_HEARTBEAT = _24_HOURS;
    uint256 private constant _CL_BTC_USD_HEARTBEAT = _1_HOUR;

    AggregatorV3Interface public constant CL_WBTC_BTC_PRICE_FEED = AggregatorV3Interface(0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23);
    AggregatorV3Interface public constant CL_BTC_USD_PRICE_FEED = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

    constructor(address _fallback) BaseOracle("WBTC / USD") {
        FALLBACK_ORACLE = AggregatorV3Interface(_fallback);
        // @audit-low Consider validating _fallback is a contract to avoid silent failure in fallback use.    
}

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = getChainlinkPrice();
        if (answer == 0 && address(FALLBACK_ORACLE) != address(0)) {
            // @audit-medium If Chainlink returns stale or zero data, fallback is used. Consider logging a warning event for transparency.

            (roundId, answer, startedAt, updatedAt, answeredInRound) = FALLBACK_ORACLE.latestRoundData();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getChainlinkPrice()
        public
        view
        returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 wbtcBtcRoundId,
            int256 wbtcBtcPrice,
            uint256 wbtcBtcStartedAt,
            uint256 wbtcBtcUpdatedAt,
            uint80 wbtcBtcAnsweredInRound
        ) = CL_WBTC_BTC_PRICE_FEED.latestRoundData();
        if (_isStale(wbtcBtcPrice, wbtcBtcUpdatedAt, _CL_WBTC_BTC_HEARTBEAT)) {
            // @audit-medium Stale WBTC/BTC price causes total price to be dropped to 0. Consider differentiating between stale and 0.

            return (0, 0, 0, 0, 0);
        }

        (
            uint80 btcUsdRoundId,
            int256 btcUsdPrice,
            uint256 btcUsdStartedAt,
            uint256 btcUsdUpdatedAt,
            uint80 btcUsdAnsweredInRound
        ) = CL_BTC_USD_PRICE_FEED.latestRoundData();
        if (_isStale(btcUsdPrice, btcUsdUpdatedAt, _CL_BTC_USD_HEARTBEAT)) {
            // @audit-medium Stale BTC/USD price causes the oracle to return 0. This could affect integrations relying on real-time pricing.

            return (0, 0, 0, 0, 0);
        }

        int256 wbtcUsdPrice = wbtcBtcPrice * btcUsdPrice / int256(1e8);
        // @audit-low Consider using SafeCast or additional overflow checks on multiplication/division for defense-in-depth.

        return
            wbtcBtcUpdatedAt < btcUsdUpdatedAt ?
                (wbtcBtcRoundId, wbtcUsdPrice, wbtcBtcStartedAt, wbtcBtcUpdatedAt, wbtcBtcAnsweredInRound) :
                (btcUsdRoundId, wbtcUsdPrice, btcUsdStartedAt, btcUsdUpdatedAt, btcUsdAnsweredInRound);
    }
}
