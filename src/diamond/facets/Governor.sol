// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { GovernorStorage } from '../storages/Governor/GovernorStorage.sol';
import { IAccessRegistry } from '../../contracts/common/interfaces/IAccessRegistry.sol';
import {
    DepositVaultMetadata,
    BorrowVaultMetadata,
    AssetMetadata,
    SecondaryMarket
} from '../storages/Governor/GovernorStruct.sol';
import { console } from 'forge-std/console.sol';

contract Governor {
    bytes32 private constant DIAMOND_STORAGE_GOVERNOR_POSITION = keccak256('diamond.standard.storage.goveror');
    bytes32 private constant OPEN_ROLE = keccak256('OPEN_ROLE');
    bytes32 private constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN_ROLE');

    /**
     * @dev Emitted when a deposit vault is set.
     * @param rToken The address of the rToken.
     * @param metadata The metadata of the deposit vault.
     */
    event DepositVaultSet(address indexed rToken, DepositVaultMetadata metadata);

    /**
     * @dev Emitted when a borrow vault is set.
     * @param dToken The address of the dToken.
     * @param metadata The metadata of the borrow vault.
     */
    event BorrowVaultSet(address indexed dToken, BorrowVaultMetadata metadata);

    /**
     * @dev Emitted when asset metadata is set.
     * @param asset The address of the asset.
     * @param metadata The metadata of the asset.
     */
    event AssetMetadataSet(address indexed asset, AssetMetadata metadata);

    /**
     * @dev Emitted when secondary market support is set.
     * @param market The address of the market.
     * @param integration The integration ID.
     * @param support The secondary market support information.
     */
    event SecondaryMarketSupportSet(address indexed market, uint integration, SecondaryMarket support);

    error INVALID_ACCESS();

    modifier onlyGovernorRole(address _check) {
        address accessControl = getAccessRegistry();
        console.log('accessControl:', accessControl);

        if (!IAccessRegistry(accessControl).hasRole(OPEN_ROLE, _check)) {
            revert INVALID_ACCESS();
        }
        _;
    }

    modifier notZero(address check) {
        if (check == address(0)) {
            revert INVALID_ACCESS();
        }
        _;
    }

    function _governorStorage() internal pure returns (GovernorStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_GOVERNOR_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @dev Initializes the Governor contract with an access registry contract.
     * @param _accessRegistryContract The address of the access registry contract.
     */
    function initializeGovernor(address _accessRegistryContract) external notZero(_accessRegistryContract) {
        GovernorStorage storage govStorage = _governorStorage();
        require(!govStorage.initialized, 'Already Initialized');
        govStorage.accessRegistryContract = _accessRegistryContract;
        govStorage.initialized = true;
    }

    /**
     * @dev Updates the access registry contract address.
     * @param _newAccessRegistryContract The new access registry contract address.
     */
    function updateAccessRegistry(address _newAccessRegistryContract)
        external
        notZero(_newAccessRegistryContract)
        onlyGovernorRole(msg.sender)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.accessRegistryContract = _newAccessRegistryContract;
    }

    /**
     * @dev Sets the deposit vault metadata.
     * @param rToken The address of the rToken.
     * @param asset The address of the asset.
     * @param supported Whether the deposit vault is supported.
     * @param paused Whether the deposit vault is paused.
     * @param stakingPaused Whether staking is paused.
     * @param minDepositAmount The minimum deposit amount allowed.
     * @param maxDepositAmount The maximum deposit amount allowed.
     */
    function setDepositVault(
        address rToken,
        address asset,
        bool supported,
        bool paused,
        bool stakingPaused,
        uint minDepositAmount,
        uint maxDepositAmount
    )
        external
        onlyGovernorRole(msg.sender)
        notZero(rToken)
        notZero(asset)
    {
        GovernorStorage storage govStorage = _governorStorage();

        DepositVaultMetadata memory metadata = DepositVaultMetadata({
            asset: asset,
            supported: supported,
            paused: paused,
            stakingPaused: stakingPaused,
            minDepositAmount: minDepositAmount,
            maxDepositAmount: maxDepositAmount
        });

        govStorage.depositVaultMetadata[rToken] = metadata;

        if (govStorage.depositVaultMetadata[rToken].asset == address(0)) {
            govStorage.depositVaultIndexToRToken[govStorage.depositVaultsLen] = rToken;
            govStorage.depositVaultsLen++;
        }

        emit DepositVaultSet(rToken, metadata);
    }

    /**
     * @dev Sets the borrow vault metadata.
     * @param dToken The address of the dToken.
     * @param asset The address of the asset.
     * @param paused Whether the borrow vault is paused.
     * @param supported Whether the borrow vault is supported.
     * @param minBorrow The minimum borrow amount allowed.
     * @param maxBorrow The maximum borrow amount allowed.
     */
    function setBorrowVault(
        address dToken,
        address asset,
        bool paused,
        bool supported,
        uint minBorrow,
        uint maxBorrow
    )
        external
        onlyGovernorRole(msg.sender)
        notZero(dToken)
        notZero(asset)
    {
        GovernorStorage storage govStorage = _governorStorage();
        BorrowVaultMetadata memory metadata = BorrowVaultMetadata({
            asset: asset,
            supported: supported,
            paused: paused,
            minBorrowAmount: minBorrow,
            maxBorrowAmount: maxBorrow
        });

        govStorage.borrowVaultMetadata[dToken] = metadata;

        if (govStorage.borrowVaultMetadata[dToken].asset == address(0)) {
            govStorage.borrowVaultIndexToDToken[govStorage.borrowVaultsLen] = dToken;
            govStorage.borrowVaultsLen++;
        }

        emit BorrowVaultSet(dToken, metadata);
    }

    /**
     * @dev Sets the asset metadata.
     * @param asset The address of the asset.
     * @param rToken The address of the rToken.
     * @param dToken The address of the dToken.
     * @param empiricKey The empiric key associated with the asset.
     */
    function setAssetMetadata(
        address asset,
        address rToken,
        address dToken,
        uint empiricKey
    )
        external
        onlyGovernorRole(msg.sender)
        notZero(asset)
        notZero(rToken)
        notZero(dToken)
    {
        GovernorStorage storage govStorage = _governorStorage();
        AssetMetadata memory metadata = AssetMetadata({ rToken: rToken, dToken: dToken, empiricKey: empiricKey });

        govStorage.assetMetadata[asset] = metadata;

        if (govStorage.assetMetadata[asset].empiricKey == 0) {
            govStorage.assetMetadataIndexToAsset[govStorage.assetMetadataLen] = asset;
            govStorage.assetMetadataLen++;
        }

        emit AssetMetadataSet(asset, metadata);
    }

    /**
     * @dev Sets the secondary market support information.
     * @param market The address of the market.
     * @param integration The integration ID.
     * @param isSupported Whether the market is supported.
     * @param isActive Whether the market is active.
     */
    function setSecondaryMarketSupport(
        address market,
        uint integration,
        bool isSupported,
        bool isActive
    )
        external
        onlyGovernorRole(msg.sender)
    {
        GovernorStorage storage govStorage = _governorStorage();
        SecondaryMarket memory secondaryMarket = SecondaryMarket({ supported: isSupported, active: isActive });

        govStorage.secondaryMarketSupport[market][integration] = secondaryMarket;

        emit SecondaryMarketSupportSet(market, integration, secondaryMarket);
    }

    /**
     * @dev Sets the integration selector mapping.
     * @param integration The integration ID.
     * @param method The method ID.
     * @param selector The selector ID.
     */
    function setIntegrationSelectorMapping(
        uint integration,
        uint method,
        uint selector
    )
        external
        onlyGovernorRole(msg.sender)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.integrationMapping[integration][method] = selector;
    }

    /**
     * @dev Sets the staking contract address.
     * @param _stakingContract The address of the staking contract.
     */
    function setStakingContract(address _stakingContract)
        external
        onlyGovernorRole(msg.sender)
        notZero(_stakingContract)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.stakingContract = _stakingContract;
    }

    /**
     * @dev Sets the collector contract address.
     * @param _collectorContract The address of the collector contract.
     */
    function setCollectorContract(address _collectorContract)
        external
        onlyGovernorRole(msg.sender)
        notZero(_collectorContract)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.collectorContract = _collectorContract;
    }

    /**
     * @dev Sets the interest contract address.
     * @param _dialContract The address of the interest contract.
     */
    function setInterestContract(address _dialContract) external onlyGovernorRole(msg.sender) notZero(_dialContract) {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.jumpInterest = _dialContract;
    }

    /**
     * @dev Sets the comptroller contract address.
     * @param _comptrollerContract The address of the comptroller contract.
     */
    function setComptroller(address _comptrollerContract)
        external
        onlyGovernorRole(msg.sender)
        notZero(_comptrollerContract)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.comptrollerContract = _comptrollerContract;
    }

    /**
     * @dev Sets whether a category and function type is allowed for a given integration.
     * @param integration The integration ID.
     * @param selector The function selector.
     * @param isAllowed Whether the category and function type is allowed.
     */
    function setCategoryAndFunctionTypeAllowed(
        uint integration,
        uint selector,
        bool isAllowed
    )
        external
        onlyGovernorRole(msg.sender)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.categoryAndFunctionTypeAllowed[integration][selector] = isAllowed;
    }

    /**
     * @dev Sets the integration contract address.
     * @param _l3DiamondAddress The address of the L3 diamond contract.
     */
    function setIntegrationContractAddress(address _l3DiamondAddress)
        external
        onlyGovernorRole(msg.sender)
        notZero(_l3DiamondAddress)
    {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.l3IntegrationAddress = _l3DiamondAddress;
    }

    /**
     * @dev Sets the liquidation base market asset address.
     * @param asset The address of the asset.
     */
    function setLiquidationBaseMarket(address asset) external onlyGovernorRole(msg.sender) notZero(asset) {
        GovernorStorage storage govStorage = _governorStorage();
        govStorage.liquidationBaseMarket = asset;
    }

    ////////////////////////////
    //////// VIEW FUNCTIONS ////
    ////////////////////////////

    /**
     * @dev Checks if the deposit vault is paused for a given asset.
     * @param asset The address of the asset.
     * @return True if the deposit vault is paused, false otherwise.
     */
    function isDVaultPaused(address asset) public view returns (bool) {
        GovernorStorage storage govStorage = _governorStorage();
        address dToken = getDTokenFromAsset(asset);
        return govStorage.borrowVaultMetadata[dToken].paused;
    }

    /**
     * @dev Checks if staking is paused for a given asset.
     * @param asset The address of the asset.
     * @return True if staking is paused, false otherwise.
     */
    function isStakePaused(address asset) public view returns (bool) {
        GovernorStorage storage govStorage = _governorStorage();
        address rToken = getRTokenFromAsset(asset);
        return govStorage.depositVaultMetadata[rToken].stakingPaused;
    }

    /**
     * @dev Retrieves the deposit vault by index.
     * @param index The index of the deposit vault.
     * @return The address of the rToken and its metadata.
     */
    function getDepositVaultByIndex(uint index) public view returns (address, DepositVaultMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        address rToken = govStorage.depositVaultIndexToRToken[index];
        return (rToken, govStorage.depositVaultMetadata[rToken]);
    }

    /**
     * @dev Retrieves the deposit vault metadata for a given rToken.
     * @param rToken The address of the rToken.
     * @return The deposit vault metadata.
     */
    function getDepositVault(address rToken) public view returns (DepositVaultMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.depositVaultMetadata[rToken];
    }

    /**
     * @dev Gets the minimum deposit amount for a given rToken.
     * @param rToken The address of the rToken.
     * @return The minimum deposit amount.
     */
    function getMinimumDepositAmount(address rToken) public view returns (uint) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.depositVaultMetadata[rToken].minDepositAmount;
    }

    /**
     * @dev Gets the maximum deposit amount for a given rToken.
     * @param rToken The address of the rToken.
     * @return The maximum deposit amount.
     */
    function getMaximumDepositAmount(address rToken) public view returns (uint) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.depositVaultMetadata[rToken].maxDepositAmount;
    }

    /**
     * @dev Gets the minimum loan amount for a given dToken.
     * @param dToken The address of the dToken.
     * @return The minimum loan amount.
     */
    function getMinimumLoanAmount(address dToken) public view returns (uint) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.borrowVaultMetadata[dToken].minBorrowAmount;
    }

    /**
     * @dev Gets the maximum loan amount for a given dToken.
     * @param dToken The address of the dToken.
     * @return The maximum loan amount.
     */
    function getMaximumLoanAmount(address dToken) public view returns (uint) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.borrowVaultMetadata[dToken].maxBorrowAmount;
    }

    /**
     * @dev Retrieves the borrow vault metadata for a given dToken.
     * @param dToken The address of the dToken.
     * @return The borrow vault metadata.
     */
    function getBorrowVault(address dToken) public view returns (BorrowVaultMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.borrowVaultMetadata[dToken];
    }

    /**
     * @dev Checks if a borrow vault is supported for a given dToken.
     * @param dToken The address of the dToken.
     * @return True if the borrow vault is supported, false otherwise.
     */
    function isDVaultSupported(address dToken) public view returns (bool) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.borrowVaultMetadata[dToken].supported;
    }

    /**
     * @dev Retrieves the borrow vault by index.
     * @param index The index of the borrow vault.
     * @return The address of the dToken and its metadata.
     */
    function getBorrowVaultByIndex(uint index) public view returns (address, BorrowVaultMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        address dToken = govStorage.borrowVaultIndexToDToken[index];
        return (dToken, govStorage.borrowVaultMetadata[dToken]);
    }

    /**
     * @dev Retrieves the asset metadata by index.
     * @param index The index of the asset metadata.
     * @return The address of the asset and its metadata.
     */
    function getAssetMetadata(uint index) public view returns (address, AssetMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        address asset = govStorage.assetMetadataIndexToAsset[index];
        return (asset, govStorage.assetMetadata[asset]);
    }

    /**
     * @dev Retrieves the asset metadata for a given asset address.
     * @param asset The address of the asset.
     * @return The asset metadata.
     */
    function getMetadata(address asset) public view returns (AssetMetadata memory) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.assetMetadata[asset];
    }

    /**
     * @dev Retrieves the secondary market support information for a given market and integration.
     * @param market The address of the market.
     * @param integration The integration ID.
     * @return The secondary market support information.
     */
    function getSecondaryMarketSupport(address market, uint integration) public view returns (SecondaryMarket memory) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.secondaryMarketSupport[market][integration];
    }

    /**
     * @dev Retrieves the integration selector mapping for a given integration and method.
     * @param integration The integration ID.
     * @param method The method ID.
     * @return The selector ID.
     */
    function getIntegrationSelectorMapping(uint integration, uint method) public view returns (uint) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.integrationMapping[integration][method];
    }

    /**
     * @dev Retrieves the rToken associated with a given asset.
     * @param asset The address of the asset.
     * @return The address of the associated rToken.
     */
    function getRTokenFromAsset(address asset) public view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.assetMetadata[asset].rToken;
    }

    /**
     * @dev Retrieves the asset associated with a given rToken.
     * @param rToken The address of the rToken.
     * @return The address of the associated asset.
     */
    function getAssetFromRToken(address rToken) public view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.depositVaultMetadata[rToken].asset;
    }

    /**
     * @dev Retrieves the dToken associated with a given asset.
     * @param asset The address of the asset.
     * @return The address of the associated dToken.
     */
    function getDTokenFromAsset(address asset) public view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.assetMetadata[asset].dToken;
    }

    /**
     * @dev Retrieves the asset associated with a given dToken.
     * @param dToken The address of the dToken.
     * @return The address of the associated asset.
     */
    function getAssetFromDToken(address dToken) public view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.borrowVaultMetadata[dToken].asset;
    }

    /**
     * @dev Checks if a category and function type is allowed for a given integration.
     * @param integration The integration ID.
     * @param selector The function selector.
     * @return True if the category and function type is allowed, false otherwise.
     */
    function getCategoryAndFunctionTypeAllowed(uint integration, uint selector) public view returns (bool) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.categoryAndFunctionTypeAllowed[integration][selector];
    }

    /**
     * @dev Retrieves the access registry contract address.
     * @return The address of the access registry contract.
     */
    function getAccessRegistry() public view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.accessRegistryContract;
    }

    function getInterestContract() external view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.jumpInterest;
    }

    function getCollectorContract() external view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.collectorContract;
    }

    function getStakingContract() external view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.stakingContract;
    }

    function getComptroller() external view returns (address) {
        GovernorStorage storage govStorage = _governorStorage();
        return govStorage.comptrollerContract;
    }
}
