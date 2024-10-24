// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { DepositVaultMetadata, BorrowVaultMetadata, AssetMetadata, SecondaryMarket } from './GovernorStruct.sol';

struct GovernorStorage {
    mapping(address => DepositVaultMetadata) depositVaultMetadata;
    mapping(uint => address) depositVaultIndexToRToken;
    uint depositVaultsLen;
    mapping(address => BorrowVaultMetadata) borrowVaultMetadata;
    mapping(uint => address) borrowVaultIndexToDToken;
    uint borrowVaultsLen;
    mapping(address => AssetMetadata) assetMetadata;
    mapping(uint => address) assetMetadataIndexToAsset;
    uint assetMetadataLen;
    mapping(address => mapping(uint => SecondaryMarket)) secondaryMarketSupport;
    mapping(uint => mapping(uint => uint)) integrationMapping;
    mapping(uint => mapping(uint => bool)) categoryAndFunctionTypeAllowed;
    address stakingContract;
    address collectorContract;
    address jumpInterest;
    address comptrollerContract;
    address l3IntegrationAddress;
    address liquidationBaseMarket;
    address accessRegistryContract;
    address diamond;
    address pricer;
    bool initialized;
}
