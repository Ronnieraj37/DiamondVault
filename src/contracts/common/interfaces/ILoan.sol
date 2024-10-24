// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Loan } from '../../../diamond/storages/Loan/LoanStorage.sol';

interface ILoan {
    function get_loan(uint loan_id) external returns (Loan memory);
    function exists(Loan memory loan) external pure returns (bool);
    function is_unspent(Loan memory loan) external view returns (bool);
}
