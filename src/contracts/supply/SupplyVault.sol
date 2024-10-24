// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC4626 } from '../common/libraries/LibERC4626.sol';
import { LibSupply} from './implementation/LibSupply.sol';
import { Security } from '../common/security/security.sol';

/**
 * @title SupplyVault
 * @dev This contract serves as a vault for managing assets, allowing users to deposit,
 * mint, withdraw, redeem, and perform various operations on supply tokens while ensuring
 * security through role-based access controls.
 */
contract SupplyVault is Security {
    error Supply__ExceedsFreeRTokenAmount();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with asset details, governor, and access control address.
     * @param asset_ The address of the asset being managed by the vault.
     * @param name_ The name of the vault.
     * @param symbol_ The symbol of the vault's tokens.
     * @param diamond The address of the contract governor.
     * @param accessRegistry The address for access control management.
     */
    function initializeSupply(
        address asset_,
        string memory name_,
        string memory symbol_,
        address diamond,
        address accessRegistry
    )
        external
        initializer
    {
        initilaizeSecurity(accessRegistry);
        LibERC4626._initializeERC4626(name_, symbol_, asset_);
        LibSupply._setGovernor(diamond);
    }

    /**
     * @dev Returns the total supply of tokens in the vault.
     * @return The total number of tokens.
     */
    function totalSupply() external view returns (uint) {
        return LibERC4626._totalSupply();
    }

    /**
     * @dev Returns the balance of a specific account.
     * @param account The address of the account.
     * @return The balance of the account.
     */
    function balanceOf(address account) external view returns (uint) {
        return LibERC4626._balanceOf(account);
    }

    /**
     * @dev Returns the name of the vault.
     * @return The name of the vault.
     */
    function name() external view returns (string memory) {
        return LibERC4626._name();
    }

    /**
     * @dev Returns the symbol of the vault's tokens.
     * @return The symbol of the vault's tokens.
     */
    function symbol() external view returns (string memory) {
        return LibERC4626._symbol();
    }

    /**
     * @dev Returns the number of decimals used by the vault's tokens.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint8) {
        return LibERC4626._decimals();
    }

    // /**
    //  * @dev Returns the address of the asset token being managed.
    //  * @return The address of the asset token.
    //  */
    function asset() external view returns(address assetTokenAddress) {
        assetTokenAddress = LibERC4626._asset();
    }

    // /**
    //  * @dev Returns the total amount of assets managed by the vault.
    //  * @return The total managed assets.
    //  */
    function totalAssets() external view returns(uint totalManagedAssets) {
        totalManagedAssets = LibERC4626._totalAssets();
    }

    /**
     * @dev Converts assets to shares.
     * @param assets The amount of assets to convert.
     * @return shares The equivalent number of shares.
     */
    function convertToShares(uint assets) external view returns (uint shares) {
        return LibERC4626._convertToShares(assets);
    }

    /**
     * @dev Converts shares to assets.
     * @param shares The amount of shares to convert.
     * @return assets The equivalent number of assets.
     */
    function convertToAssets(uint shares) external view returns (uint assets) {
        return LibERC4626._convertToAssets(shares);
    }

    /**
     * @dev Returns the maximum amount of assets that can be deposited for a receiver.
     * @param receiver The address of the receiver.
     * @return maxAssets The maximum amount of assets that can be deposited.
     */
    function maxDeposit(address receiver) external pure returns (uint maxAssets) {
        return LibERC4626._maxDeposit(receiver);
    }

    /**
     * @dev Provides a preview of the shares received for a deposit.
     * @param assets The amount of assets to deposit.
     * @return shares The expected number of shares.
     */
    function previewDeposit(uint assets) external view returns (uint shares) {
        return LibERC4626._previewDeposit(assets);
    }

    /**
     * @dev Returns the maximum shares that can be minted for a receiver.
     * @param receiver The address of the receiver.
     * @return maxShares The maximum shares that can be minted.
     */
    function maxMint(address receiver) external pure returns (uint maxShares) {
        return LibERC4626._maxMint(receiver);
    }

    /**
     * @dev Provides a preview of the assets received for minting shares.
     * @param shares The amount of shares to mint.
     * @return assets The expected number of assets.
     */
    function previewMint(uint shares) external view returns (uint assets) {
        return LibERC4626._previewMint(shares);
    }

    /**
     * @dev Returns the maximum amount of assets that can be withdrawn by an owner.
     * @param owner The address of the owner.
     * @return maxAssets The maximum assets that can be withdrawn.
     */
    function maxWithdraw(address owner) external view returns (uint maxAssets) {
        return LibERC4626._maxWithdraw(owner);
    }

    /**
     * @dev Provides a preview of the shares to be redeemed for a given asset amount.
     * @param assets The amount of assets to withdraw.
     * @return shares The expected number of shares.
     */
    function previewWithdraw(uint assets) external view returns (uint shares) {
        return LibERC4626._previewWithdraw(assets);
    }

    /**
     * @dev Returns the maximum shares that can be redeemed by an owner.
     * @param owner The address of the owner.
     * @return maxShares The maximum shares that can be redeemed.
     */
    function maxRedeem(address owner) external view returns (uint maxShares) {
        return LibERC4626._maxRedeem(owner);
    }

    /**
     * @dev Provides a preview of the assets received for redeeming shares.
     * @param shares The amount of shares to redeem.
     * @return assets The expected number of assets.
     */
    function previewRedeem(uint shares) external view returns (uint assets) {
        return LibERC4626._previewRedeem(shares);
    }

    /**
     * @dev Returns the current exchange rate between assets and shares.
     * @return (exchange rate, other value)
     */
    function exchangeRate() external view returns (uint, uint) {
        return LibSupply._exchangeRate();
    }

    /**
     * @dev Returns the total assets that have not accrued interest yet.
     * @return The total unaccrued assets.
     */
    function unaccruedTotalAssets() external view returns (uint) {
        return (LibERC4626._totalAssets() + LibSupply._totalLentAssets());
    }

    /**
     * @dev Returns the total amount of assets that have been lent out.
     * @return The total lent assets.
     */
    function totalLentAssets() external view returns (uint) {
        return LibSupply._totalLentAssets();
    }

    /**
     * @dev Returns the current incentive for rTokens.
     * @return The rToken incentive value.
     */
    function rTokenIncentive() external view returns (uint) {
        return LibSupply._rTokenIncentive();
    }

    /**
     * @dev Returns the amount of free rTokens available for a user.
     * @param user The address of the user.
     * @return The amount of free rTokens.
     */
    function getFreeRTokens(address user) external view returns (uint) {
        return LibSupply._getFreeRTokens(user);
    }

    /**
     * @dev Calculates the repayment amount for a borrow vault.
     * @param borrower The address of the borrower.
     * @param loanId The ID of the loan.
     * @return The repayment amount.
     */
    function getRepayAmountLoanFacet(address borrower, uint loanId) external view returns (uint) {
        return LibSupply._getRepayAmountLoanFacet(borrower, loanId);
    }

    /**
     * @dev Returns the accrued interest for incentives.
     * @return The amount of accrued interest.
     */
    function incentiveAccruedInterest() external view returns (uint) {
        return LibSupply._incentiveAccruedInterest();
    }

    /**
     * @dev Returns the total accrued interest for the vault.
     * @return The total accrued interest.
     */
    function accruedInterest() external view returns (uint) {
        return LibSupply._accruedInterest();
    }

    /**
     * @dev Returns the unaccrued total supply of tokens.
     * @return The unaccrued total supply.
     */
    function unaccruedTotalSupply() external view returns (uint) {
        return LibERC4626._totalSupply();
    }

    /**
     * @dev Returns the next reset time for withdrawals.
     * @return The next withdrawal reset time as a UNIX timestamp.
     */
    function getNextWithdrawalResetTime() external view returns (uint64) {
        return LibSupply._getNextWithdrawalResetTime();
    }

    /**
     * @dev Returns a snapshot of the deposit reserves.
     * @return The deposit reserves snapshot.
     */
    function getDepositReservesSnapshot() external view returns (uint) {
        return LibSupply._getDepositReservesSnapshot();
    }

    /**
     * @dev Returns the daily withdrawal threshold. This function should be implemented.
     * @return The daily withdrawal threshold.
     */
    function getDailyWithdrawalThreshold() external returns (uint) {
        // Placeholder for implementation
    }

    /**
     * @dev Returns the minimum snapshot reserves.
     * @return The minimum snapshot reserves.
     */
    function getMinSnapshotReserves() external view returns (uint) {
        return LibSupply._getMinSnapshotReserves();
    }

    /**
     * @dev Transfers tokens to another address.
     * @param to The recipient address.
     * @param value The amount of tokens to transfer.
     * @return success Indicates if the transfer was successful.
     */
    function transfer(address to, uint value) external notZeroAddress(to) returns (bool) {
        if (value > LibSupply._getFreeRTokens(msg.sender)) {
            revert Supply__ExceedsFreeRTokenAmount();
        }
        return LibERC4626._transfer(msg.sender, to, value);
    }

    /**
     * @dev Returns the allowance of a spender for a specific owner's tokens.
     * @param owner The address of the token owner.
     * @param spender The address of the spender.
     * @return The amount of tokens allowed to be spent.
     */
    function allowance(address owner, address spender) external view notZeroAddress(owner) returns (uint) {
        return LibERC4626._allowance(owner, spender);
    }

    /**
     * @dev Approves a spender to spend a specified amount of tokens.
     * @param spender The address of the spender.
     * @param value The amount of tokens to approve.
     * @return success Indicates if the approval was successful.
     */
    function approve(address spender, uint value) external notZeroAddress(spender) returns (bool) {
        return LibERC4626._approve(msg.sender, spender, value);
    }

    /**
     * @dev Transfers tokens from one address to another using an allowance.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param value The amount of tokens to transfer.
     * @return success Indicates if the transfer was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint value
    )
        external
        notZeroAddress(from)
        notZeroAddress(to)
        returns (bool)
    {
        if (value > LibSupply._getFreeRTokens(from)) {
            revert Supply__ExceedsFreeRTokenAmount();
        }
        return LibERC4626._transferFrom(from, to, value);
    }

    /**
     * @dev Deposits assets into the vault and mints shares for the receiver.
     * @param assets The amount of assets to deposit.
     * @param receiver The address that will receive the shares.
     * @return shares The amount of shares minted.
     */
    function deposit(
        address sender,
        uint assets,
        address receiver
    )
        external
        onlyOpenRole
        whenNotPaused
        notZeroAddress(receiver)
        notZeroValue(assets)
        returns (uint shares)
    {
        return LibERC4626._deposit(sender, assets, receiver);
    }

    /**
     * @dev Mints shares for a specified amount and assigns them to the receiver.
     * @param shares The amount of shares to mint.
     * @param receiver The address that will receive the assets.
     * @return assets The amount of assets received for the shares.
     */
    function mint(
        uint shares,
        address receiver
    )
        external
        whenNotPaused
        notZeroAddress(receiver)
        notZeroValue(shares)
        returns (uint assets)
    {
        return LibERC4626._mint(msg.sender, shares, receiver);
    }

    /**
     * @dev Withdraws a specified amount of assets from the vault.
     * @param assets The amount of assets to withdraw.
     * @param receiver The address that will receive the assets.
     * @param owner The address of the owner of the assets.
     * @return shares The amount of shares burned.
     */
    function withdraw(
        address caller,
        uint assets,
        address receiver,
        address owner
    )
        external
        onlyOpenRole
        whenNotPaused
        notZeroAddress(receiver)
        notZeroValue(assets)
        returns (uint shares)
    {
        return LibERC4626._withdraw(caller, assets, receiver, owner);
    }

    /**
     * @dev Redeems shares for a specified amount of assets.
     * @param shares The amount of shares to redeem.
     * @param receiver The address that will receive the assets.
     * @param owner The address of the owner of the shares.
     * @return assets The amount of assets received for the shares.
     */
    function redeem(
        uint shares,
        address receiver,
        address owner
    )
        external
        whenNotPaused
        notZeroAddress(receiver)
        notZeroValue(shares)
        returns (uint assets)
    {
        return LibERC4626._redeem(msg.sender, shares, receiver, owner);
    }

    /**
     * @dev Locks a specified amount of rTokens for a user.
     * @param user The address of the user whose rTokens are to be locked.
     * @param rTokenAmount The amount of rTokens to lock.
     */
    function lockRTokens(
        address user,
        uint rTokenAmount
    )
        external
        onlyOpenRole
        notZeroAddress(user)
        notZeroValue(rTokenAmount)
    {
        LibSupply._lockRTokens(user, rTokenAmount);
    }

    /**
     * @dev Frees a specified amount of locked rTokens for a user.
     * @param user The address of the user whose rTokens are to be freed.
     * @param rTokenAmount The amount of rTokens to free.
     */
    function freeLockedRTokens(
        address user,
        uint rTokenAmount
    )
        external
        onlyOpenRole
        notZeroAddress(user)
        notZeroValue(rTokenAmount)
    {
        LibSupply._freeLockedRTokens(user, rTokenAmount);
    }

    /**
     * @dev Transfers assets to the borrow vault.
     * @param loanId The ID of the loan.
     * @param amount The amount of assets to transfer.
     */
    function transferAssetsToLoanFacet(address caller, uint loanId, uint amount) external onlyOpenRole notZeroValue(amount) {
        LibSupply._transferAssetsToLoanFacet(caller,loanId, amount);
    }

    /**
     * @dev Transfers assets during liquidation.
     * @param user The address of the user whose assets are being transferred.
     * @param recipient The address that will receive the assets.
     * @param rTokensAmount The amount of rTokens involved in the transfer.
     */
    function liquidationTransfer(
        address user,
        address recipient,
        uint rTokensAmount
    )
        external
        onlyOpenRole
        notZeroAddress(user)
        notZeroValue(rTokensAmount)
    {
        LibSupply._liquidationTransfer(user, recipient, rTokensAmount);
    }

    /**
     * @dev Repays assets from the borrow vault.
     * @param loanId The ID of the loan.
     * @param borrower The address of the borrower.
     * @param amountAssetsToRepay The amount of assets to repay.
     */
    function repayFromLoanFacet(
        uint loanId,
        address  borrower,
        uint amountAssetsToRepay
    )
        external
        onlyOpenRole
        notZeroAddress(borrower)
        notZeroValue(amountAssetsToRepay)
    {
        LibSupply._repayFromLoanFacet(borrower, loanId, amountAssetsToRepay);
    }

    /**
     * @dev Updates the deposit vault's state with the new supply APR.
     * @param supply_apr The new supply annual percentage rate.
     */
    function updateDepositVaultState(uint supply_apr) external onlyOpenRole notZeroValue(supply_apr) {
        LibSupply._updateDepositVaultState(supply_apr);
    }

    /**
     * @dev Sets the daily withdrawal threshold.
     * @param threshold The new daily withdrawal threshold.
     */
    function setDailyWithdrawalThreshold(uint64 threshold) external onlyOpenRole {
        LibSupply._setDailyWithdrawalThreshold(threshold);
    }

    /**
     * @dev Sets the minimum snapshot reserves.
     * @param reserve The new minimum snapshot reserves.
     */
    function setMinSnapshotReserves(uint reserve) external onlyOpenRole {
        LibSupply._setMinSnapshotReserves(reserve);
    }

    /**
     * @dev Increases the allowance of a spender.
     * @param spender The address of the spender.
     * @param addedValue The amount to add to the allowance.
     * @return success Indicates if the increase was successful.
     */
    function increaseAllowance(
        address spender,
        uint addedValue
    )
        external
        notZeroAddress(spender)
        returns(bool)
    {
        return LibERC4626._increaseAllowance(msg.sender, spender, addedValue);
    }

    /**
     * @dev Decreases the allowance of a spender.
     * @param spender The address of the spender.
     * @param subtractedValue The amount to subtract from the allowance.
     * @return success Indicates if the decrease was successful.
     */
    function decreaseAllowance(
        address spender,
        uint subtractedValue
    )
        external
        notZeroAddress(spender)
        returns (bool success)
    {
        return LibERC4626._decreaseAllowance(msg.sender, spender, subtractedValue);
    }
}