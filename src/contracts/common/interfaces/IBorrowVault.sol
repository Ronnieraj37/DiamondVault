// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrowVault {
    function updateBorrowVaultState(uint256 borrow_apr) external ;
    function getUnderlyingDebt() external view returns (uint);
    function convertToAssets(uint shares) external view returns (uint);
    function convertToDebtTokenWithBorrowAPR(uint loanamount, uint borrowAPR) external view returns (uint);
    function convertToUnderlyingAssetWithBorrowAPR(uint loanAmount, uint borrowApr) external view returns (uint);
    function mint(address recipient, uint dTokens, uint loanAmount) external;
    function redeem(address owner, address receiver, uint dTokens, uint loanAmount) external;
}
