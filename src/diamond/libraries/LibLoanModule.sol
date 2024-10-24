// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    Loan,
    LoanStorage,
    LoanStateConstants,
    CategoryConstants,
    BASIS_POINTS,
    Collateral,
    Withdraw_collateral
} from '../storages/Loan/LoanStorage.sol';
import {SecondaryMarket} from "../storages/Governor/GovernorStruct.sol";
import { LoanErrors, BorrowErrors, SpendErrors } from '../../contracts/borrow/implementation/LibErrors.sol';
import { DepositVaultMetadata } from '../storages/Governor/GovernorStruct.sol';
import { Governor } from '../facets/Governor.sol';
import { SafeERC20 } from '../../contracts/common/libraries/SafeERC20.sol';
import { IERC20 } from '../../contracts/common/interfaces/IERC20.sol';
import { console } from 'forge-std/console.sol';
import { Collateral, CollateralStorage } from '../storages/Loan/LoanStorage.sol';

import { RouterStorage } from '../storages/RouterStorage.sol';
import { IInterestRate } from '../../contracts/common/interfaces/IInterestRate.sol';
import { IComptroller } from '../../contracts/common/interfaces/IComptroller.sol';
import { ICollector } from '../../contracts/common/interfaces/ICollector.sol';
import { GovernorStorage } from '../storages/Governor/GovernorStorage.sol';
import { IERC4626 } from '../../contracts/common/interfaces/IERC4626.sol';
import { IPricer } from '../../contracts/common/interfaces/IPricer.sol';

import { ISupplyVault } from '../../contracts/common/interfaces/ISupplyVault.sol';
import { IBorrowVault } from '../../contracts/common/interfaces/IBorrowVault.sol';
import { IGovernor } from '../../contracts/common/interfaces/IGovernor.sol';
import { LibCollateral } from './LibCollateral.sol';
import { LibRouter } from './LibRouter.sol';

import {
    SpendParams,
    RevertSpendParams,
    SwapInfo,
    IntegrationMethod,
    SpendLoanResult,
    RevertLoanResult
} from '../../contracts/integrations/IntegrationStructs.sol';
import { IL3Integration } from '../../contracts/common/interfaces/IL3Integration.sol';

/// @title LibLoanModule
/// @notice Library for managing loans, including borrowing, repayment, and collateral management.
/// @dev This library provides functionality for creating, transferring, spending, and repaying loans.
///      It also includes checks for loan state, collateral, and fees.

library LibLoanModule {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a new loan is created.
    /// @param loan_record The details of the created loan.
    /// @param timestamp The timestamp of when the loan was created.
    event NewLoan(Loan loan_record, uint timestamp);

    /// @notice Emitted when a loan is transferred from one owner to another.
    /// @param loan_id The ID of the loan being transferred.
    /// @param sender The address of the loan's previous owner.
    /// @param receiver The address of the loan's new owner.
    /// @param timestamp The timestamp of when the loan was transferred.
    event LoanTransferred(uint loan_id, address sender, address receiver, uint timestamp);

    /// @notice Emitted when a loan is spent.
    /// @param old_loan_record The state of the loan before it was spent.
    /// @param new_loan_record The state of the loan after it has been spent.
    /// @param timestamp The timestamp of when the loan was spent.
    event LoanSpent(Loan old_loan_record, Loan new_loan_record, uint timestamp);

    /// @notice Emitted when fees are deducted from a loan.
    /// @param fees The amount of fees deducted.
    /// @param fee_market The market from which the fees are deducted.
    /// @param dToken_amount The amount of dTokens involved in the transaction.
    /// @param current_amount_post_fee The current amount after the fees are deducted.
    /// @param timestamp The timestamp of when the fees were deducted.
    event FeeDeducted(uint fees, address fee_market, uint dToken_amount, uint current_amount_post_fee, uint timestamp);

    /// @notice Emitted when a loan is fully repaid.
    /// @param loan_record The state of the loan before repayment.
    /// @param new_loan_record The state of the loan after repayment.
    /// @param totalUserDebt The total user debt after repayment.
    /// @param debtMarket The market associated with the debt.
    event LoanRepaid(Loan loan_record, Loan new_loan_record, uint totalUserDebt, address debtMarket);

    // Storage positions for various components.
    bytes32 constant LOAN_STORAGE_POSITION = keccak256('diamond.standard.storage.loan');
    bytes32 constant COLLATERAL_STORAGE_POSITION = keccak256('diamond.standard.storage.collateral');
    bytes32 constant DIAMOND_STORAGE_OPEN_ROUTER_POSITION = keccak256('diamond.standard.storage.router');
    bytes32 constant GOVERNOR_STORAGE_POSITION = keccak256('diamond.standard.storage.governor');

    /// @notice Returns the router storage.
    /// @return ds The RouterStorage struct from the storage.
    function _routerStorage() internal pure returns (RouterStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_OPEN_ROUTER_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Returns the loan storage.
    /// @return ds The LoanStorage struct from the storage.
    function _loanStorage() internal pure returns (LoanStorage storage ds) {
        bytes32 position = LOAN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Returns the governor storage.
    /// @return ds The GovernorStorage struct from the storage.
    function _governorStorage() internal pure returns (GovernorStorage storage ds) {
        bytes32 position = GOVERNOR_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    ///////////////////////////////////
    ///// Internal View Functions /////
    ///////////////////////////////////

    /// @notice Retrieves loan and collateral information by loan ID.
    /// @param _loanId The ID of the loan.
    /// @return loanInfo The loan information.
    /// @return collateralInfo The collateral information.
    function _getLoanById(uint _loanId) internal view returns (Loan memory loanInfo, Collateral memory collateralInfo) {
        loanInfo = _getLoan(_loanId);
        collateralInfo = LibCollateral._getCollateral(_loanId);
        return (loanInfo, collateralInfo);
    }

    /// @notice Validates that the caller is the owner of the loan.
    /// @param loan_id The ID of the loan.
    /// @dev This function reverts if the caller is not the loan owner.
    function _assertLoanOwnerOnly(uint loan_id) internal view {
        (Loan memory loan, ) = _getLoanById(loan_id);
        address caller = msg.sender;
        if(caller != loan.borrower) revert LoanErrors.Loan__CallerIsNotOwner();
    }

    /// @notice Validates that the provided market is supported for loans.
    /// @param _diamond The diamond address.
    /// @param market The market address.
    /// @dev This function reverts if the market is not supported.
    function _assertSupportedLoanMarket(address _diamond, address market) internal view {
        address dToken = Governor(_diamond).getDTokenFromAsset(market);
        if(dToken == address(0)) revert BorrowErrors.Borrow__LoanMarketNotSupported();
    }

    /// @notice Retrieves the diamond address.
    /// @return The address of the diamond.
    function _getGovernor() internal view returns (address) {
        return _loanStorage().diamond;
    }

    /// @notice Creates a new loan record.
    /// @param loan_id The ID of the loan.
    /// @param recipient The address of the loan recipient.
    /// @param dToken The dToken address.
    /// @param dAmount The amount of dTokens.
    /// @param currentMarket The current market address.
    /// @param currentAmount The current amount associated with the loan.
    /// @return loan A Loan struct representing the new loan.
    function _New(
        uint loan_id,
        address recipient,
        address dToken,
        uint dAmount,
        address currentMarket,
        uint currentAmount
    )
        internal
        view
        returns (Loan memory)
    {
        return Loan(
            loan_id,
            recipient,
            dToken,
            dAmount,
            currentMarket,
            currentAmount,
            LoanStateConstants.LOAN_STATE_ACTIVE,
            address(0),
            CategoryConstants.CATEGORY_UNSPENT,
            block.timestamp
        );
    }

    /// @notice Checks if a loan exists.
    /// @param loan The loan to check.
    /// @return True if the loan exists, false otherwise.
    function _exists(Loan memory loan) internal pure returns (bool) {
        return (loan.timestamp != 0);
    }

    /// @notice Checks if a loan is open.
    /// @param loan The loan to check.
    /// @return True if the loan is open, false otherwise.
    function _isOpen(Loan memory loan) internal pure returns (bool) {
        return _exists(loan)
            && (loan.state == LoanStateConstants.LOAN_STATE_ACTIVE || loan.state == LoanStateConstants.LOAN_STATE_SPENT);
    }

    /// @notice Checks if a loan is spent.
    /// @param loan The loan to check.
    /// @return True if the loan is spent, false otherwise.
    function _isSpent(Loan memory loan) internal pure returns (bool) {
        return (_exists(loan) && (loan.state == LoanStateConstants.LOAN_STATE_SPENT));
    }

    /// @notice Checks if a loan is unspent.
    /// @param loan The loan to check.
    /// @return True if the loan is unspent, false otherwise.
    function _isUnspent(Loan memory loan) internal pure returns (bool) {
        return (_exists(loan) && (loan.state == LoanStateConstants.LOAN_STATE_ACTIVE));
    }

    /// @notice Asserts that the loan is in the expected state.
    /// @param loan The loan to check.
    /// @param state The expected loan state.
    /// @dev This function reverts if the loan is not in the expected state.
    function _assertState(Loan memory loan, LoanStateConstants state) internal pure {
        if (loan.state != state) revert LoanErrors.Loan__InvalidState();
    }

    /// @notice Retrieves a loan record by ID.
    /// @param loan_id The ID of the loan.
    /// @return loan The Loan struct associated with the ID.
    function _getLoan(uint loan_id) internal view returns (Loan memory) {
        return _loanStorage().loan_records[loan_id];
    }

    /// @notice Calculates the health factor of a loan.
    /// @param loan_id The ID of the loan to calculate the health factor for.
    /// @return health_factor The calculated health factor as a uint.
    /// @dev This function retrieves the loan, computes the current USD value of the loan, collateral, and debt,
    /// and then calculates the health factor.
    function _calculateHealthFactor(uint loan_id) internal view returns (uint) {
        Loan memory loan = _getLoan(loan_id);
        if (!_isOpen(loan)) revert LoanErrors.Loan__LoanIsNotOpen();

        IPricer pricer = IPricer(_governorStorage().pricer);

        // Compute current loan value
        uint current_usd = 0;
        if (!_isSpent(loan)) {  
            current_usd = pricer.getAssetBaseValue(loan.current_market, loan.current_amount);
        } else {
            // L3 USD value
            IL3Integration l3_integration = IL3Integration(_governorStorage().l3IntegrationAddress);
            uint8 strategy_id = l3_integration.getStrategyIndex(loan.l3_integration);
            current_usd = l3_integration.getAssetValue(strategy_id, loan.current_amount);
        }

        // Compute collateral value
        Collateral memory collateral = LibCollateral._getCollateral(loan_id);
        address col_underlying = IERC4626(collateral.collateral_market).asset();
        uint col_amount = IERC4626(collateral.collateral_market).previewRedeem(collateral.amount);
        uint collateral_usd = pricer.getAssetBaseValue(col_underlying, col_amount);

        // Compute accrued debt value
        address underlying_debt_asset = IERC4626(loan.borrow_market).asset();
        uint total_debt = IBorrowVault(loan.borrow_market).convertToAssets(loan.amount);
        uint debt_usd = pricer.getAssetBaseValue(underlying_debt_asset, total_debt);

        uint health_factor = ((collateral_usd + current_usd) * 10e18) / debt_usd;
        return health_factor;
    }

    /// @notice Checks if the integration method is a swap.
    /// @param method The method to check.
    /// @return bool Returns true if the method is a swap, false otherwise.
    function _isSwapMethod(IntegrationMethod method) private pure returns (bool) {
        return (IntegrationMethod.Swap == method && IntegrationMethod.RevertSwap != method);
    }

    /// @notice Checks if the integration method is a revert swap.
    /// @param method The method to check.
    /// @return bool Returns true if the method is a revert swap, false otherwise.
    function _isRevertSwapMethod(IntegrationMethod method) private pure returns (bool) {
        return (IntegrationMethod.RevertSwap == method && IntegrationMethod.Swap != method);
    }

    //////////////////////////////
    ///// Internal Functions /////
    //////////////////////////////

    /// @notice Prepares the borrow process by checking collateral and reserves.
    /// @param market The market address.
    /// @param amount The amount to borrow.
    /// @param rToken The rToken address.
    /// @param rTokenAmount The amount of rTokens.
    /// @param recipient The address of the borrower.
    /// @return loan_id The ID of the loan.
    /// @dev This function ensures that enough collateral is provided and that the loan amount does not exceed reserves.
    function _preBorrowProcess(
        address market,
        uint amount,
        address rToken,
        uint rTokenAmount,
        address recipient
    )
        internal
        returns (uint)
    {
        address collateral_underlying_asset = IERC4626(market).asset();
        RouterStorage storage rs = _routerStorage();
        GovernorStorage storage gs = _governorStorage();
        uint loan_id = rs.loanRecordsLen++;
        Loan memory loan = _getLoan(loan_id);

        if (_exists(loan)) revert BorrowErrors.Borrow__LoanExists();

        // Ensure enough collateral with recipient and lock them
        LibCollateral._preAddCollateral(rToken, rTokenAmount, recipient);

        address rtoken_from_asset = Governor(gs.diamond).getRTokenFromAsset(market);
        uint total_deposit_reserves = IERC20(market).balanceOf(rtoken_from_asset);
        uint reserve_factor = IInterestRate(gs.jumpInterest).getInterestRateParameters(market).reserve_factor;

        uint allowed_amount = total_deposit_reserves * reserve_factor / BASIS_POINTS;
        if (amount > allowed_amount) revert BorrowErrors.Borrow__NotEnoughReserves();

        // LTV check
        uint underlying_collateral_amount = IERC4626(rtoken_from_asset).previewRedeem(rTokenAmount);
        uint cdr_permissible = IComptroller(gs.comptrollerContract).checkPermissibleLtv(
            recipient, collateral_underlying_asset, underlying_collateral_amount
        );
        IPricer pricer = IPricer(gs.pricer);
        uint loan_usd = pricer.getAssetBaseValue(market, amount);
        uint collateral_usd = pricer.getAssetBaseValue(collateral_underlying_asset, underlying_collateral_amount);
        uint my_ltv = (loan_usd * 100 / collateral_usd);
        if (my_ltv > cdr_permissible) revert BorrowErrors.Borrow__NotPermissible_CDR();

        return loan_id;
    }

    /// @notice Processes a loan request and creates a loan record.
    /// @param dToken The dToken address.
    /// @param loan_id The ID of the loan.
    /// @param loanAmount The amount of the loan.
    /// @param rToken The rToken address.
    /// @param rTokenAmount The amount of rTokens.
    /// @param recipient The address of the borrower.
    /// @param borrow_apr The APR for borrowing.
    /// @dev This function creates a new loan record and handles associated fees and collateral.
    function _processLoanRequest(
        address dToken,
        uint loan_id,
        uint loanAmount,
        address rToken,
        uint rTokenAmount,
        address recipient,
        uint borrow_apr
    )
        internal
    {
        uint dTokenAmount = IBorrowVault(dToken).convertToDebtTokenWithBorrowAPR(loanAmount, borrow_apr);
        address underlying_asset = IERC4626(dToken).asset();

        ISupplyVault(rToken).transferAssetsToLoanFacet(loan_id, loanAmount);

        Loan memory loan_record = _New(
            loan_id,
            recipient,
            dToken,
            dTokenAmount,
            underlying_asset,
            loanAmount
        );

        uint loan_issuance_fee = IComptroller(_governorStorage().comptrollerContract).getLoanRequestFee();
        uint fee = _createWithFee(loan_record, loan_issuance_fee);
        _deductFee(loan_record, fee);

        // Create collateral record
        LibCollateral._addCollateralWithRTokenI(loan_id, rToken, rTokenAmount, recipient);

        // Mint dTokens

        IBorrowVault(dToken).mint(recipient, dTokenAmount, loanAmount);
    }

    /// @notice Repays a loan and updates the collateral state.
    /// @param loanId The ID of the loan being repaid.
    /// @param repayAmount The amount being repaid.
    /// @return result The result of the repayment process.
    function _repayLoanI(uint loanId, uint repayAmount) internal returns (Withdraw_collateral memory) {
        Loan memory loan = _getLoan(loanId);
        if(!_isOpen(loan)) revert LoanErrors.Loan__LoanIsNotOpen();

        address loanMarket = IGovernor(_getGovernor()).getAssetFromDToken(loan.current_market);
        address rToken = IGovernor(_getGovernor()).getRTokenFromAsset(loanMarket);
        address dToken = _routerStorage().loanIdToDToken[loanId];
        address caller = msg.sender;
        address thisContract = address(this);
        IERC20 interfaceAssetLoanMarket = IERC20(loanMarket);
        // IBorrowVault borrowDispatcher = IBorrowVault(dToken);

        SafeERC20.safeTransferFrom(interfaceAssetLoanMarket, caller, thisContract, repayAmount);
        // SafeERC20.forceApprove(interfaceAssetLoanMarket, dToken, repayAmount);

        // Update Accumulators
        (uint supply_apr,uint borrow_apr) = IInterestRate(LibLoanModule._governorStorage().jumpInterest).getInterestRates(loanMarket);
        ISupplyVault(rToken).updateDepositVaultState(supply_apr);
        IBorrowVault(dToken).updateBorrowVaultState(borrow_apr);

        // Repay loan
        Withdraw_collateral memory result = _repayLoanII(dToken, loan, msg.sender, repayAmount, borrow_apr, caller);

        return result;
    }

    /**
     * @notice Repays a loan on behalf of the borrower.
     * @dev This function updates the loan record and transfers the repayment amount from the caller to the recipient.
     * The function checks if the amount is sufficient to cover the loan repayment and updates the interest accordingly.
     * 
     * @param dToken The address of the dToken associated with the loan.
     * @param loan_record The loan record containing details about the loan being repaid.
     * @param caller The address of the entity initiating the repayment.
     * @param amount The amount of the loan to be repaid.
     * @param borrow_apr The annual percentage rate (APR) for the loan, used to calculate any outstanding interest.
     * @param recipient The address that will receive the repayment.
    ***/
    function _repayLoanII(
        address dToken,
        Loan memory loan_record,
        address caller,
        uint amount,
        uint borrow_apr,
        address recipient
    )
        internal
        returns (Withdraw_collateral memory)
    {
        address underlying_asset = IERC4626(loan_record.borrow_market).asset();
        uint debt_amount = IBorrowVault(dToken).convertToUnderlyingAssetWithBorrowAPR(loan_record.amount, borrow_apr);
        if (debt_amount > amount) revert BorrowErrors.Borrow__InsufficientRepayAmount();
        IERC20(underlying_asset).safeTransferFrom(caller, address(this), debt_amount);

        address rToken = IGovernor(_governorStorage().diamond).getRTokenFromAsset(underlying_asset);
        uint repay_amount_to_deposit_vault =
            ISupplyVault(rToken).getRepayAmountLoanFacet(address(this), loan_record.loan_id);

        if (repay_amount_to_deposit_vault > debt_amount) revert BorrowErrors.Borrow__InvalidRepayFunds();

        IERC20(underlying_asset).approve(rToken, repay_amount_to_deposit_vault);
        ISupplyVault(rToken).repayFromLoanFacet(loan_record.loan_id, repay_amount_to_deposit_vault);

        // burn dTokens

        IBorrowVault(loan_record.borrow_market).redeem(
            loan_record.borrower, recipient, loan_record.amount, debt_amount
        );

        // release rTokens
        Collateral memory collateral = LibCollateral._getCollateral(loan_record.loan_id);
        ISupplyVault(collateral.collateral_market).liquidationTransfer(loan_record.borrower, recipient, collateral.amount);

        // free the locked tokens
        ISupplyVault(collateral.collateral_market).freeLockedRTokens(recipient, collateral.amount);
        LibCollateral._repay(collateral, collateral.amount);

        // deduct fee
        uint loan_repay_fee = IComptroller(_governorStorage().comptrollerContract).getLoanRepayFee();
        // transfer current assets to recipient
        IERC20(loan_record.current_market).safeTransfer(recipient, loan_record.current_amount);

        _repay(loan_record, loan_repay_fee);

        return Withdraw_collateral(
            debt_amount,
            loan_record.current_market,
            loan_record.current_amount,
            loan_record.borrow_market,
            loan_record.amount
        );
    }

    /// @notice Creates a new loan record and emits an event.
    /// @param loan The Loan struct containing loan details.
    /// @dev This function saves the loan record to storage and emits a NewLoan event.
    function _create(Loan memory loan) internal {
        _saveLoanRecord(loan);
        emit NewLoan(loan, block.timestamp);
    }

    /// @notice Creates a loan record and deducts a fee from it.
    /// @param loan The Loan struct containing loan details.
    /// @param fee_basis_points The fee expressed in basis points to deduct.
    /// @return fee The amount of the fee deducted.
    /// @dev This function first deducts the fee and then creates the loan record.
    function _createWithFee(Loan memory loan, uint fee_basis_points) internal returns (uint) {
        uint fee = _deductFee(loan, fee_basis_points);
        _create(loan);
        return fee;
    }

    /// @notice Marks a loan as spent and updates its state.
    /// @param loan The Loan struct to be updated.
    /// @param current_market The market address associated with the loan.
    /// @param current_amount The amount related to the loan's current state.
    /// @param l3_integration The L3 integration address.
    /// @param l3_category The category of the L3 integration.
    /// @dev This function updates the loan state to "spent" and emits a LoanSpent event.
    function _spend(
        Loan memory loan,
        address current_market,
        uint current_amount,
        address l3_integration,
        CategoryConstants l3_category
    )
        internal
    {
        Loan memory old_record = loan;
        loan = _updateCurrentState(loan, current_market, current_amount, l3_integration, l3_category);
        loan.state = LoanStateConstants.LOAN_STATE_SPENT;
        _saveLoanRecord(loan);
        emit LoanSpent(old_record, loan, block.timestamp);
    }

    /// @notice Reverts a loan from spent back to active state.
    /// @param loan The Loan struct to revert.
    /// @param current_market The market address associated with the loan.
    /// @param current_amount The amount related to the loan's current state.
    /// @dev This function updates the loan state back to "active" and emits a LoanSpent event.
    function _revertSpend(Loan memory loan, address current_market, uint current_amount) internal {
        Loan memory old_record = loan;
        loan =
            _updateCurrentState(loan, current_market, current_amount, address(0), CategoryConstants.CATEGORY_UNSPENT);
        loan.state = LoanStateConstants.LOAN_STATE_ACTIVE;
        _saveLoanRecord(loan);
        emit LoanSpent(old_record, loan, block.timestamp);
    }

    /// @notice Repays a loan and deducts a fee in the process.
    /// @param loan The Loan struct being repaid.
    /// @param fee_basis_points The fee expressed in basis points to deduct.
    /// @return fee The amount of the fee deducted.
    /// @dev This function ensures the loan is open, deducts the fee, and marks the loan as repaid.
    function _repay(Loan memory loan, uint fee_basis_points) internal returns (uint) {
        if (!_isOpen(loan)) revert LoanErrors.Loan__LoanIsNotOpen();
        Loan memory old_loan = loan;

        uint fee = _deductFee(loan, fee_basis_points);
        loan = _updateCurrentState(loan, address(0), 0, address(0), CategoryConstants.CATEGORY_UNSPENT);
        loan.state = LoanStateConstants.LOAN_STATE_REPAID;
        loan.amount = 0;
        _saveLoanRecord(loan);
        emit LoanRepaid(old_loan, loan, loan.amount, loan.current_market);
        return fee;
    }

    /// @notice Transfers the ownership of a loan to a new owner.
    /// @param loan The Loan struct to be transferred.
    /// @param new_owner The address of the new loan owner.
    /// @dev This function updates the loan's borrower and emits a LoanTransferred event.
    function _transfer(Loan memory loan, address new_owner) internal {
        loan.borrower = new_owner;
        _saveLoanRecord(loan);
        emit LoanTransferred(loan.loan_id, loan.borrower, new_owner, block.timestamp);
    }

    /// @notice Marks a loan as liquidated.
    /// @param loan The Loan struct to be marked.
    /// @param original_owner The original owner's address.
    /// @dev This function updates the loan's state to "liquidated".
    function _markLiquidated(Loan memory loan, address original_owner) internal {
        loan.borrower = original_owner;
        loan.state = LoanStateConstants.LOAN_STATE_LIQUIDATED;
        _saveLoanRecord(loan);
    }

    /// @notice Updates the current state of a loan.
    /// @param loan The Loan struct to be updated.
    /// @param current_market The current market address.
    /// @param current_amount The current amount associated with the loan.
    /// @param l3_integration The L3 integration address.
    /// @param l3_category The category of the L3 integration.
    /// @return loan The updated Loan struct.
    /// @dev This function modifies the loan's current market, amount, integration, and category.
    function _updateCurrentState(
        Loan memory loan,
        address current_market,
        uint current_amount,
        address l3_integration,
        CategoryConstants l3_category
    )
        internal
        pure
        returns (Loan memory)
    {
        loan.current_market = current_market;
        loan.current_amount = current_amount;
        loan.l3_integration = l3_integration;
        loan.l3_category = l3_category;
        return loan;
    }

    /// @notice Deducts a fee from the loan's current amount.
    /// @param loan The Loan struct from which to deduct the fee.
    /// @param fee_basis_points The fee expressed in basis points to deduct.
    /// @return fee The amount of the fee deducted.
    /// @dev This function updates the loan's current amount and emits a FeeDeducted event.
    function _deductFee(Loan memory loan, uint fee_basis_points) internal returns (uint) {
        uint fee = (loan.current_amount * fee_basis_points) / BASIS_POINTS;
        loan.current_amount = loan.current_amount - fee;
        if (fee > 0) {
            emit FeeDeducted(fee, loan.current_market, loan.amount, loan.current_amount, block.timestamp);
        }
        return fee;
    }

    /// @notice Saves a loan record to storage.
    /// @param loan The Loan struct to be saved.
    /// @dev This function persists the loan record in the loan storage.
    function _saveLoanRecord(Loan memory loan) internal {
        _loanStorage().loan_records[loan.loan_id] = loan;
    }

    /// @notice Interacts with L3 integrations to spend a loan.
    /// @param spend_params The parameters required for spending the loan.
    /// @return return_data The result of the spending operation as a SpendLoanResult struct.
    /// @dev This function performs a swap or adds liquidity based on the method specified in spend_params,
    /// and verifies the loan's health factor after spending.
    function interactWithL3(SpendParams calldata spend_params) internal returns (SpendLoanResult memory) {
        _preInteractWithL3(spend_params);

        IGovernor governor = IGovernor(_getGovernor());
        IL3Integration l3Integration = IL3Integration(_governorStorage().l3IntegrationAddress);
        Loan memory loan = _getLoan(spend_params.loan_id);
        SpendLoanResult memory return_data;
        CategoryConstants spend_category;

        if (_isSwapMethod(spend_params.method)) {
            return_data = l3Integration.swapTokens(spend_params.strategyId, spend_params.swap_info);
            spend_category = CategoryConstants.CATEGORY_SWAP;
        } else {
            return_data = l3Integration.addLiquidity(spend_params.strategyId, loan.current_market, loan.current_amount);
            spend_category = CategoryConstants.CATEGORY_LIQUIDITY;
        }

        // Assert received token is valid
        SecondaryMarket memory secondary_market =
            governor.getSecondaryMarketSupport(return_data.spent_market, spend_params.strategyId);
            if(!secondary_market.supported) revert SpendErrors.Spend__InvallidSpendMarket();
            if(!secondary_market.active) revert SpendErrors.Spend__SpendMarketInactive();

        // Assert min amount out
        if (spend_params.min_amount_out != 0) {
            if(return_data.return_amount < spend_params.min_amount_out) revert SpendErrors.Spend__InsufficientAmountOut();
        }

        _spend(loan,
            return_data.spent_market,
            return_data.return_amount,
            l3Integration.getStrategy(spend_params.strategyId),
            spend_category
        );

        // Assert loan is healthy
        uint hf = _calculateHealthFactor(spend_params.loan_id);
        uint liquidation_call_factor = governor.getLiquidationCallFactor();
        if(hf < liquidation_call_factor) revert BorrowErrors.Borrow__LiquidationCall();
        return return_data;
    }



    /// @notice Prepares for interaction with L3 integrations by validating the loan.
    /// @param spend_params The parameters required for spending the loan.
    /// @dev This function checks that the loan is unspent and deducts the applicable fee.
    function _preInteractWithL3(SpendParams calldata spend_params) internal {
        Loan memory loan_record = _getLoan(spend_params.loan_id);
        if (!_isUnspent(loan_record)) revert LoanErrors.Loan__LoanIsSpent();

        // Deduct fee
        address comptrollerContract = _governorStorage().comptrollerContract;
        uint spend_fee = IComptroller(comptrollerContract).getL3InteractionFee();
        uint fee = _deductFee(loan_record, spend_fee);
        _sendFeesToCollector(loan_record, fee);
    }

    /// @notice Reverts an interaction with L3 integrations.
    /// @param revert_spend_params The parameters required to revert the interaction.
    /// @return return_data The result of the revert operation as a RevertLoanResult struct.
    /// @dev This function performs a revert swap or removes liquidity based on the method specified in revert_spend_params.
    function revertInteractionWithL3(
        RevertSpendParams memory revert_spend_params
    )
        external
        returns (RevertLoanResult memory)
    {
        _preRevertInteractwithL3(revert_spend_params);
        GovernorStorage storage ds = _governorStorage();
        IComptroller comptroller = IComptroller(ds.diamond);
        IL3Integration l3Integration = IL3Integration(ds.l3IntegrationAddress);
        Loan memory loan = _getLoan(revert_spend_params.loan_id);

        RevertLoanResult memory return_data;
        if (_isRevertSwapMethod(revert_spend_params.method)) {
            return_data = l3Integration.revertSwap(revert_spend_params.strategyId, revert_spend_params.swap_info);
        } else {
            if(revert_spend_params.strategyId != l3Integration.getStrategyIndex(loan.l3_integration)) revert SpendErrors.Spend__InvalidStrategy();
            return_data =
                l3Integration.removeLiquidity(revert_spend_params.strategyId, loan.current_market, loan.current_amount);
        }

        // Assert min amount out
        if (revert_spend_params.min_amount_out != 0 && return_data.current_amount < revert_spend_params.min_amount_out) {
            revert SpendErrors.Spend__InsufficientAmountOut();
        }

        // Deduct fee
        uint revert_fee_basis_points = comptroller.getRevertL3InteractionFee();
        uint fee = _deductFee(loan, revert_fee_basis_points);
        _sendFeesToCollector(loan, fee);

        // Update revert loan record
        _revertSpend(loan, return_data.current_market, return_data.current_amount);
        return return_data;
    }

    /// @notice Prepares for a revert interaction with L3 integrations by validating the loan.
    /// @param revertSpendParams The parameters required to revert the interaction.
    /// @dev This function checks that the loan is spent.
    function _preRevertInteractwithL3(RevertSpendParams memory revertSpendParams) internal view {
        Loan memory loan_record = _getLoan(revertSpendParams.loan_id);
        if (_isSpent(loan_record)) revert LoanErrors.Loan__LoanIsSpent();
    }

    /// @notice Deducts a fee from the loan record.
    /// @param loan_record The Loan struct from which to deduct the fee.
    /// @param fee The fee amount to deduct.
    /// @dev This function approves the fee payment and collects it through the comptroller.
    function _sendFeesToCollector(Loan memory loan_record, uint fee) internal {
        address collectorContract = _governorStorage().collectorContract;
        if (fee != 0) {
            SafeERC20.forceApprove(IERC20(loan_record.current_market), collectorContract, fee);
            ICollector(collectorContract).collectFees(loan_record.current_market, fee);
        }
    }
}
