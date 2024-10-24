// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct SupplyVaultStorage {
    uint lentAssets;
    uint lastTimeAccrued;
    mapping(address => mapping(uint => uint)) lentLoansRTokens;
    mapping(address => uint) lockedRTokens;
    uint64 dialyWithdrawalThreshold;
    uint64 nextWithdrawLimitResetTime;
    address governor;
    uint depositReservesSnapshot;
    uint minSnapshotReserve;
}

// uint256 deposit_reserves_snapshot;