// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISupplyVault } from '../../contracts/common/interfaces/ISupplyVault.sol';
import { IBorrowVault } from '../../contracts/common/interfaces/IBorrowVault.sol';
import { BorrowErrors } from '../../contracts/borrow/implementation/LibErrors.sol';
import {
    Loan,
    LoanStorage,
    LoanStateConstants,
    CategoryConstants,
    BASIS_POINTS,
    Collateral,
    Withdraw_collateral
} from '../storages/Loan/LoanStorage.sol';
import { Collateral, CollateralStorage } from '../storages/Loan/LoanStorage.sol';
import { RouterStorage } from '../storages/RouterStorage.sol';
import { Governor } from '../facets/Governor.sol';
import { LibRouter } from './LibRouter.sol';
import { LibLoanModule } from './LibLoanModule.sol';
import { IERC20 } from '../../contracts/common/interfaces/IERC20.sol';
import { SafeERC20 } from '../../contracts/common/libraries/SafeERC20.sol';

/**
 * @title LibCollateral
 * @dev Library for managing loan collateral in the borrowing system.
 */
library LibCollateral {
    using LibCollateral for Collateral;
    using SafeERC20 for IERC20;

    event collateral_added(Collateral collateral, uint amount, uint timestamp);
    event collateral_released(uint released_amount, Collateral collateral_record, uint timestamp);

    bytes32 constant STORAGE_POSITION = keccak256('hashstack.colleteral_storage.storage');
    bytes32 constant DIAMOND_STORAGE_OPEN_ROUTER_POSITION = keccak256('diamond.standard.storage.router');
    bytes32 constant GOVERNOR_STORAGE_POSITION = keccak256('diamond.standard.storage.governor');

    /// @notice Retrieves the Collateral storage.
    /// @return ds The CollateralStorage struct.
    function _collateralStorage() internal pure returns (CollateralStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    ///////////////////////////////////
    ///// Internal View Functions /////
    ///////////////////////////////////

    /// @notice Gets the collateral information for a specific loan.
    /// @param loan_id The ID of the loan to retrieve collateral for.
    /// @return The Collateral struct containing collateral details.
    function _getCollateral(uint loan_id) internal view returns (Collateral memory) {
        return _collateralStorage().collateral_records[loan_id];
    }

    /// @notice Gets the net collateral for a specific rToken.
    /// @param rToken The address of the rToken.
    /// @return The total net collateral amount.
    function _netCollateral(address rToken) internal view returns (uint) {
        return _collateralStorage().net_collaterals[rToken];
    }


    //////////////////////////////
    ///// Internal Functions /////
    //////////////////////////////

    /// @notice Creates new collateral record.
    /// @param collateral The Collateral struct to create.
    function _create(Collateral memory collateral) internal {
        _saveCollateral(collateral);
        _addNewCollateral(collateral, collateral.amount);
    }

    /// @notice Repays part of the collateral.
    /// @param collateral The existing Collateral struct.
    /// @param amount The amount of collateral to repay.
    function _repay(Collateral memory collateral, uint amount) internal {
        collateral.amount -= amount;
        _saveCollateral(collateral);
        _subNewCollateral(collateral, amount);
        emit collateral_released(amount, collateral, block.timestamp);
    }

    /// @notice Adds collateral in the form of underlying asset.
    /// @param loanId The loan ID for which collateral is being added.
    /// @param collateralAsset The address of the collateral market.
    /// @param collateralAmount The amount of the collateral to add.
    function _addCollateralWithAsset(uint loanId, address collateralAsset, uint collateralAmount) internal {
        address rToken = Governor(LibRouter._getGovernor()).getRTokenFromAsset(collateralAsset);
        (Loan memory loanRecord,) = LibLoanModule._getLoanById(loanId);
        uint rTokenAmount = LibRouter._deposit(collateralAsset, collateralAmount, loanRecord.borrower);
        _addCollateralWithRTokenI(loanId, rToken, rTokenAmount, msg.sender);
    }

    /// @notice Adds collateral in the form of rToken.
    /// @param loanId The loan ID for which collateral is being added.
    /// @param rToken The address of the rToken.
    /// @param rTokenAmount The amount of rTokens to add as collateral.
    /// @param owner The owner of the rTokens.
    /// @dev This function allows anyone to add collateral to a loan.
    /// If the caller is not the owner of the loan, rTokens will be transferred to the loan owner.
    function _addCollateralWithRTokenI(uint loanId, address rToken, uint rTokenAmount, address owner) internal {
        Loan memory loan = LibLoanModule._getLoan(loanId);

        if (owner != loan.borrower) {
            IERC20(rToken).safeTransferFrom(owner, loan.borrower, rTokenAmount);
        }

        _preAddCollateral(rToken, rTokenAmount, loan.borrower);
        _addCollateralWithRTokenII(loanId, rToken, rTokenAmount);
    }

    /// @notice Prepares to add collateral by checking available rTokens.
    /// @param rToken The address of the rToken.
    /// @param rTokenAmount The amount of rTokens to lock.
    /// @param owner The owner of the rTokens.
    /// @dev Reverts if not enough collateral is available.
    function _preAddCollateral(address rToken, uint rTokenAmount, address owner) internal {
        uint free_rTokens = ISupplyVault(rToken).getFreeRTokens(owner);
        if (rTokenAmount > free_rTokens) revert BorrowErrors.Borrow__NotEnoughCollateral();
        ISupplyVault(rToken).lockRTokens(owner, rTokenAmount);
    }

    /////////////////////////////
    ///// Private Functions /////
    /////////////////////////////

    /// @notice Adds more collateral to an existing record.
    /// @param collateral The existing Collateral struct.
    /// @param amount The additional amount of collateral to add.
    function _add(Collateral memory collateral, uint amount) private {
        collateral.amount += amount;
        _saveCollateral(collateral);
        _addNewCollateral(collateral, amount);
        emit collateral_added(collateral, amount, block.timestamp);
    }

    /// @notice Saves the collateral information in storage.
    /// @param collateral The Collateral struct to save.
    function _saveCollateral(Collateral memory collateral) private {
        _collateralStorage().collateral_records[collateral.loan_id] = collateral;
    }

    /// @notice Adds new collateral amount to net collateral.
    /// @param collateral The Collateral struct containing the information.
    /// @param amount The amount to add to net collateral.
    function _addNewCollateral(Collateral memory collateral, uint amount) private {
        _collateralStorage().net_collaterals[collateral.collateral_market] += amount;
    }

    /// @notice Subtracts collateral amount from net collateral.
    /// @param collateral The Collateral struct containing the information.
    /// @param amount The amount to subtract from net collateral.
    function _subNewCollateral(Collateral memory collateral, uint amount) private {
        _collateralStorage().net_collaterals[collateral.collateral_market] -= amount;
    }

    /// @notice Adds collateral to a loan by locking rTokens.
    /// @param loan_id The ID of the loan to add collateral to.
    /// @param rToken The address of the rToken.
    /// @param rTokenAmount The amount of rTokens to add as collateral.
    /// @return The updated Collateral struct.
    function _addCollateralWithRTokenII(uint loan_id, address rToken, uint rTokenAmount) private returns (Collateral memory) {
        Collateral memory collateral = _getCollateral(loan_id);
        if (collateral.timestamp == 0) {
            // New loan collateral
            collateral.timestamp = block.timestamp;
            collateral.collateral_market = rToken;
            collateral.loan_id = loan_id;
        } else {
            // Existing collateral checks
            if (collateral.collateral_market != rToken) revert BorrowErrors.Borrow__CollateralMismatch();
        }
        _add(collateral, rTokenAmount);
        return collateral;
    }

}
