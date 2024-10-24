// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

uint constant BASIS_POINTS = 1e18;

struct BorrowStorage {
    uint last_debt_accrued; // last_debt_activity
    uint outstanding_debt;
    address diamond;
}
