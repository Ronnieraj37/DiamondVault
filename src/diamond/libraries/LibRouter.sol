// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RouterStorage } from '../storages/RouterStorage.sol';
import { DepositVaultMetadata } from '../storages/Governor/GovernorStruct.sol';
import { ISupplyVault } from '../../contracts/common/interfaces/ISupplyVault.sol';
import { IBorrowVault } from '../../contracts/common/interfaces/IBorrowVault.sol';
import { SafeERC20 } from '../../contracts/common/libraries/SafeERC20.sol';
import { IERC20 } from '../../contracts/common/interfaces/IERC20.sol';
import { IERC4626 } from '../../contracts/common/interfaces/IERC4626.sol';
import { IGovernor } from '../../contracts/common/interfaces/IGovernor.sol';
import { console } from 'forge-std/console.sol';
import {
    Loan,
    LoanStorage,
    LoanStateConstants,
    CategoryConstants,
    BASIS_POINTS,
    Collateral,
    Withdraw_collateral
} from '../storages/Loan/LoanStorage.sol';
import { LibLoanModule } from './LibLoanModule.sol';
import { IInterestRate } from '../../contracts/common/interfaces/IInterestRate.sol';

library LibRouter {
    bytes32 constant DIAMOND_STORAGE_OPEN_ROUTER_POSITION = keccak256('diamond.standard.storage.router');

    function _routerStorage() internal pure returns (RouterStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_OPEN_ROUTER_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Deposits an asset into the supply vault and returns the corresponding rToken amount.
    /// @param asset The address of the asset to deposit.
    /// @param amount The amount of the asset to deposit.
    /// @param receiver The address to receive the rTokens.
    /// @return rTokenAmount The amount of rTokens received from the deposit.
    function _deposit(address asset, uint amount, address receiver) internal returns (uint) {
        address diamond = _getGovernor();
        address depositVault = _assertValidDepositVault(diamond, asset);
        ISupplyVault rVault = ISupplyVault(depositVault);

        uint supply_apr = IInterestRate(IGovernor(diamond).getInterestContract()).getSupplyAPR(asset);
        rVault.updateDepositVaultState(supply_apr);

        uint rTokenAmount = rVault.deposit(msg.sender, amount, receiver);
        return rTokenAmount;
    }

    /// @notice Withdraws an asset from the supply vault based on the given rToken shares.
    /// @param asset The address of the asset to withdraw.
    /// @param rTokenShares The amount of rToken shares to redeem.
    /// @param receiver The address to receive the withdrawn asset.
    /// @param owner The address of the owner of the rToken shares.
    /// @return rTokensBurnt The amount of rTokens burnt in the process.
    function _withdrawDeposit(
        address asset,
        uint rTokenShares,
        address receiver,
        address owner
    )
        internal
        returns (uint)
    {
        address diamond = _getGovernor();
        address depositVault = _assertValidDepositVault(diamond, asset);
        address caller = msg.sender;

        require(receiver != address(0), 'Receiver is a zero address');
        require(owner != address(0), 'Owner is a zero address');
        require(caller == owner, 'Owner only');

        ISupplyVault rToken = ISupplyVault(depositVault);
        uint supply_apr = IInterestRate(IGovernor(diamond).getInterestContract()).getSupplyAPR(asset);
        rToken.updateDepositVaultState(supply_apr);

        uint assetAmountToWithdraw = IERC4626(depositVault).previewRedeem(rTokenShares);
        uint rTokensBurnt = ISupplyVault(depositVault).withdraw(caller, assetAmountToWithdraw, receiver, owner);
        return rTokensBurnt;
    }

    /// @notice Requests a loan using collateral by depositing it first.
    /// @param _loanMarket The address of the loan market.
    /// @param _amount The amount of loan requested.
    /// @param _collateralAsset The asset used as collateral.
    /// @param _collateralAmount The amount of collateral to deposit.
    /// @param _recipient The address to receive the loan.
    /// @return loanId The ID of the newly created loan.
    function _loanRequest(
        address _loanMarket,
        uint _amount,
        address _collateralAsset,
        uint _collateralAmount,
        address _recipient
    )
        internal
        returns (uint)
    {
        address diamond = _getGovernor();
        address rToken = _assertValidDepositVault(diamond, _collateralAsset);
        uint rAmount = _deposit(_collateralAsset, _collateralAmount, _recipient);
        uint loanId = _loanRequestWithRToken(_loanMarket, _amount, rToken, rAmount, _recipient);
        return loanId;
    }

    /// @notice Requests a loan with rToken already deposited as collateral.
    /// @param loanMarket The address of the loan market.
    /// @param amount The amount of loan requested.
    /// @param rToken The address of the rToken representing collateral.
    /// @param rAmount The amount of rToken deposited as collateral.
    /// @param recipient The address to receive the loan.
    /// @return loanId The ID of the newly created loan.
    function _loanRequestWithRToken(
        address loanMarket,
        uint amount,
        address rToken,
        uint rAmount,
        address recipient
    )
        internal
        returns (uint loanId)
    {
        RouterStorage storage ds = _routerStorage();

        LibLoanModule._assertSupportedLoanMarket(ds.diamond, loanMarket);

        address dToken = IGovernor(ds.diamond).getDTokenFromAsset(loanMarket);

        uint existingLoanIdInSameCombination = ds.userLoans[recipient][dToken][rToken];

        if (existingLoanIdInSameCombination != 0) {
            (Loan memory loanInfo,) = LibLoanModule._getLoanById(existingLoanIdInSameCombination);
            require(!LibLoanModule._isOpen(loanInfo), 'Loan combination already exists');
        }

        // Min/max checks
        uint minimumLoanAmount = IGovernor(ds.diamond).getMinimumLoanAmount(dToken);
        require(amount >= minimumLoanAmount, 'Amount less than minimum');

        uint maximumLoanAmount = IGovernor(ds.diamond).getMaximumLoanAmount(dToken);
        require(amount <= maximumLoanAmount, 'Amount more than maximum');

        // Update Accumulators
        (uint supply_apr, uint borrow_apr) =
            IInterestRate(LibLoanModule._governorStorage().jumpInterest).getInterestRates(loanMarket);
        ISupplyVault(rToken).updateDepositVaultState(supply_apr);
        IBorrowVault(dToken).updateBorrowVaultState(borrow_apr);

        // Create loan
        loanId = LibLoanModule._preBorrowProcess(loanMarket, amount, rToken, rAmount, recipient);
        LibLoanModule._processLoanRequest(dToken, loanId, amount, rToken, rAmount, recipient, borrow_apr);

        // Update router loan index and user mapping storage
        _updateLoanIndexOnNewLoan(loanId, dToken, rToken, recipient);

        return loanId;
    }

    /// @notice Repays a loan by its ID and returns collateral information.
    /// @param loanId The ID of the loan to repay.
    /// @param repayAmount The amount to repay.
    /// @return Withdraw_collateral memory information about the collateral withdrawn.
    function _repayloanRouter(uint loanId, uint repayAmount) internal returns (Withdraw_collateral memory) {
        return LibLoanModule._repayLoanI(loanId, repayAmount);
    }

    /// @notice Asserts that the specified deposit vault is valid.
    /// @param _diamond The address of the diamond.
    /// @param market The address of the market to validate.
    /// @return rToken The address of the corresponding rToken.
    function _assertValidDepositVault(address _diamond, address market) internal view returns (address) {
        address rToken = IGovernor(_diamond).getRTokenFromAsset(market);
        console.log('rToken', rToken);
        _assertValidRToken(_diamond, rToken);

        return rToken;
    }

    /// @notice Asserts that the specified rToken is valid.
    /// @param _diamond The address of the diamond.
    /// @param rToken The address of the rToken to validate.
    /// @dev Reverts if the rToken is not supported or if the vault is paused.
    function _assertValidRToken(address _diamond, address rToken) internal view {
        DepositVaultMetadata memory vault = IGovernor(_diamond).getDepositVault(rToken);
        require(vault.supported, 'Supply vault not supported');
        require(!vault.paused, 'Supply vault is paused');
    }

    /// @notice Retrieves the diamond address from storage.
    /// @return The address of the diamond.
    function _getGovernor() internal view returns (address) {
        return _routerStorage().diamond;
    }

    /// @notice Updates the loan index when a new loan is created.
    /// @param _loanId The ID of the new loan.
    /// @param _dToken The address of the corresponding dToken.
    /// @param _collateralRToken The address of the collateral rToken.
    /// @param _receiver The address of the loan recipient.
    function _updateLoanIndexOnNewLoan(
        uint _loanId,
        address _dToken,
        address _collateralRToken,
        address _receiver
    )
        internal
    {
        RouterStorage storage ds = _routerStorage();
        uint len = ds.userLoanIdsLen[_receiver];
        ds.userLoanIds[_receiver][len] = _loanId;
        ds.userLoanIdsLen[_receiver] = len + 1;
        ds.userLoans[_receiver][_dToken][_collateralRToken] = _loanId;
        ds.loanIdToDToken[_loanId] = _dToken;
        uint totalLoan = ds.loanRecordsLen++;
        require(totalLoan == _loanId, 'LoanId Incorrect Increment');
    }
}
