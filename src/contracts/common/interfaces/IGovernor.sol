// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

import {
    SecondaryMarket,
    AssetMetadata,
    BorrowVaultMetadata,
    DepositVaultMetadata
} from '../../../diamond/storages/Governor/GovernorStruct.sol';

interface IGovernor {
    ////////////////////////
    /// External Functions //
    ////////////////////////

    function setDepositVault(
        address rToken,
        address asset,
        bool supported,
        bool paused,
        bool stakingPaused,
        uint minDepositAmount,
        uint maxDepositAmount
    )
        external;

    function setBorrowVault(
        address dToken,
        address asset,
        bool paused,
        bool supported,
        uint minBorrow,
        uint maxBorrow
    )
        external;

    function setAssetMetadata(address asset, address rToken, address dToken, bytes32 empiricKey) external;

    function setSecondaryMarketSupport(
        address _address,
        bytes32 integration,
        bool isSupported,
        bool isActive
    )
        external;

    function setIntegrationSelectorMapping(bytes32 integration, bytes32 method, bytes32 selector) external;

    function setStakingContract(address stakingContract) external;

    function setCollectorContract(address collectorContract) external;

    function setCategoryAndFunctionTypeAllowed(bytes32 integration, bytes32 selector, bool isAllowed) external;

    function setIntegrationContractAddress(address _address) external;

    function setLiquidationBaseMarket(address asset) external;

    function setComptroller(address _address) external;

    function setRouter(address _address) external;

    function setInterestContract(address _address) external;

    ////////////////////////
    /// View Functions //////
    ////////////////////////

    function getLiquidationCallFactor() external view returns (uint);
    function isDVaultPaused(address asset) external view returns (bool);

    function isStakePaused(address asset) external view returns (bool);

    function getDepositVaultByIndex(uint index) external view returns (address, DepositVaultMetadata memory);

    function getDepositVault(address rToken) external view returns (DepositVaultMetadata memory);

    function getMinimumDepositAmount(address rToken) external view returns (uint);

    function getMaximumDepositAmount(address rToken) external view returns (uint);

    function getMinimumLoanAmount(address dToken) external view returns (uint);

    function getMaximumLoanAmount(address dToken) external view returns (uint);

    function getDepositVaultsLen() external view returns (uint);

    function getBorrowVault(address dToken) external view returns (BorrowVaultMetadata memory);

    function isDVaultSupported(address dToken) external view returns (bool);

    function getBorrowVaultByIndex(uint index) external view returns (address, BorrowVaultMetadata memory);

    function getBorrowVaultsLen() external view returns (uint);

    function getAssetMetadata(uint index) external view returns (address, AssetMetadata memory);

    function getMetadata(address asset) external view returns (AssetMetadata memory);

    function getSecondaryMarketSupport(
        address _address,
        uint8 strategyId
    )
        external
        view
        returns (SecondaryMarket memory);

    function getIntegrationSelectorMapping(bytes32 integration, bytes32 method) external view returns (bytes32);

    function getAssetMetadataLen() external view returns (uint);

    function getLoansLen() external view returns (uint);

    function getRTokenFromAsset(address asset) external view returns (address);

    function getAssetFromRToken(address rToken) external view returns (address);

    function getDTokenFromAsset(address asset) external view returns (address);

    function getAssetFromDToken(address dToken) external view returns (address);

    function getStakingContract() external view returns (address);

    function getCollectorContract() external view returns (address);

    function getCategoryAndFunctionTypeAllowed(bytes32 integration, bytes32 selector) external view returns (bool);

    function getIntegrationContractAddress() external view returns (address);

    function getLiquidationBaseMarket() external view returns (address);

    function getComptroller() external view returns (address);

    function getRouter() external view returns (address);

    function getCollector() external view returns (address);

    function getInterestContract() external view returns (address);
}

// Add any required structs or additional contracts here
// struct DepositVaultMetadata {
//     bool supported;
//     bool paused;
//     bool stakingPaused;
//     uint256 minDepositAmount;
//     uint256 maxDepositAmount;
// }

// struct BorrowVaultMetadata {
//     bool paused;
//     bool supported;
//     uint256 minBorrow;
//     uint256 maxBorrow;
// }

// struct AssetMetadata {
//     address rToken;
//     address dToken;
//     bytes32 empiricKey;
// }

// struct SecondaryMarket {
//     bool isSupported;
//     bool isActive;
// }
