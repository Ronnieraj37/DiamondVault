// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibBorrow } from './implementation/LibBorrow.sol';
import { LibERC4626 } from '../common/libraries/LibERC4626.sol';
import { BorrowErrors } from './implementation/LibErrors.sol';
import { Loan } from '../../diamond/storages/Loan/LoanStorage.sol';
import { Security } from '../common/security/security.sol';
import { IGovernor } from '../common/interfaces/IGovernor.sol';
import { IInterestRate } from '../common/interfaces/IInterestRate.sol';

contract BorrowVault is Security {
    /**
     * @dev Emitted when the debt token price is updated.
     * @param debt_token The address of the debt token.
     * @param underlying_asset The address of the underlying asset.
     * @param total_supply The total supply of the debt tokens.
     * @param total_debt The total amount of debt.
     * @param timestamp The time at which the update occurred.
     */
    event UpdatedDebtTokenPrice(
        address indexed debt_token,
        address indexed underlying_asset,
        uint total_supply,
        uint total_debt,
        uint indexed timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the BorrowVault contract with access control, asset information, and borrowing settings.
     * @param asset The address of the asset used for borrowing.
     * @param name The name of the borrowing vault.
     * @param symbol The symbol of the borrowing vault.
     * @param access_control The address of the access control contract.
     * @param diamond The address of diamond contract.
     */
    function initialize(
        address asset,
        string memory name,
        string memory symbol,
        address access_control,
        address diamond
    ) external initializer {
        LibBorrow._initializeVault(asset, name, symbol);
        initilaizeSecurity(access_control);
        LibBorrow._setGovernor(diamond);
    }

    function mint(address recipient, uint dTokens, uint loanAmount) external onlyOpenRole {
        LibBorrow._mint(recipient, dTokens, loanAmount);
    }

    function redeem(address owner, address receiver, uint dTokens, uint loanAmount) external onlyOpenRole {
        LibBorrow._redeem(address(this), owner, receiver, dTokens, loanAmount);
    }

    /**
     * @dev Updates the address of diamond contract.
     * @param diamond The address of diamond contract.
     */
    function setDiamond(address diamond) external {
        LibBorrow._setGovernor(diamond);
    }

    /**
     * @dev Updates the state of the borrow vault and emits an event with updated debt token price.
     * @param borrow_apr The new borrowing annual percentage rate.
     */
    function updateBorrowVaultState(uint borrow_apr) external onlyOpenRole {
        uint interest = LibBorrow._accruedInterest(borrow_apr);
        uint underlying_debt = LibBorrow._underlying_debt();
        uint total = interest + underlying_debt;
        LibBorrow._update_underlying_debt(total);

        emit UpdatedDebtTokenPrice(
            address(this),
            LibERC4626._asset(),
            LibERC4626._totalSupply(),
            total,
            block.timestamp
        );
    }

    ////////////////////////////
    //////// VIEW FUNCTIONS ////
    ////////////////////////////

    function convertToDebtTokenWithBorrowAPR(uint loanamount, uint borrowAPR) external view returns (uint){
        return LibBorrow._convertToDebtTokenWithBorrowAPR(loanamount, borrowAPR);
    }
    function convertToUnderlyingAssetWithBorrowAPR(uint loanAmount, uint borrowApr) external view returns (uint){
        return LibBorrow._convertToUnderlyingAssetWithBorrowAPR(loanAmount, borrowApr);
    }

    /**
     * @dev Returns the address of the underlying asset.
     * @return The address of the underlying asset.
     */
    function getUnderlyingAsset() external view returns (address) {
        return LibERC4626._asset();
    }

    /**
     * @dev Returns the total underlying debt amount.
     * @return The total underlying debt.
     */
    function getUnderlyingDebt() external view returns (uint) {
        return LibBorrow._underlying_debt();
    }

    /**
     * @dev Converts a given amount of shares to the underlying asset.
     * @param shares The amount of shares to convert.
     * @return The equivalent amount of underlying asset.
     */
    function convertToAssets(uint shares) external view returns (uint) {
        return LibBorrow._convert_to_underlying_asset(shares);
    }

    /**
     * @dev Converts a given amount of underlying asset to shares.
     * @param amount The amount of underlying asset to convert.
     * @return The equivalent amount of shares.
     */
    function convertToShares(uint amount) external view returns (uint) {
        return LibBorrow._convert_to_debt_token(amount);
    }
}