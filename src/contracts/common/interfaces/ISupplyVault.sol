// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

interface ISupplyVault {
    function deposit(address sender, uint amount,address receiver) external returns(uint);
    function withdraw(
        address caller,
        uint assets,
        address receiver,
        address owner
    )
        external returns(uint);
    function lockRTokens(address, uint) external;
    function freeLockedRTokens(address, uint) external;
    function transferAssetsToLoanFacet(uint, uint) external;
    function liquidationTransfer(address, address, uint) external;
    function repayFromLoanFacet(uint, uint) external;

    function updateDepositVaultState(uint) external;
    function setDailyWithdrawalThreshold(uint) external;
    function setMintSnapshotReserves(uint) external;
    function exchangeRate() external returns (uint, uint);
    function unaccruedTotalAssets() external returns (uint);
    function totalLentAssets() external returns (uint);
    function rTokenIncentive() external returns (uint);
    function getFreeRTokens(address) external returns (uint);
    function getRepayAmountLoanFacet(address, uint) external returns (uint);
    function incentiveAccruedInterest() external returns (uint);
    function accruedInterest() external returns (uint);
    function unaccruedTotalSupply() external returns (uint);
    function getNextWithdrawalResetTime() external returns (uint64);
    function getDepositReservesSnapshot() external returns (uint);
    function getDailyWithdrawalThreshold() external returns (uint);
    function getMinSnapshotReserves() external returns (uint);
}