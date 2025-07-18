// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./ZapperAsFuck.sol";

interface IWrapper {
    function depositFor(address account, uint256 amount) external returns (bool);
    function withdrawTo(address account, uint256 amount) external returns (bool);
}

contract WbtcZapper is ZapperAsFuck {
    using SafeERC20 for IERC20;

    uint256 private constant _DECIMALS_DIFF = 10;

    IERC20 private constant _WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    constructor(IAddressesRegistry _addressesRegistry) ZapperAsFuck(_addressesRegistry) {
        // Approve unwrapped coll (WBTC) to coll (WWBTC)
        _WBTC.approve(address(collToken), type(uint256).max);
    }

    function _pullColl(uint256 _amount) internal override {
        uint256 collAmountInStrangeDecimals = _amount / 10 ** _DECIMALS_DIFF;
        require(collAmountInStrangeDecimals * 10 ** _DECIMALS_DIFF == _amount, "!precision");
        // @audit-low Precision check is good, but may revert in many legit edge cases (e.g., _amount = 1e17)

        _WBTC.safeTransferFrom(msg.sender, address(this), collAmountInStrangeDecimals);
        IWrapper(collToken).depositFor(address(this), collAmountInStrangeDecimals);
        // @audit-medium Return value of `depositFor` is ignored. If it returns false, funds may be stuck. Consider checking return value.

    }

    function _sendColl(address _receiver, uint256 _amount) internal override {
        IWrapper(collToken).withdrawTo(_receiver, _amount);
        // @audit-medium Same as above: `withdrawTo` return value is ignored. Check to confirm success.

    }
}
