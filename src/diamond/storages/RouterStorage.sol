// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct RouterStorage {
    address jumpInterest;
    address diamond;
    // @todo needs to modified as per the BorrowVault vault
    // Number of loan records
    uint loanRecordsLen;
    // Mapping from loan ID to dToken address
    mapping(uint => address) loanIdToDToken;
    // Mapping from user address, asset address, and collateral address to loan ID
    mapping(address => mapping(address => mapping(address => uint))) userLoans;
    // Mapping from user address to number of loan IDs
    mapping(address => uint) userLoanIdsLen;
    // Mapping from user address and index to loan ID
    mapping(address => mapping(uint => uint)) userLoanIds;
    bool initialized;
}
