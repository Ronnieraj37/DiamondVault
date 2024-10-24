// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SupplyVaultStorage } from '../storage/SupplyVaultStorage.sol';
import { LibERC4626 } from '../../common/libraries/LibERC4626.sol';
import { IGovernor } from '../../common/interfaces/IGovernor.sol';
import { IInterestRate } from '../../common/interfaces/IInterestRate.sol';
import { IERC20 } from '../../common/interfaces/IERC20.sol';
import { SafeERC20 } from '../../common/libraries/SafeERC20.sol';

library LibSupply {
    using SafeERC20 for IERC20;

    // keccak256("hashstack.supply.storage")
    bytes32 constant SUPPLY_STORAGE_POSITION = 0x3c383d8d1cde9ea5d5f52c422b05d944143720c8e610e8baf62b9393972d7b85;

    event Locked(address indexed user, uint rTokensAmount, uint totalLocked);
    event Unlocked(address indexed user, uint rTokensAmount, uint totalLocked);
    event updatedSupplyTokenPrice(
        address indexed supplyToken,
        address indexed underlyingAsset,
        uint _totalSupply,
        uint totalAssets,
        uint timestamp
    );

    /// @dev Retrieves the supply storage for the current context.
    /// @return ds The SupplyVaultStorage struct reference.
    function supplyStorage() internal pure returns (SupplyVaultStorage storage ds) {
        bytes32 position = SUPPLY_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Gets the amount of free rTokens available for a user.
    /// @param user The address of the user.
    /// @return The amount of free rTokens available.
    /// @dev Reverts if the user is the zero address or if locked rTokens exceed user's balance.
    function _getFreeRTokens(address user) internal view returns (uint) {
        require(user != address(0), 'User is a zero address');
        uint _lockedRTokens = supplyStorage().lockedRTokens[user];
        uint userRTokensBalance = LibERC4626._balanceOf(user);
        require(_lockedRTokens <= userRTokensBalance, 'Inconsistent rToken balance');
        return (userRTokensBalance - _lockedRTokens);
    }

    /// @notice Calculates the total assets that are not accrued.
    /// @return The amount of unaccrued total assets.
    function _unaccruedTotalAssets() internal view returns (uint) {
        uint actualAssets = IERC20(LibERC4626._asset()).balanceOf(address(this));
        uint lentAssets_ = supplyStorage().lentAssets;
        return (actualAssets + lentAssets_);
    }

    /// @notice Computes the incentive for rTokens based on accrued interests.
    /// @return The rToken incentive amount.
    function _rTokenIncentive() internal view returns (uint) {
        uint depositAPR =
            IInterestRate(IGovernor(supplyStorage().governor).getInterestContract()).getSupplyAPR(address(this));
        uint unaccruedTotalAssets = _unaccruedTotalAssets();
        uint accruedInterest_ = _libAccruedInterest(unaccruedTotalAssets, depositAPR);
        uint incentivisedAccruedInterest = _libIncentiveAccruedInterest(unaccruedTotalAssets, depositAPR);
        uint rTokenIncentive_ = _libRTokenIncentive(unaccruedTotalAssets, accruedInterest_, incentivisedAccruedInterest);
        return rTokenIncentive_;
    }

    /// @notice Estimates the amount of assets that will be transferred for a given number of shares.
    /// @param shares The number of shares to convert to assets.
    /// @return The estimated amount of assets that can be withdrawn.
    function _previewRTokensTransfer(uint shares) internal view returns (uint) {
        (, uint exchangeRatesRTokensToAsset) = _exchangeRate();
        uint PRECISION = 1e18;
        uint assetAmountToWithdraw_ = exchangeRatesRTokensToAsset * shares;
        return (assetAmountToWithdraw_ / PRECISION);
    }

    /// @notice Locks a specified amount of rTokens for a user.
    /// @param user The address of the user.
    /// @param rTokensAmount The amount of rTokens to lock.
    /// @dev Reverts if the user is the zero address or if the rTokens amount is zero.
    /// @dev Also checks that the new locked amount does not exceed the user's balance.
    function _lockRTokens(address user, uint rTokensAmount) internal {
        require(user != address(0), 'user is a zero address');
        require(rTokensAmount != 0, 'rTokensAmount is zero');

        SupplyVaultStorage storage ds = supplyStorage();
        uint userRTokensBalance = LibERC4626._balanceOf(user);
        uint _lockedRTokens = ds.lockedRTokens[user];
        uint newLockedRTokens = _lockedRTokens + rTokensAmount;
        require(newLockedRTokens <= userRTokensBalance, 'Inconsistent rToken balance');

        ds.lockedRTokens[user] = newLockedRTokens;
        emit Locked(user, rTokensAmount, newLockedRTokens);
    }

    /// @notice Frees a specified amount of locked rTokens for a user.
    /// @param user The address of the user.
    /// @param rTokensAmount The amount of rTokens to free.
    /// @dev Reverts if the user is the zero address, if the rTokens amount is zero,
    /// or if there are not enough locked rTokens.
    function _freeLockedRTokens(address user, uint rTokensAmount) internal {
        require(user != address(0), 'user is a zero address');
        require(rTokensAmount != 0, 'rTokens amount is zero');

        SupplyVaultStorage storage ds = supplyStorage();
        uint _lockedRTokens = ds.lockedRTokens[user];

        require(rTokensAmount <= _lockedRTokens, 'Not enough locked rTokens');
        uint newLockedRTokens = _lockedRTokens - rTokensAmount;

        ds.lockedRTokens[user] = newLockedRTokens;

        emit Unlocked(user, rTokensAmount, newLockedRTokens);
    }

    /// @notice Updates the state of the deposit vault based on the current deposit APR.
    /// @param depositAPR The annual percentage rate for deposits.
    function _updateDepositVaultState(uint depositAPR) internal {
        SupplyVaultStorage storage ds = supplyStorage();

        uint unaccruedTotalAssets = LibERC4626._totalAssets();
        uint accruedIntertest = _libAccruedInterest(unaccruedTotalAssets, depositAPR);
        uint incentivisedAccruedInterest = _libIncentiveAccruedInterest(unaccruedTotalAssets, depositAPR);
        uint rTokenIncentiveShares =
            _libRTokenIncentive(unaccruedTotalAssets, accruedIntertest, incentivisedAccruedInterest);
        address stakingContract = IGovernor(ds.governor).getStakingContract();
        LibERC4626._mint(address(this), rTokenIncentiveShares, stakingContract);
        uint _lentAssetUpdated = accruedIntertest + incentivisedAccruedInterest;
        uint lentAseets_ = ds.lentAssets;
        ds.lentAssets = lentAseets_ + _lentAssetUpdated;
        ds.lastTimeAccrued = block.timestamp;
        emit updatedSupplyTokenPrice(
            address(this), LibERC4626._asset(), LibERC4626._totalSupply(), LibERC4626._totalAssets(), block.timestamp
        );
    }

    /// @notice Sets the daily withdrawal threshold.
    /// @param threshold The maximum percentage allowed for daily withdrawals.
    /// @dev Reverts if the threshold is greater than 100.
    function _setDailyWithdrawalThreshold(uint threshold) internal {
        require(threshold <= 100, 'greater than 100');
        supplyStorage().dialyWithdrawalThreshold = uint64(threshold);
    }

    function _accruedInterest() internal view returns (uint) {
        uint deposit_apr =
            IInterestRate(IGovernor(supplyStorage().governor).getInterestContract()).getSupplyAPR(address(this));

        uint unaccrued_total_assets = _unaccruedTotalAssets();
        uint accrued_interest = _libAccruedInterest(unaccrued_total_assets, deposit_apr);
        return accrued_interest;
    }

    function _incentiveAccruedInterest() internal view returns (uint) {
        uint deposit_apr =
            IInterestRate(IGovernor(supplyStorage().governor).getInterestContract()).getSupplyAPR(address(this));
        uint total_assets = _unaccruedTotalAssets();
        uint incentive_accrued_interest = _libIncentiveAccruedInterest(total_assets, deposit_apr);
        return incentive_accrued_interest;
    }

    /// @notice Calculates the incentive for rTokens.
    /// @param unaccruedTotalAssets The total unaccrued assets.
    /// @param accruedInterest The total accrued interest.
    /// @param incentivisedAccruedInterest The incentivized accrued interest.
    /// @return The calculated rToken incentive shares.
    function _libRTokenIncentive(
        uint unaccruedTotalAssets,
        uint accruedInterest,
        uint incentivisedAccruedInterest
    )
        internal
        view
        returns (uint)
    {
        uint rTokenTotalSupply = LibERC4626._totalSupply();
        if (rTokenTotalSupply == 0) {
            return 0;
        }
        uint numerator = incentivisedAccruedInterest * rTokenTotalSupply;
        uint denominator = unaccruedTotalAssets + accruedInterest;

        uint rTokenIncentiveShares = numerator / denominator;
        return rTokenIncentiveShares;
    }

    /// @notice Computes the accrued interest based on unaccrued assets and APR.
    /// @param unaccruedTotalAssets The total unaccrued assets.
    /// @param supplyAPR The annual percentage rate for deposits.
    /// @return The total accrued interest.
    function _libAccruedInterest(uint unaccruedTotalAssets, uint supplyAPR) internal view returns (uint) {
        uint currentBlockTimestamp = block.timestamp;
        uint lastTimeAccrued_ = supplyStorage().lastTimeAccrued;
        uint timeDiff = currentBlockTimestamp - lastTimeAccrued_;

        uint daysInSec = 365 * 86_400 * 10_000; // 10000 is buffer
        uint partialInterest = timeDiff * supplyAPR;
        uint aggInterest = partialInterest * unaccruedTotalAssets;
        uint accruedInterest = aggInterest / daysInSec;

        return accruedInterest;
    }

    /// @notice Gets the extra accrued interest for the stakers who stake rTokens.
    /// @param unaccruedTotalAssets The total unaccrued assets.
    /// @param supplyAPR The annual percentage rate for deposits.
    /// @return The extra accrued interest for stakers.
    function _libIncentiveAccruedInterest(uint unaccruedTotalAssets, uint supplyAPR) internal view returns (uint) {
        if (LibERC4626._totalSupply() == 0) {
            return (0);
        }

        address stakingContract = IGovernor(supplyStorage().governor).getStakingContract();
        uint stakedRTokens = IERC20(address(this)).balanceOf(stakingContract);

        // Calculate asset shares of stakers
        uint numerator = unaccruedTotalAssets * stakedRTokens;
        uint denominator = LibERC4626._totalSupply();
        uint assetSharesOfStakers = numerator / denominator;

        uint currentBlockTimestamp = block.timestamp;
        uint lastTimeAccrued_ = supplyStorage().lastTimeAccrued;
        uint timeDiff = currentBlockTimestamp - lastTimeAccrued_;

        uint daysInSec = 365 * 86_400 * 10_000; // 10000 is buffer (precision)
        uint partialInterest = timeDiff * supplyAPR;
        uint aggInterest = partialInterest * assetSharesOfStakers;
        uint extraAccruedInterest = aggInterest / daysInSec;
        return extraAccruedInterest;
    }

    /// @notice Gets the total amount of lent assets.
    /// @return The total lent assets.
    function _totalLentAssets() internal view returns (uint) {
        return supplyStorage().lentAssets;
    }

    /// @notice Sets the governor address for the supply storage.
    /// @param _governor The address of the new governor.
    /// @dev Reverts if the governor address is zero.
    function _setGovernor(address _governor) internal {
        require(_governor != address(0), 'Governor address is zero');
        supplyStorage().governor = _governor;
    }

    /// @notice Sets the minimum snapshot reserves.
    /// @param _reserve The minimum reserve amount.
    function _setMinSnapshotReserves(uint _reserve) internal {
        supplyStorage().minSnapshotReserve = _reserve;
    }

    /// @notice Gets the next withdrawal reset time.
    /// @return The next reset time as a timestamp.
    function _getNextWithdrawalResetTime() internal view returns (uint64) {
        return supplyStorage().nextWithdrawLimitResetTime;
    }

    /// @notice Gets the current deposit reserves snapshot.
    /// @return The amount of deposit reserves.
    function _getDepositReservesSnapshot() internal view returns (uint) {
        return uint(supplyStorage().depositReservesSnapshot);
    }

    /// @notice Gets the current daily withdrawal threshold.
    /// @return The current daily withdrawal threshold percentage.
    function _getDailyWithdrawalThreshold() internal view returns (uint) {
        return supplyStorage().dialyWithdrawalThreshold;
    }

    /// @notice Gets the minimum snapshot reserves.
    /// @return The minimum snapshot reserves amount.
    function _getMinSnapshotReserves() internal view returns (uint) {
        return supplyStorage().minSnapshotReserve;
    }

    /// @notice Calculates the exchange rate between assets and rTokens.
    /// @return exchangeRatesAssetToRTokens The exchange rate from assets to rTokens.
    /// @return exchangeRatesRTokensToAsset The exchange rate from rTokens to assets.
    function _exchangeRate() internal view returns (uint, uint) {
        uint totalSupply_ = LibERC4626._totalSupply();
        uint PRECISION = 1e18;
        if (totalSupply_ == 0) {
            return (PRECISION, PRECISION);
        }
        uint totalAssets_ = LibERC4626._totalAssets();
        uint getTotalSupplyPrecissioned = totalSupply_ * PRECISION;
        uint getTotalAssetsPrecissioned = totalAssets_ * PRECISION;
        uint exchangeRatesAssetToRTokens = getTotalSupplyPrecissioned / totalAssets_;
        uint exchangeRatesRTokensToAsset = getTotalAssetsPrecissioned / totalSupply_;
        return (exchangeRatesAssetToRTokens, exchangeRatesRTokensToAsset);
    }

    /// @notice Transfers assets to the borrow vault for a given loan.
    /// @param caller The address of the caller.
    /// @param loanId The ID of the loan.
    /// @param amountAssets The amount of assets to transfer.
    /// @dev Reverts if the loan has already been transferred or if there are insufficient assets.
    function _transferAssetsToLoanFacet(address caller, uint loanId, uint amountAssets) internal {
        SupplyVaultStorage storage ds = supplyStorage();
        address asset = LibERC4626._asset();

        uint amountRTokensExisting = ds.lentLoansRTokens[caller][loanId];
        require(amountRTokensExisting == 0, 'already transferred');

        uint loanAmountRTokens = _previewAssetsTransfer(amountAssets);
        ds.lentLoansRTokens[caller][loanId] = loanAmountRTokens;

        uint assetBalanceContract = IERC20(asset).balanceOf(address(this));
        require(amountAssets <= assetBalanceContract, 'unable to transfer assets');

        IERC20(asset).safeTransfer(caller, amountAssets);
        ds.lentAssets += amountAssets;
    }

    /// @notice Transfers rTokens during a liquidation process.
    /// @param user The address of the user being liquidated.
    /// @param recipient The address to receive the rTokens.
    /// @param rTokensAmount The amount of rTokens to transfer.
    /// @dev Reverts if the user does not have enough locked rTokens.
    function _liquidationTransfer(address user, address recipient, uint rTokensAmount) internal {
        uint _lockedRTokens = supplyStorage().lockedRTokens[user];
        require(_lockedRTokens >= rTokensAmount, 'Not enough locked rTokens');
        _freeLockedRTokens(user, rTokensAmount);
        LibERC4626._transfer(user, recipient, rTokensAmount);
        supplyStorage().lockedRTokens[recipient] = rTokensAmount;
    }

    /// @notice Calculates the post-fee amount and the fee charged.
    /// @param amount The original amount.
    /// @param feeBasis The fee basis points (bps).
    /// @return post_feeAmount The amount after fees.
    /// @return feeAmount The amount charged as a fee.
    function _getPostFeeAmount(uint amount, uint feeBasis) internal pure returns (uint, uint) {
        uint _feeAmount = amount * feeBasis;
        uint feeAmount = _feeAmount / 10_000;
        uint post_feeAmount = amount - feeAmount;
        return (post_feeAmount, feeAmount);
    }

    /// @notice Calculates the pre-fee amount required to achieve a desired amount after fees.
    /// @param amount The desired amount after fees.
    /// @param feeBasis The fee basis points (bps).
    /// @return preFeeAmount The amount before fees.
    /// @return feeAmount The amount charged as a fee.
    function _getPreFeeAmount(uint amount, uint feeBasis) internal pure returns (uint, uint) {
        uint effectiveBPS = 10_000 - feeBasis;
        uint _preFeeAmount = amount * 10_000;
        uint preFeeAmount = _preFeeAmount / effectiveBPS;
        uint feeAmount = preFeeAmount - amount;
        return (preFeeAmount, feeAmount);
    }

    /// @notice Estimates the amount of rTokens to be received for a specified amount of assets.
    /// @param assets The amount of assets to convert to rTokens.
    /// @return The estimated number of rTokens to receive.
    function _previewAssetsTransfer(uint assets) internal view returns (uint) {
        (uint exchangeRatesAssetToRTokens,) = _exchangeRate();
        uint PRECISION = 1e18;
        uint getCalculatedShares = exchangeRatesAssetToRTokens * assets;
        uint finalCalculatedShares = getCalculatedShares / PRECISION;
        return finalCalculatedShares;
    }

    function _getRepayAmountLoanFacet(address borrower, uint loan_id) internal view returns (uint) {
        uint amount_rTokens_existing = supplyStorage().lentLoansRTokens[borrower][loan_id];
        uint assets = _previewRTokensTransfer(amount_rTokens_existing);
        return assets;
    }

    /// @notice Repays assets from the borrow vault for a specified loan.
    /// @param borrower The address of the borrower.
    /// @param loanId The ID of the loan.
    /// @param amountAssetsToRepay The amount of assets to repay.
    /// @dev Reverts if the loan has not been previously taken or if the repay amount exceeds the expected assets.
    function _repayFromLoanFacet(address borrower, uint loanId, uint amountAssetsToRepay) internal {
        uint amountRTokensExisting = supplyStorage().lentLoansRTokens[borrower][loanId];
        require(amountRTokensExisting != 0, 'lent loans rTokens is zero');

        uint expectedAssets = _previewRTokensTransfer(amountRTokensExisting);
        require(amountAssetsToRepay <= expectedAssets, 'repay_assets > expectedAssets');

        uint amountLeft = expectedAssets - amountAssetsToRepay;

        supplyStorage().lentLoansRTokens[borrower][loanId] = amountLeft;

        supplyStorage().lentAssets -= amountAssetsToRepay;
        IERC20(LibERC4626._asset()).safeTransferFrom(borrower, address(this), amountAssetsToRepay);
    }
}
