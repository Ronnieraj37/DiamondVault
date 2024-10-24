// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Loan } from '../../../diamond/storages/Loan/LoanStorage.sol';

interface ILogger {
    function get_loan(uint loan_id) external returns (Loan memory);
}
