// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BorrowStorage, BASIS_POINTS } from '../storage/BorrowStructs.sol';

import { LibERC4626 } from '../../common/libraries/LibERC4626.sol';
import { BorrowErrors } from './LibErrors.sol';

import { IERC20 } from '../../common/interfaces/IERC20.sol';
import { SafeERC20 } from '../../common/libraries/SafeERC20.sol';
import { IGovernor } from '../../common/interfaces/IGovernor.sol';
import { IInterestRate } from '../../common/interfaces/IInterestRate.sol';

library LibBorrow {
    using SafeERC20 for IERC20;

    bytes32 constant STORAGE_POSITION = keccak256('hashstack._borrowStorage.storage');

    function _borrowStorage() internal pure returns (BorrowStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    function _convert_to_debt_token(uint debt_amount) internal view returns (uint) {
        uint borrow_apr = IInterestRate(IGovernor(_getGovernor()).getInterestContract()).getBorrowAPR(LibERC4626._asset());
        return _convertToDebtTokenWithBorrowAPR(debt_amount, borrow_apr);
    }

    function _convertToDebtTokenWithBorrowAPR(uint debt_amount, uint borrow_apr) internal view returns (uint) {
        (uint supply, uint total_debt) = _getSuppliesInfo(borrow_apr);
        if (total_debt == 0) {
            return debt_amount;
        }

        return (debt_amount * supply / total_debt);
    }

    function _convert_to_underlying_asset(uint debt_tokens) internal view returns (uint) {
        uint borrow_apr = IInterestRate(IGovernor(_getGovernor()).getInterestContract()).getBorrowAPR(LibERC4626._asset());
        return _convertToUnderlyingAssetWithBorrowAPR(debt_tokens, borrow_apr);
    }

    function _convertToUnderlyingAssetWithBorrowAPR(
        uint debt_tokens,
        uint borrow_apr
    )
        internal
        view
        returns (uint)
    {
        (uint supply, uint total_debt) = _getSuppliesInfo(borrow_apr);
        if (supply == 0) {
            return debt_tokens;
        }

        return (debt_tokens * total_debt / supply);
    }

    function _getSuppliesInfo(uint borrow_apr) internal view returns (uint, uint) {
        uint total_debt = _totalDebtGivenBorrowAPR(borrow_apr); // debt in underlying asset, with interest calculated fresh
        uint supply = LibERC4626._totalSupply();

        return (supply, total_debt);
    }

    function _totalDebt() internal view returns (uint) {
       uint borrow_apr = IInterestRate(IGovernor(_getGovernor()).getInterestContract()).getBorrowAPR(LibERC4626._asset());
        return _totalDebtGivenBorrowAPR(borrow_apr);
    }

    function _totalDebtGivenBorrowAPR(uint borrow_apr) internal view returns (uint) {
        uint accured_interest = _accruedInterest(borrow_apr);
        uint outstanding_debt = _borrowStorage().outstanding_debt;
        uint TotalDebt = accured_interest + outstanding_debt;
        return (TotalDebt);
    }

    function _accruedInterest(uint borrow_apr) internal view returns (uint) {
        uint blocktimestamp = block.timestamp;
        uint last_timestamp = _borrowStorage().last_debt_accrued;
        uint period = blocktimestamp - last_timestamp;
        uint outstanding_debt = _borrowStorage().outstanding_debt;
        //Calculate interest
        uint numerator = period * outstanding_debt * borrow_apr;
        uint denominator = 86_400 * 365 * BASIS_POINTS;
        uint final_interest = numerator / denominator; // per cent is per 100, this is per 10,000
        return (final_interest);
    }

    function _mint(address recipient, uint dTokens, uint loanAmount) internal {
        LibERC4626._mint(address(this), dTokens, recipient);

        uint totalSupply = IERC20(LibERC4626._asset()).totalSupply();
        require(totalSupply >= LibERC4626._totalSupply(), 'BorrowVault: Mint fail');

        _borrowStorage().outstanding_debt += loanAmount;
    }

    function _redeem(address sender, address owner, address receiver, uint dTokens, uint loanAmount) internal {
        _borrowStorage().outstanding_debt -= loanAmount;
        LibERC4626._redeem(sender, dTokens, receiver, owner);
    }

    function _underlying_debt() internal view returns (uint) {
        return _borrowStorage().outstanding_debt;
    }

    function _last_debt_accrued() internal view returns (uint) {
        return _borrowStorage().last_debt_accrued;
    }

    function _update_underlying_debt(uint new_debt) internal {
        _borrowStorage().outstanding_debt = new_debt;
        _borrowStorage().last_debt_accrued = block.timestamp;
    }

    function _initializeVault(address asset_, string memory name_, string memory symbol_) internal {
        LibERC4626._initializeERC4626(name_, symbol_, asset_);
    }

    function _getGovernor() internal view returns (address) {
        return _borrowStorage().diamond;
    }

    function _setGovernor(address _diamond) internal {
        _borrowStorage().diamond = _diamond;
    }
}
