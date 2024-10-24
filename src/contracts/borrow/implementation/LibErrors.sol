// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LoanErrors {
    error Loan__InvalidState();
    error Loan__LoanIsNotOpen();
    error Loan__LoanIsSpent();
    error Loan__LoanIsNotSpent();
    error Loan__CallerIsNotOwner();
}

library BorrowErrors {
    error Borrow__LoanExists();
    error Borrow__NotEnoughReserves();
    error Borrow__NotPermissible_CDR();
    error Borrow__InsufficientRepayAmount();
    error Borrow__InvalidRepayFunds();
    error Borrow__NotEnoughCollateral();
    error Borrow__CollateralMismatch();
    error Borrow__LoanIsNotOpen();
    error Borrow__LoanMarketNotSupported();
    error Borrow__LiquidationCall();
}

library SpendErrors {
    error Spend__InvalidStrategy();
    error Spend__InsufficientAmountOut();
    error Spend__InvallidSpendMarket();
    error Spend__SpendMarketInactive();
}
