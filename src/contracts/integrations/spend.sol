// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Collateral, CategoryConstants } from '../borrow/storage/BorrowStructs.sol';
// import { Loan } from '../../diamond/storages/Loan/LoanStorage.sol';
// import { LoanErrors } from '../borrow/implementation/LibErrors.sol';
// import { ILoan } from '../common/interfaces/ILoan.sol';
// import { IGovernor } from '../common/interfaces/IGovernor.sol';
// import { IPricer } from '../common/interfaces/IPricer.sol';
// import { IERC4626 } from '../common/interfaces/IERC4626.sol';
// import { ISupply } from '../common/interfaces/ISupply.sol';
// import { IBorrowVault } from '../common/interfaces/IBorrowVault.sol';
// import {
//     SpendParams,
//     RevertSpendParams,
//     SwapInfo,
//     IntegrationMethod,
//     SpendLoanResult,
//     RevertLoanResult
// } from './IntegrationStructs.sol';

// contract temp {
//     error Spend__InvalidIntegrationMethod();

//     function _calculateHealthFactor(uint loan_id) public returns (uint) {
//         IGovernor governor = IGovernor(governor_address);
//         Loan memory loan = governor.get_loan(loan_id);
//         if (!loan.is_open()) revert LoanErrors.Loan__LoanIsNotOpen();

//         IPricer pricer = governor.getPricer();

//         // compute current loan value
//         uint current_usd = 0;
//         if (!loan.isSpent()) {
//             current_usd = price.getAssetBaseValue(loan.current_market, loan.current_amount);
//         } else {
//             // l3 usd value
//             IL3Integration l3_integration = governor.get_integration_contract_address();
//             uint8 strategy_id = l3_integration.getStrategyIndex(loan.l3_integration);
//             current_usd = l3_integration.getAssetValue(strategy_id, loan.current_amount);
//         }

//         // compute col value
//         Collateral collateral = governor.getCollateral(loan_id);
//         address col_underlying = IERC4626(collateral.collateral_token).asset();
//         uint col_amount = IERC4626(collateral.collateral_token).previewRedeem(collateral.amount);
//         uint collateral_usd = pricer.getAssetBaseValue(col_underlying, col_amount);

//         // compute accrued debt value
//         address underlying_debt_asset = IERC4626(loan.borrow_market).asset();
//         uint total_debt = IBorrowVault(loan.borrow_market).convertToAssets(loan.amount);
//         uint debt_usd = pricer.getAssetBaseValue(underlying_debt_asset, total_debt);

//         uint health_factor = ((collateral_usd + current_usd) * 10e18) / debt_usd;
//         return health_factor;
//     }

//     function interactWithL3(
//         SpendParams calldata spend_params
//     )
//         external
//         returns (
//             // onlyOpenRole
//             // whenNotPaused
//             // nonReentrant
//             SpendLoanResult memory
//         )
//     {
//         _preInteractWithL3(spend_params);
//         IGovernor governor = IGovernor(governor_address);
//         IL3Integration l3Integration = IL3Integration(l3_integration_router);
//         Loan memory loan = governor.get_loan(spend_params.loan_id);
//         // spend loan
//         SpendLoanResult memory return_data;
//         CategoryConstants spend_category;
//         if (_isSwapMethod(spend_params.method)) {
//             return_data = l3Integration.swapTokens(spend_params.strategyId, spend_params.swap_info);
//             spend_category = CategoryConstants.CATEGORY_SWAP;
//         } else {
//             return_data = l3_integration.addLiquidity(spend_params.strategyId, loan.current_market, loan.current_amount);
//             spend_category = CategoryConstants.CATEGORY_LIQUIDITY;
//         }

//         // assert received token is valid
//         address secondary_market =
//             governor.getSecondaryMarketSupport(return_data.return_market, spend_params.strategyId);
//         require(secondary_market.supported, 'BorrowVault:: Invalid secondary mkt');
//         require(secondary_market.active, 'BorrowVault:: spend market inactive');

//         // assert min amount out
//         if (spend_params.min_amount_out != 0) {
//             require(return_data.return_amount >= spend_params.min_amount_out, 'Spend: Insufficient amount out');
//         }

//         loan_record.spend(
//             return_data.return_market, return_data.return_amount, l3_integration.getStrategy(strategyId), spend_category
//         );

//         // assert loan is healthy
//         uint hf = _calculateHealthFactor(spend_params.loan_id);
//         uint liquidation_call_factor = governor.getLiquidationCallFactor();
//         //// println!("BorrowVault: hf: {:?}", hf);
//         require(hf > liquidation_call_factor, 'BorrowVault: Liquidation call');
//         return return_data;
//     }

//     function _isSwapMethod(IntegrationMethod method) private returns (bool) {
//         return (IntegrationMethod.Swap == method && IntegrationMethod.RevertSwap != method);
//     }

//     function _isRevertSwapMethod(IntegrationMethod method) private returns (bool) {
//         return (IntegrationMethod.RevertSwap == method && IntegrationMethod.Swap != method);
//     }

//     function _preInteractWithL3(SpendParams calldata spend_params) internal {
//         // (Check protocol ops for the integrationDapp != paused)
//         // assert valid loan
//         ILogger logger = ILogger(spend_storage()._logger);
//         Loan loan_record = logger.get_loan(spend_params.loan_id);
//         if (!logger.is_unspent(loan_record)) revert LoanErrors.Loan__LoanIsSpent();

//         assert(function_selector != 0, 'BorrowVault:: Invalid L3 selector');

//         // deduct fee
//         uint spend_fee = logger.getL3InteractionFee();
//         uint fee = loanState.sendFeesToCollector(loan_record, spend_fee);
//         _deductFee(loan_record, fee);
//     }

//     function revertInteractionWithL3(
//         RevertSpendParams memory revert_spend_params
//     )
//         external
//         returns (
//             // onlyOpenRole
//             // whenNotPaused
//             // nonReentrant
//             RevertLoanResult memory
//         )
//     {
//         // pre revert interact with l3 checks
//         _preRevertInteractwithL3(revert_spend_params);
//         IGovernor governor = IGovernor(governor_address);
//         IL3Integration l3Integration = IL3Integration(l3_integration_router);
//         Loan memory loan = governor.get_loan(revert_spend_params.loan_id);

//         RevertLoanResult memory return_data;
//         if (_isRevertSwapMethod(revert_spend_params.method)) {
//             return_data = l3Integration.revertSwapTokens(revert_spend_params.strategyId, spend_params.swap_info);
//         } else {
//             require(
//                 revert_spend_params.strategyId == l3_integration.getStrategyIndex(loan.l3_integration),
//                 'Borrow__InvalidStrategy'
//             );
//             return_data =
//                 l3Integration.removeLiquidity(revert_spend_params.strategyId, loan.current_market, loan.current_amount);
//         }

//         // assert min amount out
//         if (revert_spend_params.min_amount_out != 0) {
//             require(return_data.return_amount >= revert_spend_params.min_amount_out, 'Revert: Insufficient amount out');
//         }

//         // deduct fee
//         uint revert_fee_basis_points = governor.getRevertL3InteractionFee();
//         uint fee = loan.sendFeesToCollector(revert_fee_basis_points);
//         _deductFee(fee);
//         // update revert loan record
//         loan.revert_spend(return_data.return_market, return_data.return_amount);
//         return return_data;
//     }

//     function _preRevertInteractwithL3(RevertSpendParams revertSpendParams) internal {
//         // (Check protocol ops for the integrationDapp != paused)
//         // assert valid loan
//         ILogger logger = ILogger(spend_storage()._logger);
//         Loan loan_record = logger.get_loan(spend_params.loan_id);
//         if (logger.isSpent(loan_record)) revert LoanErrors.Loan__LoanIsSpent();
//     }
// }
