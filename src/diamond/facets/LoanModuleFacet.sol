// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
pragma solidity ^0.8.0;

import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { LibLoanModule } from '../libraries/LibLoanModule.sol';
import { RouterStorage } from '../storages/RouterStorage.sol';
import { Context } from '../../contracts/common/libraries/Context.sol';
import { console } from 'forge-std/console.sol';
import { IAccessRegistry } from '../../contracts/common/interfaces/IAccessRegistry.sol';
import { LibRouter } from '../libraries/LibRouter.sol';
import { LibCollateral } from '../libraries/LibCollateral.sol';
import {
    Loan,
    LoanStorage,
    LoanStateConstants,
    CategoryConstants,
    BASIS_POINTS,
    Collateral,
    Withdraw_collateral
} from '../storages/Loan/LoanStorage.sol';

contract LoanModuleFacet is ReentrancyGuard {
    bytes32 private constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN');

    error LoanFacet_InputZeroValue();

    modifier notZero(uint value) {
        if (value == 0) revert LoanFacet_InputZeroValue();
        _;
    }

    function initializeOpenRouter(address _diamond) external {
        RouterStorage storage ds = LibRouter._routerStorage();
        require(!ds.initialized, 'Already initialized');
        ds.diamond = _diamond;
        ds.initialized = true;
    }

    /// @notice Initiates a deposit request and mint rTokens
    /// @param _asset Address of the asset to be deposited
    /// @param _amount Amount of asset to be deposited
    /// @param _receiver Address of the receiver
    /// @return rShares Returns amount of rToken to be minted the receiver

    function deposit(address _asset, uint _amount, address _receiver) external nonReentrant returns (uint rShares) {
        // console.log('Deposit here: ');
        rShares = LibRouter._deposit(_asset, _amount, _receiver);
    }

    /// @notice Withdraws the deposited assets from the deposit vault
    /// @param _asset Address of the asset
    /// @param _rTokenShares Amount of rTokens to be withdrawn
    /// @param _receiver Address of the receiver of deposit
    /// @param _owner Address of the owner of rTokens
    /// @return asset Returns the amount of asset

    function withdrawDeposit(
        address _asset,
        uint _rTokenShares,
        address _receiver,
        address _owner
    )
        external
        nonReentrant
        returns (uint asset)
    {
        asset = LibRouter._withdrawDeposit(_asset, _rTokenShares, _receiver, _owner);
    }

    function loanRequest(
        address asset,
        uint amount,
        address collateralAsset,
        uint collateralAmount,
        address recipient
    )
        external
        nonReentrant
        returns (uint loanId)
    {
        // check for the vault should not Paused
        loanId = LibRouter._loanRequest(asset, amount, collateralAsset, collateralAmount, recipient);
        return loanId;
    }

    function loanRequestWithRToken(
        address asset,
        uint amount,
        address rToken,
        uint rTokenAmount,
        address recipient
    )
        public
        nonReentrant
        returns (uint loanId)
    {
        // security.assertNotPaused();
        require(msg.sender == recipient, 'Caller should be the recipient');
        loanId = LibRouter._loanRequestWithRToken(asset, amount, rToken, rTokenAmount, recipient);
        return loanId;
    }

    function addCollateral(
        uint loanId,
        address collateralAsset,
        uint collateralAmount
    )
        external
        notZero(collateralAmount)
        nonReentrant
    {
        LibCollateral._addCollateralWithAsset(loanId, collateralAsset, collateralAmount);
    }

    function addRTokenCollateral(uint loanId, address rToken, uint rTokenAmount, address owner) external nonReentrant {
        LibCollateral._addCollateralWithRTokenI(loanId, rToken, rTokenAmount, owner);
    }

    function repay_loan(
        uint loan_id,
        uint repay_amount
    )
        external
        nonReentrant
        returns (Withdraw_collateral memory result)
    {
        //@todo Check Not Paused
        LibLoanModule._assertLoanOwnerOnly(loan_id);
        return LibRouter._repayloanRouter(loan_id, repay_amount);
    }

    function getDiamond() external view returns (address) {
        return LibRouter._getGovernor();
    }

    function getLoansLen() external view returns (uint) {
        return LibRouter._routerStorage().loanRecordsLen;
    }

    function exists(Loan memory loan) external pure returns (bool) {
        return LibLoanModule._exists(loan);
    }

    function isOpen(Loan memory loan) external pure returns (bool) {
        return LibLoanModule._isOpen(loan);
    }

    function isSpent(Loan memory loan) external pure returns (bool) {
        return LibLoanModule._isSpent(loan);
    }

    function getLoan(uint loan_id) external view returns (Loan memory) {
        return LibLoanModule._getLoan(loan_id);
    }

    function spend(
        Loan memory loan,
        address current_market,
        uint current_amount,
        address l3_integration,
        CategoryConstants l3_category
    )
        external
    {
        LibLoanModule._spend(loan, current_market,current_amount,l3_integration,l3_category);
    }

    function revert_spend(Loan memory loan, address current_market, uint current_amount) external {
        LibLoanModule._revertSpend(loan,current_market,current_amount);

    }
}
