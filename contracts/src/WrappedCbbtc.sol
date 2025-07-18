// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract WrappedCbbtc is ERC20Wrapper {
    using SafeERC20 for IERC20;

    uint256 private constant _DECIMALS_DIFF = 10;
    address private constant _CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    constructor() ERC20Wrapper(IERC20(_CBBTC)) ERC20("Wrapped cbBTC", "cbBTC18") {
        require(IERC20Metadata(_CBBTC).decimals() == 8, "!DECIMALS");
    }

    /**
     * @dev See {ERC20-decimals}.
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {ERC20Wrapper-depositFor}.
     */
    function depositFor(address account, uint256 amount) public override returns (bool) {
        address sender = _msgSender();
        require(sender != address(this), "ERC20Wrapper: wrapper can't deposit");
     underlying().safeTransferFrom(sender, address(this), amount);
        // @audit-medium No slippage check — assumes full amount was received; may be unsafe for fee-on-transfer tokens

        uint256 amountInDecimals = amount * 10 ** _DECIMALS_DIFF;
        // @audit-medium Risk of overflow if `amount` is large; consider using `SafeMath` or checked math in future upgrades

        _mint(account, amountInDecimals);
        return true;
    }

    /**
     * @dev See {ERC20Wrapper-withdrawTo}.
     */
    function withdrawTo(address account, uint256 amount) public override returns (bool) {
        _burn(_msgSender(), amount);
        uint256 amountInDecimals = amount / 10 ** _DECIMALS_DIFF;
        // @audit-low Possible precision loss due to truncation (division flooring)

        underlying().safeTransfer(account, amountInDecimals);
        // @audit-low Same risk as in deposit — assumes transfer succeeded with full value

        return true;
    }
}
