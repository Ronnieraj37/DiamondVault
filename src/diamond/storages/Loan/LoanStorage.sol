// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum LoanStateConstants {
    LOAN_STATE_ACTIVE,
    LOAN_STATE_SPENT,
    LOAN_STATE_REPAID,
    LOAN_STATE_LIQUIDATED
}

uint constant BASIS_POINTS = 100_000;

enum CategoryConstants {
    CATEGORY_UNSPENT,
    CATEGORY_SWAP,
    CATEGORY_LIQUIDITY
}

struct Loan {
    uint loan_id;
    address borrower;
    address borrow_market;
    uint amount;
    address current_market;
    uint current_amount;
    LoanStateConstants state;
    address l3_integration;
    CategoryConstants l3_category;
    uint timestamp;
}

struct LoanStorage {
    address diamond;
    mapping(uint => Loan) loan_records;
}

struct Withdraw_collateral {
    uint repaid_debt;
    address current_market;
    uint current_amount;
    address collateral_market;
    uint collateral_amount;
}

struct Collateral {
    uint loan_id;
    address collateral_market;
    uint amount;
    uint timestamp;
}

struct CollateralStorage {
    mapping(address => uint) net_collaterals; //uint -> collateral id.
    mapping(uint => Collateral) collateral_records;
}
