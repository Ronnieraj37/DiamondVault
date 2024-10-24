// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.10;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import {IERC20} from "../common/interfaces/IERC20.sol";
// import {IFlashLoanReceiver} from "../common/interfaces/IFlashLoanSimpleReceiver.sol";
// import {IPool} from "../common/interfaces/IPool.sol";
// import {IBorrowVault} from "../common/interfaces/IBorrowVault.sol";
// import {IGovernor} from "../common/interfaces/IGovernor.sol";
// import {ILoan} from "../common/interfaces/ILoan.sol";
// import {Loan} from "../../diamond/storages/Loan/LoanStorage.sol";

// contract Liquidation is ReentrancyGuard, Pausable, AccessControl, FlashLoanSimpleReceiverBase {
//     bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
//     address public diamond;
//     IPoool public pool;
    
//     event Liquidated(
//         Loan loanRecord,
//         Collateral collateral,
//         address liquidator,
//         uint256 repayAmount,
//         uint256 returnedAmount,
//         uint256 protocolShare,
//         uint256 timestamp
//     );
    
//     event SmartLiquidation(
//         uint256 loanId,
//         address liquidator,
//         bool isProfit,
//         uint256 amountDiff,
//         uint256 timestamp
//     );
    
//     constructor(
//         address _accessControl,
//         address _diamond,
//         address _diamond,
//         IPoolAddressesProvider _addressProvider,
//         address _swapRouter
//     ) FlashLoanSimpleReceiverBase(_addressProvider) {
//         _setupRole(DEFAULT_ADMIN_ROLE, _accessControl);
//         diamond = _diamond;
//         diamond = _diamond;
//         swapRouter = ISwapRouter(_swapRouter);
//     }
    
//     function liquidate(
//         uint256 loanId,
//         SwapInfo memory swapInfo,
//         bytes memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes memory additionalParams
//     ) external nonReentrant whenNotPaused {
//         _liquidate(loanId, swapInfo, revertSpendAllParams, minAmount, additionalParams);
//     }
    
//     function smartLiquidate(
//         uint256 loanId,
//         SwapInfo memory swapInfo,
//         bytes memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes memory additionalParams
//     ) external onlyRole(LIQUIDATOR_ROLE) whenNotPaused {
//         _smartLiquidate(loanId, swapInfo, revertSpendAllParams, minAmount, additionalParams);
//     }
    
//     function isLoanLiquidable(uint256 loanId, bytes memory additionalParams) external view returns (bool) {
//         (Loan memory loanRecord, ) = ILoan(diamond).getLoanById(loanId);
//         uint256 healthFactor = ILoan(loanRecord.market).getHealthFactor(loanId, additionalParams);
//         return healthFactor <= 1.6e18;
//     }
    
//     function selfLiquidate(
//         uint256 loanId,
//         SwapInfo memory swapInfo,
//         bytes memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes memory additionalParams
//     ) external nonReentrant whenNotPaused {
//         (Loan memory loan, Collateral memory collateral) = ILoan(diamond).getLoanById(loanId);
//         require(loan.borrower == msg.sender, "Caller is not loan owner");
//         require(loan.isOpen, "Loan is not active");
        
//         address loanUnderlyingAsset = IGovernor(diamond).getAssetFromDToken(loan.market);
//         uint256 flashAmount = _takeFlashLoan(loan, loanUnderlyingAsset);
        
//         uint256 netAmount =     (
//             loan,
//             collateral,
//             0,
//             msg.sender,
//             flashAmount,
//             swapInfo,
//             revertSpendAllParams,
//             minAmount,
//             additionalParams
//         );
        
//         require(netAmount >= flashAmount, "Insufficient funds to self liquidate");
        
//         address rToken = IGovernor(diamond).getRTokenFromAsset(loanUnderlyingAsset);
//         uint256 amountToRepay = IRToken(rToken).getRepayAmountLoanFacet(address(this), loan.loanId);
//         IERC20(loanUnderlyingAsset).approve(rToken, amountToRepay);
//         IRToken(rToken).repayFromLoanFacet(loan.loanId, amountToRepay);
        
//         uint256 balance = IERC20(loanUnderlyingAsset).balanceOf(address(this));
//         IERC20(loanUnderlyingAsset).transfer(msg.sender, balance);
//     }
    
//     function _smartLiquidate(
//         uint256 loanId,
//         SwapInfo memory swapInfo,
//         bytes memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes memory additionalParams
//     ) internal {
//         address collectorContract = IGovernor(diamond).getCollectorContract();
//         address caller = msg.sender;
        
//         (Loan memory loanRecord, Collateral memory collateral) = ILoan(diamond).getLoanById(loanId);
//         address loanUnderlyingAsset = IGovernor(diamond).getAssetFromDToken(loanRecord.market);
        
//         uint256 loanAmount = _takeFlashLoan(loanRecord, loanUnderlyingAsset);
        
//         (bool isProfit, uint256 amountDiff, , uint256 protocolShare) = _processLiquidation(
//             loanRecord,
//             collateral,
//             100,
//             address(this),
//             loanAmount,
//             swapInfo,
//             revertSpendAllParams,
//             minAmount,
//             additionalParams
//         );
        
//         address rToken = IGovernor(diamond).getRTokenFromAsset(loanUnderlyingAsset);
//         uint256 repayAmount = IRToken(rToken).getRepayAmountLoanFacet(address(this), loanRecord.loanId);
        
//         if (isProfit) {
//             uint256 grossReturn = loanAmount + protocolShare;
//             require(grossReturn > repayAmount, "Flash loan repay amount > gross return");
//             IERC20(loanUnderlyingAsset).approve(rToken, repayAmount);
//             IRToken(rToken).repayFromLoanFacet(loanRecord.loanId, repayAmount);
//             uint256 updatedProtocolShare = grossReturn - repayAmount;
//             IERC20(loanUnderlyingAsset).approve(collectorContract, updatedProtocolShare);
//             ICollector(collectorContract).addLiquidationShare(loanUnderlyingAsset, updatedProtocolShare);
//         } else {
//             uint256 availLiquidationShare = ICollector(collectorContract).availableLiquidationShare(loanUnderlyingAsset);
//             uint256 myAvailable = loanAmount - amountDiff;
//             uint256 loss = repayAmount - myAvailable;
            
//             if (loss <= availLiquidationShare) {
//                 ICollector(collectorContract).requestLiquidationLossCover(loanUnderlyingAsset, amountDiff);
//                 IERC20(loanUnderlyingAsset).approve(rToken, loanAmount);
//                 IRToken(rToken).repayFromLoanFacet(loanRecord.loanId, loanAmount);
//             } else {
//                 uint256 repayableAmount = loanAmount - amountDiff;
//                 IERC20(loanUnderlyingAsset).approve(rToken, repayableAmount);
//                 IRToken(rToken).repayFromLoanFacet(loanRecord.loanId, repayableAmount);
//             }
//         }
        
//         emit SmartLiquidation(loanId, caller, isProfit, amountDiff, block.timestamp);
//     }
    
//     function _liquidate(
//         uint256 loanId,
//         SwapInfo memory swapInfo,
//         bytes memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes memory additionalParams
//     ) internal {
//         address collectorContract = IGovernor(diamond).getCollectorContract();
//         address caller = msg.sender;
        
//         (Loan memory loanRecord, Collateral memory collateral) = IRouter(diamond).getLoanById(loanId);
//         address loanUnderlyingAsset = IGovernor(diamond).getAssetFromDToken(loanRecord.market);
        
//         uint256 loanAmount = IBorrowVault(loanRecord.market).convertToAssets(loanRecord.amount);
//         IERC20(loanUnderlyingAsset).transferFrom(caller, address(this), loanAmount);
        
//         (bool isProfit, uint256 amountDiff, uint256 amountToReturn, uint256 protocolShare) = _processLiquidation(
//             loanRecord,
//             collateral,
//             30,
//             caller,
//             loanAmount,
//             swapInfo,
//             revertSpendAllParams,
//             minAmount,
//             additionalParams
//         );
        
//         IERC20(loanUnderlyingAsset).approve(collectorContract, protocolShare);
//         ICollector(collectorContract).addLiquidationShare(loanUnderlyingAsset, protocolShare);
//         IERC20(loanUnderlyingAsset).transfer(caller, amountToReturn);
//     }
    
//     function _takeFlashLoan(Loan memory loanRecord, address loanUnderlyingAsset) internal returns (uint256) {
//         address rToken = IGovernor(diamond).getRTokenFromAsset(loanUnderlyingAsset);
//         uint256 increaseFactor = IComptroller(diamond).getProtocolThresholdIncreaseFactor();
//         uint256 currentThreshold = IRToken(rToken).getDailyWithdrawalThreshold();
        
//         uint256 newThreshold = (currentThreshold * (100 + increaseFactor)) / 100;
//         IRToken(rToken).setDailyWithdrawalThreshold(newThreshold);
        
//         uint256 loanAmount = IBorrowVault(loanRecord.market).convertToAssets(loanRecord.amount);
        
//         // Perform Aave flash loan
//         bytes memory params = abi.encode(loanRecord.loanId, loanAmount);
//         POOL.flashLoanSimple(address(this), loanUnderlyingAsset, loanAmount, params, 0);
        
//         return loanAmount;
//     }
    
//     function executeOperation(
//         address asset,
//         uint256 amount,
//         uint256 premium,
//         address initiator,
//         bytes calldata params
//     ) external override returns (bool) {
//         // Decode params
//         (uint256 loanId, uint256 loanAmount) = abi.decode(params, (uint256, uint256));
        
//         // Use the flash loaned amount for liquidation
//         address rToken = IGovernor(diamond).getRTokenFromAsset(asset);
//         IRToken(rToken).transferAssetsToBorrowVault(loanId, loanAmount);
        
//         // Approve repayment
//         uint256 amountOwed = amount + premium;
//         IERC20(asset).approve(address(POOL), amountOwed);
        
//         return true;
//     }
    
//     function _closeLoan(
//         Loan memory loanRecord,
//         Collateral memory collateral,
//         uint32 protocolSharePercent,
//         address liquidator,
//         uint256 loanAmount,
//         SwapInfo memory swapInfo,
//         RevertSpendAllParams memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes32[] memory additionalParams
//     ) internal returns (uint256) {
//         address diamond = diamond;
//         address contractAddress = address(this);

//         uint256 loanId = loanRecord.loanId;
//         address originalBorrower = loanRecord.borrower;
//         address collateralAsset = IGovernor(diamond).getAssetFromRToken(collateral.collateralToken);
//         address loanUnderlyingAsset = IGovernor(diamond).getAssetFromDToken(loanRecord.market);

//         // Check if loan is spent
//         bool isSpentLoan = LoanImpl.isSpent(loanRecord);
//         if (isSpentLoan) {
//             IMarket(loanRecord.market).revertInteractionWithL3(revertSpendAllParams);
//         }

//         // Repay loan
//         IERC20(loanUnderlyingAsset).approve(loanRecord.market, loanAmount);
//         (uint256 currentAmount, uint256 collateralAmount) = IMarket(loanRecord.market).repayLoan(loanId, loanAmount, contractAddress);
//         uint256 excess = currentAmount;

//         // Withdraw released rTokens
//         uint256 freedRtokens = collateralAmount;
//         require(freedRtokens == collateral.amount, "Liquidation::free collateral mismatch");
//         uint256 freedCollateral = IRToken(collateral.collateralToken).previewRedeem(freedRtokens);
//         uint256 balBefore = IERC20(collateralAsset).balanceOf(contractAddress);
//         IRToken(collateral.collateralToken).withdraw(freedCollateral, contractAddress, contractAddress);
//         uint256 balAfter = IERC20(collateralAsset).balanceOf(contractAddress);
//         freedCollateral = balAfter.sub(balBefore);

//         // Swap if collateral asset is not the same as loan asset
//         if (collateralAsset != loanUnderlyingAsset) {
//             uint256 convertedCollateral = ISwapRouter(avnuDispatcher).swap(
//                 collateralAsset,
//                 loanUnderlyingAsset,
//                 freedCollateral,
//                 minAmount,
//                 contractAddress,
//                 swapInfo.routes
//             );
//         }

//         uint256 netAssetValue = IERC20(loanUnderlyingAsset).balanceOf(contractAddress);

//         return netAssetValue;
//     }

//     function _processLiquidation(
//         Loan memory loanRecord,
//         Collateral memory collateral,
//         uint32 protocolSharePercent,
//         address liquidator,
//         uint256 loanAmount,
//         SwapInfo memory swapInfo,
//         RevertSpendAllParams memory revertSpendAllParams,
//         uint256 minAmount,
//         bytes32[] memory additionalParams
//     ) internal returns (bool, uint256, uint256, uint256) {
//         uint256 loanId = loanRecord.loanId;
//         address originalBorrower = loanRecord.borrower;

//         // Assert liquidation is valid
//         _preLiquidation(loanRecord, additionalParams);

//         uint256 netAssetValue = _closeLoan(
//             loanRecord,
//             collateral,
//             protocolSharePercent,
//             liquidator,
//             loanAmount,
//             swapInfo,
//             revertSpendAllParams,
//             minAmount,
//             additionalParams
//         );

//         // If profit, compute protocol share and return amount rest to liquidator
//         if (loanAmount <= netAssetValue) {
//             uint256 profit = netAssetValue.sub(loanAmount);
//             (uint256 liquidatorProfitShare, uint256 protocolShare) = _computeProtocolShare(profit, protocolSharePercent);
//             uint256 amountToReturn = loanAmount.add(liquidatorProfitShare);
//             _postLiquidation(
//                 loanId,
//                 originalBorrower,
//                 liquidator,
//                 loanAmount,
//                 amountToReturn,
//                 protocolShare,
//                 loanRecord.market
//             );
//             return (true, profit, amountToReturn, protocolShare);
//         }

//         // Loss condition. Liquidator gets less amount
//         uint256 loss = loanAmount.sub(netAssetValue);
//         uint256 amountToReturn = loanAmount.sub(loss);
//         _postLiquidation(
//             loanId,
//             originalBorrower,
//             liquidator,
//             loanAmount,
//             amountToReturn,
//             0,
//             loanRecord.market
//         );
//         return (false, loss, amountToReturn, 0);
//     }

//     function _postLiquidation(
//         uint256 loanId,
//         address originalBorrower,
//         address liquidator,
//         uint256 repayAmount,
//         uint256 returnedAmount,
//         uint256 protocolShare,
//         address dToken
//     ) internal {
//         uint256 blockTimestamp = block.timestamp;
//         2(dToken).markLiquidation(loanId, originalBorrower);
//         (Loan memory newLoan, Collateral memory newCollateral) = IRouter(diamond).getLoanById(loanId);
//         emit Liquidated(
//             newLoan,
//             newCollateral,
//             liquidator,
//             repayAmount,
//             returnedAmount,
//             protocolShare,
//             blockTimestamp
//         );
//     }

//     function _computeProtocolShare(uint256 profit, uint32 protocolShare) internal pure returns (uint256, uint256) {
//         uint256 protocolShareAmount = (profit * protocolShare) / 100;
//         uint256 userShare = profit - protocolShareAmount;
//         return (userShare, protocolShareAmount);
//     }
// }