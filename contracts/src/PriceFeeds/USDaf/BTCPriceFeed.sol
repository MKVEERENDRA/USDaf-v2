// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./../CompositePriceFeed.sol";

contract BTCPriceFeed is CompositePriceFeed {

    Oracle public btcUsdOracle;

    uint256 public constant DEVIATION_THRESHOLD = 2e16; // 2%
    uint256 private constant _CL_BTC_USD_HEARTBEAT = 24 hours;
    AggregatorV3Interface public constant CL_BTC_USD_PRICE_FEED = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

    constructor(
// @audit-low Inconsistent Naming (ethUsdOracle) Can Lead to Misunderstanding

        address _ethUsdOracleAddress, // actually WBTC/cbBTC/tBTC --> USD oracle
        uint256 _ethUsdStalenessThreshold, // staleness threshold for ^^
        address _borrowerOperationsAddress
    )
        CompositePriceFeed(_ethUsdOracleAddress, address(0), _ethUsdStalenessThreshold, _borrowerOperationsAddress)
    {

        btcUsdOracle = Oracle({
            aggregator: CL_BTC_USD_PRICE_FEED,
            stalenessThreshold: _CL_BTC_USD_HEARTBEAT,
            decimals: CL_BTC_USD_PRICE_FEED.decimals()
        });

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 ethUsdPrice, bool ethUsdOracleDown) = _getOracleAnswer(ethUsdOracle); // actually our wbtc/cbbtc/tbtc price
        (uint256 realEthUsdPrice, bool exchangeRateIsDown) = _getCanonicalRate(); // actually cl's btc/usd price

        if (ethUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        }

        // if btc/usd cl is down, just ignore it
        // @audit-info Oracle Fallback — If BTC/USD Chainlink is down, fallback to ethUsdOracle without marking fail.


        if (exchangeRateIsDown) {
            lastGoodPrice = ethUsdPrice;
            return (ethUsdPrice, ethUsdOracleDown);
        }

        uint256 rEthUsdPrice;

        // If it's a redemption and canonical is within 2% of market, use the max to mitigate unwanted redemption oracle arb
        // @audit-low Assumption: Chainlink BTC/USD price is more trustworthy than on-chain price only during redemption.
        // In non-redemption cases, upward manipulation risk is mitigated by choosing the lower value. Could be overly conservative.
        if (
            _isRedemption
                && _withinDeviationThreshold(ethUsdPrice, realEthUsdPrice, DEVIATION_THRESHOLD)
        ) {
            rEthUsdPrice = LiquityMath._max(ethUsdPrice, realEthUsdPrice);
        } else {
            // @audit-medium Potential Price Suppression — Taking the min(ethUsd, realEth) may unfairly penalize depositors.
            // A manipulated Chainlink BTC/USD feed (or a slow update) could lower the effective price used, especially outside redemptions.
            // Take the minimum of (market, canonical) in order to mitigate against upward market price manipulation.
            // Assumes a deviation between market <> canonical of >2% represents a legitimate market price difference.
            rEthUsdPrice = LiquityMath._min(ethUsdPrice, realEthUsdPrice);
        }

        lastGoodPrice = rEthUsdPrice;

        return (rEthUsdPrice, false);
    }

    function _getCanonicalRate() internal view override returns (uint256, bool) {
        return _getOracleAnswer(btcUsdOracle);
    }
}
