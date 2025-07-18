// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BaseZapper.sol";
import "../Dependencies/Constants.sol";

contract ZapperAsFuck is BaseZapper {
    using SafeERC20 for IERC20;

    address public immutable collToken;

    constructor(IAddressesRegistry _addressesRegistry)
        BaseZapper(_addressesRegistry, IFlashLoanProvider(address(0)), IExchange(address(0)))
    {
        collToken = address(_addressesRegistry.collToken());
        require(address(WETH) != address(collToken), "GCZ: Wrong coll branch");

        // Approve WETH to BorrowerOperations
        WETH.approve(address(borrowerOperations), type(uint256).max);
        // @audit-medium Approving `type(uint256).max` without revoke logic may allow griefing if `borrowerOperations` is compromised.

        // Approve coll to BorrowerOperations
        IERC20(address(collToken)).approve(address(borrowerOperations), type(uint256).max);
        // @audit-medium Same issue as above, especially for non-upgradable tokens — consider revoking on emergency.

    }

    function openTroveWithRawETH(OpenTroveParams calldata _params) external payable returns (uint256) {
        require(msg.value == ETH_GAS_COMPENSATION, "GCZ: Wrong ETH");
        // @audit-low Only allows exact compensation value. This is inflexible for future gas pricing changes.

        require(
            _params.batchManager == address(0) || _params.annualInterestRate == 0,
            "GCZ: Cannot choose interest if joining a batch"
        );
        // @audit-low No validation on `_params.collAmount` or `_params.boldAmount` — could result in failed open.


        // Convert ETH to WETH
        WETH.deposit{value: msg.value}();

        // Pull coll
        _pullColl(_params.collAmount);

        uint256 troveId;
        uint256 index = _getTroveIndex(_params.ownerIndex);
        if (_params.batchManager == address(0)) {
            troveId = borrowerOperations.openTrove(
                _params.owner,
                index,
                _params.collAmount,
                _params.boldAmount,
                _params.upperHint,
                _params.lowerHint,
                _params.annualInterestRate,
                _params.maxUpfrontFee,
                // Add this contract as add/receive manager to be able to fully adjust trove,
                // while keeping the same management functionality
                address(this), // add manager
                address(this), // remove manager
                address(this) // receiver for remove manager
            );
        } else {
            IBorrowerOperations.OpenTroveAndJoinInterestBatchManagerParams memory
                openTroveAndJoinInterestBatchManagerParams = IBorrowerOperations
                    .OpenTroveAndJoinInterestBatchManagerParams({
                    owner: _params.owner,
                    ownerIndex: index,
                    collAmount: _params.collAmount,
                    boldAmount: _params.boldAmount,
                    upperHint: _params.upperHint,
                    lowerHint: _params.lowerHint,
                    interestBatchManager: _params.batchManager,
                    maxUpfrontFee: _params.maxUpfrontFee,
                    // Add this contract as add/receive manager to be able to fully adjust trove,
                    // while keeping the same management functionality
                    addManager: address(this), // add manager
                    removeManager: address(this), // remove manager
                    receiver: address(this) // receiver for remove manager
                });
            troveId =
                borrowerOperations.openTroveAndJoinInterestBatchManager(openTroveAndJoinInterestBatchManagerParams);
        }

        boldToken.transfer(msg.sender, _params.boldAmount);
        // @audit-medium Assumes mint succeeded and enough Bold is present in contract. No check on `boldToken.balanceOf`.


        // Set add/remove managers
        _setAddManager(troveId, _params.addManager);
        _setRemoveManagerAndReceiver(troveId, _params.removeManager, _params.receiver);

        return troveId;
    }

    function addColl(uint256 _troveId, uint256 _amount) external {
        address owner = troveNFT.ownerOf(_troveId);
        _requireSenderIsOwnerOrAddManager(_troveId, owner);

        IBorrowerOperations borrowerOperationsCached = borrowerOperations;

        // Pull coll
        _pullColl(_amount);

        borrowerOperationsCached.addColl(_troveId, _amount);
    }

    function withdrawColl(uint256 _troveId, uint256 _amount) external {
        address owner = troveNFT.ownerOf(_troveId);
        address receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner);
        _requireZapperIsReceiver(_troveId);

        borrowerOperations.withdrawColl(_troveId, _amount);

        // Send coll left
        _sendColl(receiver, _amount);
    }

    function withdrawBold(uint256 _troveId, uint256 _boldAmount, uint256 _maxUpfrontFee) external {
        address owner = troveNFT.ownerOf(_troveId);
        address receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner);
        _requireZapperIsReceiver(_troveId);

        borrowerOperations.withdrawBold(_troveId, _boldAmount, _maxUpfrontFee);

        // Send Bold
        boldToken.transfer(receiver, _boldAmount);
        // @audit-low No error handling — transfer may fail on non-standard tokens.

    }

    function repayBold(uint256 _troveId, uint256 _boldAmount) external {
        address owner = troveNFT.ownerOf(_troveId);
        _requireSenderIsOwnerOrAddManager(_troveId, owner);

        // Set initial balances to make sure there are not lefovers
        InitialBalances memory initialBalances;
        _setInitialTokensAndBalances(IERC20(address(collToken)), boldToken, initialBalances);

        // Pull Bold
        boldToken.transferFrom(msg.sender, address(this), _boldAmount);

        borrowerOperations.repayBold(_troveId, _boldAmount);

        // return leftovers to user
        _returnLeftovers(initialBalances);
    }

    function adjustTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        uint256 _maxUpfrontFee
    ) external {
        InitialBalances memory initialBalances;
        address receiver =
            _adjustTrovePre(_troveId, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease, initialBalances);
        borrowerOperations.adjustTrove(
            _troveId, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease, _maxUpfrontFee
        );
        _adjustTrovePost(_collChange, _isCollIncrease, _boldChange, _isDebtIncrease, receiver, initialBalances);
    }

    function adjustZombieTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external {
        InitialBalances memory initialBalances;
        address receiver =
            _adjustTrovePre(_troveId, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease, initialBalances);
        borrowerOperations.adjustZombieTrove(
            _troveId, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease, _upperHint, _lowerHint, _maxUpfrontFee
        );
        _adjustTrovePost(_collChange, _isCollIncrease, _boldChange, _isDebtIncrease, receiver, initialBalances);
    }

    function _adjustTrovePre(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        InitialBalances memory _initialBalances
    ) internal returns (address) {
        address receiver =
            _checkAdjustTroveManagers(_troveId, _collChange, _isCollIncrease, _isDebtIncrease);

        // Set initial balances to make sure there are not lefovers
        _setInitialTokensAndBalances(IERC20(address(collToken)), boldToken, _initialBalances);

        // Pull coll
        if (_isCollIncrease) {
            _pullColl(_collChange);
        }

        // Pull Bold
        if (!_isDebtIncrease) {
            boldToken.transferFrom(msg.sender, address(this), _boldChange);
        }

        return receiver;
    }

    function _adjustTrovePost(
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        address _receiver,
        InitialBalances memory _initialBalances
    ) internal {
        // Send coll left
        if (!_isCollIncrease && _collChange > 0) {
            _sendColl(_receiver, _collChange);
        }

        // Send Bold
        if (_isDebtIncrease) {
            boldToken.transfer(_receiver, _boldChange);
        }

        // return leftovers to user
        _returnLeftovers(_initialBalances);
    }

    function closeTroveToRawETH(uint256 _troveId) external {
        address owner = troveNFT.ownerOf(_troveId);
        address payable receiver = payable(_requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner));
        _requireZapperIsReceiver(_troveId);

        // pull Bold for repayment
        LatestTroveData memory trove = troveManager.getLatestTroveData(_troveId);
        boldToken.transferFrom(msg.sender, address(this), trove.entireDebt);
        // @audit-high Relies on user to send exact amount without allowance validation.

        borrowerOperations.closeTrove(_troveId);

        // Send coll left
        _sendColl(receiver, trove.entireColl);

        // Send gas compensation
        WETH.withdraw(ETH_GAS_COMPENSATION);
        (bool success,) = receiver.call{value: ETH_GAS_COMPENSATION}("");
        require(success, "GCZ: Sending ETH failed");
        // @audit-low ETH send pattern can be replaced with `.transfer` for gas-limited safety.

    }

    function _pullColl(uint256 _amount) virtual internal {
        IERC20(collToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function _sendColl(address _receiver, uint256 _amount) virtual internal {
        IERC20(collToken).safeTransfer(_receiver, _amount);
    }

    receive() external payable {}

    function closeTroveFromCollateral(uint256 _troveId, uint256 _flashLoanAmount, uint256 _minExpectedCollateral) external virtual override {}
    function receiveFlashLoanOnCloseTroveFromCollateral(
        IZapper.CloseTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    function receiveFlashLoanOnOpenLeveragedTrove(
        ILeverageZapper.OpenLeveragedTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    function receiveFlashLoanOnLeverUpTrove(
        ILeverageZapper.LeverUpTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    function receiveFlashLoanOnLeverDownTrove(
        ILeverageZapper.LeverDownTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    // @audit-medium Stubbed flash loan entry points — must be protected or implemented to avoid misuse.

}
