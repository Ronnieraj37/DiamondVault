// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestBase } from './utils/TestBase.sol';
import { console } from 'forge-std/console.sol';
import {
    DepositVaultMetadata,
    BorrowVaultMetadata,
    AssetMetadata,
    SecondaryMarket
} from '../src/diamond/storages/Governor/GovernorStruct.sol';
import { Governor } from '../src/diamond/facets/Governor.sol';
import { TestHelpers } from './TestHelpers.t.sol';

contract TestGovernor is TestBase, TestHelpers {
    event DepositVaultSet(address indexed rToken, DepositVaultMetadata metadata);
    event AssetMetadataSet(address indexed asset, AssetMetadata metadata);
    event BorrowVaultSet(address indexed dToken, BorrowVaultMetadata metadata);

    address public admin = address(0x1);
    address public user = address(0x2);
    address public _governorUser = address(0x3);

    bytes32 public constant GOVERNOR_ROLE = keccak256('GOVERNOR_ROLE');

    function setUp() public {
        setUpAccessRegistry(admin);

        setUpDiamond(admin);

        vm.startPrank(admin);

        // Initialize Governor
        Governor(address(diamond)).initializeGovernor(address(wrappedAccessRegistryProxy));

        // Grant GOVERNOR_ROLE to the governor address
        wrappedAccessRegistryProxy.grantRole(GOVERNOR_ROLE, _governorUser);

        // Grant roles to admin
        wrappedAccessRegistryProxy.grantRole(GOVERNOR_ROLE, admin);
        wrappedAccessRegistryProxy.grantRole(wrappedAccessRegistryProxy.SUPER_ADMIN_ROLE(), admin);

        vm.stopPrank();

        // Label addresses for easier debugging
        vm.label(address(diamond), 'Diamond');
        vm.label(address(governor), 'GovernorFacet');
        vm.label(address(accessRegistryProxy), 'AccessRegistry');
        vm.label(admin, 'Admin');
        vm.label(user, 'User');
        vm.label(_governorUser, 'Governor');

        debug('AccessRegistry address in Governor:', Governor(address(diamond)).getAccessRegistry());
        debug('Actual AccessRegistry address:', address(accessRegistryProxy));
    }

    function testMultipleInitialization() public {
        vm.startPrank(admin);

        vm.expectRevert();
        // Initialize Governor
        Governor(address(diamond)).initializeGovernor(address(wrappedAccessRegistryProxy));
        vm.stopPrank();
    }

    function testSetDepositVault() public {
        vm.startPrank(admin);

        address rToken = address(0x4);
        address asset = address(0x5);
        bool supported = true;
        bool paused = false;
        bool stakingPaused = false;
        uint minDepositAmount = 100;
        uint maxDepositAmount = 1000;

        Governor(address(diamond)).setDepositVault(
            rToken, asset, supported, paused, stakingPaused, minDepositAmount, maxDepositAmount
        );

        // @audit - getDepositVaultByIndex is not returning the correct values
        DepositVaultMetadata memory metadata = Governor(address(diamond)).getDepositVault(rToken);

        // assertEq(storedRToken, rToken, "Incorrect rToken stored");
        assertEq(metadata.asset, asset, 'Incorrect asset stored');
        assertEq(metadata.supported, supported, 'Incorrect supported value');
        assertEq(metadata.paused, paused, 'Incorrect paused value');
        assertEq(metadata.stakingPaused, stakingPaused, 'Incorrect stakingPaused value');
        assertEq(metadata.minDepositAmount, minDepositAmount, 'Incorrect minDepositAmount');
        assertEq(metadata.maxDepositAmount, maxDepositAmount, 'Incorrect maxDepositAmount');

        vm.stopPrank();
    }

    function testSetDepositVaultWithNonGovernor() public {
        address nonGovernor = address(123);

        vm.startPrank(nonGovernor);

        address rToken = address(0x4);
        address asset = address(0x5);
        bool supported = true;
        bool paused = false;
        bool stakingPaused = false;
        uint minDepositAmount = 100;
        uint maxDepositAmount = 1000;

        vm.expectRevert();

        Governor(address(diamond)).setDepositVault(
            rToken, asset, supported, paused, stakingPaused, minDepositAmount, maxDepositAmount
        );

        vm.stopPrank();
    }

    function testSetDepositVaultEventEmission() public {
        vm.startPrank(admin);

        address rToken = address(0x4);
        address asset = address(0x5);
        bool supported = true;
        bool paused = false;
        bool stakingPaused = false;
        uint minDepositAmount = 100;
        uint maxDepositAmount = 1000;

        DepositVaultMetadata memory metadata = DepositVaultMetadata({
            asset: asset,
            supported: supported,
            paused: paused,
            stakingPaused: stakingPaused,
            minDepositAmount: minDepositAmount,
            maxDepositAmount: maxDepositAmount
        });

        vm.expectEmit(true, true, false, false);
        emit DepositVaultSet(rToken, metadata);

        Governor(address(diamond)).setDepositVault(
            rToken, asset, supported, paused, stakingPaused, minDepositAmount, maxDepositAmount
        );

        vm.stopPrank();
    }

    function testSetDepositVaultWithZeroAddress() public {
        vm.startPrank(admin);

        address rToken = address(0x4);
        address asset = address(0);
        bool supported = true;
        bool paused = false;
        bool stakingPaused = false;
        uint minDepositAmount = 100;
        uint maxDepositAmount = 1000;

        vm.expectRevert();

        Governor(address(diamond)).setDepositVault(
            rToken, asset, supported, paused, stakingPaused, minDepositAmount, maxDepositAmount
        );

        vm.stopPrank();
    }

    function testSetAssetMetadataWithZeroAddress() public {
        vm.startPrank(admin);

        address asset = address(0);
        address rToken = address(0x7);
        address dToken = address(0x8);
        uint empiricKey = 123;

        vm.expectRevert();

        Governor(address(diamond)).setAssetMetadata(asset, rToken, dToken, empiricKey);

        vm.stopPrank();
    }

    function testSetDepositMultipleVault() public {
        vm.startPrank(admin);

        address rToken1 = address(1);
        address asset1 = address(2);
        bool supported1 = true;
        bool paused1 = false;
        bool stakingPaused1 = false;
        uint minDepositAmount1 = 100;
        uint maxDepositAmount1 = 1000;

        address rToken2 = address(3);
        address asset2 = address(4);
        bool supported2 = true;
        bool paused2 = false;
        bool stakingPaused2 = false;
        uint minDepositAmount2 = 100;
        uint maxDepositAmount2 = 1000;

        Governor(address(diamond)).setDepositVault(
            rToken1, asset1, supported1, paused1, stakingPaused1, minDepositAmount1, maxDepositAmount1
        );

        Governor(address(diamond)).setDepositVault(
            rToken2, asset2, supported2, paused2, stakingPaused2, minDepositAmount2, maxDepositAmount2
        );

        // @audit - getDepositVaultByIndex is not returning the correct values
        DepositVaultMetadata memory metadata1 = Governor(address(diamond)).getDepositVault(rToken1);
        DepositVaultMetadata memory metadata2 = Governor(address(diamond)).getDepositVault(rToken2);

        // assertEq(storedRToken, rToken, "Incorrect rToken stored");
        assertEq(metadata1.asset, asset1, 'Incorrect asset stored');
        assertEq(metadata1.supported, supported1, 'Incorrect supported value');
        assertEq(metadata1.paused, paused1, 'Incorrect paused value');
        assertEq(metadata1.stakingPaused, stakingPaused1, 'Incorrect stakingPaused value');
        assertEq(metadata1.minDepositAmount, minDepositAmount1, 'Incorrect minDepositAmount');
        assertEq(metadata1.maxDepositAmount, maxDepositAmount1, 'Incorrect maxDepositAmount');

        assertEq(metadata2.asset, asset2, 'Incorrect asset stored');
        assertEq(metadata2.supported, supported2, 'Incorrect supported value');
        assertEq(metadata2.paused, paused2, 'Incorrect paused value');
        assertEq(metadata2.stakingPaused, stakingPaused2, 'Incorrect stakingPaused value');
        assertEq(metadata2.minDepositAmount, minDepositAmount2, 'Incorrect minDepositAmount');
        assertEq(metadata2.maxDepositAmount, maxDepositAmount2, 'Incorrect maxDepositAmount');

        vm.stopPrank();
    }

    function testSetAssetMetadata() public {
        vm.startPrank(admin);

        address asset = address(0x6);
        address rToken = address(0x7);
        address dToken = address(0x8);
        uint empiricKey = 123;

        Governor(address(diamond)).setAssetMetadata(asset, rToken, dToken, empiricKey);

        AssetMetadata memory metadata = Governor(address(diamond)).getMetadata(asset);

        // assertEq(storedAsset, asset, "Incorrect asset stored");
        assertEq(metadata.rToken, rToken, 'Incorrect rToken stored');
        assertEq(metadata.dToken, dToken, 'Incorrect dToken stored');
        assertEq(metadata.empiricKey, empiricKey, 'Incorrect empiricKey stored');

        vm.stopPrank();
    }

    function testSetAssetMetadataEventEmission() public {
        vm.startPrank(admin);

        address asset = address(0x6);
        address rToken = address(0x7);
        address dToken = address(0x8);
        uint empiricKey = 123;

        AssetMetadata memory metadata = AssetMetadata({ rToken: rToken, dToken: dToken, empiricKey: empiricKey });

        vm.expectEmit(true, true, false, false);
        emit AssetMetadataSet(asset, metadata);

        Governor(address(diamond)).setAssetMetadata(asset, rToken, dToken, empiricKey);
    }

    function testSetAssetMetadataWithNonGovernor() public {
        address nonGovernor = address(123);

        vm.startPrank(nonGovernor);

        address asset = address(0x6);
        address rToken = address(0x7);
        address dToken = address(0x8);
        uint empiricKey = 123;

        vm.expectRevert();

        Governor(address(diamond)).setAssetMetadata(asset, rToken, dToken, empiricKey);
        vm.stopPrank();
    }

    function testSetComptroller() public {
        vm.startPrank(admin);

        address newComptroller = address(0x123);
        Governor(address(diamond)).setComptroller(newComptroller);

        // Verify the comptroller address
        assertEq(Governor(address(diamond)).getComptroller(), newComptroller, 'Incorrect comptroller address');

        vm.stopPrank();
    }

    function testSetComptrollerNonGovernor() public {
        vm.startPrank(user);

        address newComptroller = address(0x123);
        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setComptroller(newComptroller);

        vm.stopPrank();
    }

    function testSetComptrollerZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setComptroller(address(0));

        vm.stopPrank();
    }

    function testSetCollectorContract() public {
        vm.startPrank(admin);

        address newCollector = address(0x456);
        Governor(address(diamond)).setCollectorContract(newCollector);

        // Verify the collector address
        assertEq(Governor(address(diamond)).getCollectorContract(), newCollector, 'Incorrect collector address');

        vm.stopPrank();
    }

    function testSetCollectorContractNonGovernor() public {
        vm.startPrank(user);

        address newCollector = address(0x456);
        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setCollectorContract(newCollector);

        vm.stopPrank();
    }

    function testSetCollectorContractZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setCollectorContract(address(0));

        vm.stopPrank();
    }

    function testSetStakingContract() public {
        vm.startPrank(admin);

        address newStaking = address(0x789);
        Governor(address(diamond)).setStakingContract(newStaking);

        // Verify the staking address
        assertEq(Governor(address(diamond)).getStakingContract(), newStaking, 'Incorrect staking address');

        vm.stopPrank();
    }

    function testSetStakingContractNonGovernor() public {
        vm.startPrank(user);

        address newStaking = address(0x789);
        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setStakingContract(newStaking);

        vm.stopPrank();
    }

    function testSetStakingContractZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setStakingContract(address(0));

        vm.stopPrank();
    }

    function testSetBorrowVault() public {
        vm.startPrank(admin);

        address dToken = address(0x6);
        address asset = address(0x7);
        bool paused = false;
        bool supported = true;
        uint minBorrow = 50;
        uint maxBorrow = 500;

        // Test successful execution
        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        // Verify the borrow vault metadata
        BorrowVaultMetadata memory metadata = Governor(address(diamond)).getBorrowVault(dToken);
        assertEq(metadata.asset, asset, 'Incorrect asset stored');
        assertEq(metadata.supported, supported, 'Incorrect supported value');
        assertEq(metadata.paused, paused, 'Incorrect paused value');
        assertEq(metadata.minBorrowAmount, minBorrow, 'Incorrect minBorrowAmount');
        assertEq(metadata.maxBorrowAmount, maxBorrow, 'Incorrect maxBorrowAmount');

        // Test event emission
        vm.expectEmit(true, true, false, true);
        emit BorrowVaultSet(dToken, metadata);
        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        // Test access control
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        // Test zero address checks
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setBorrowVault(address(0), asset, paused, supported, minBorrow, maxBorrow);

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));
        Governor(address(diamond)).setBorrowVault(dToken, address(0), paused, supported, minBorrow, maxBorrow);

        // Test updating an existing borrow vault
        bool newPaused = true;
        bool newSupported = false;
        uint newMinBorrow = 100;
        uint newMaxBorrow = 1000;

        Governor(address(diamond)).setBorrowVault(dToken, asset, newPaused, newSupported, newMinBorrow, newMaxBorrow);

        metadata = Governor(address(diamond)).getBorrowVault(dToken);
        assertEq(metadata.supported, newSupported, 'Incorrect updated supported value');
        assertEq(metadata.paused, newPaused, 'Incorrect updated paused value');
        assertEq(metadata.minBorrowAmount, newMinBorrow, 'Incorrect updated minBorrowAmount');
        assertEq(metadata.maxBorrowAmount, newMaxBorrow, 'Incorrect updated maxBorrowAmount');

        // Test adding a new borrow vault
        address newDToken = address(0x8);
        Governor(address(diamond)).setBorrowVault(newDToken, asset, paused, supported, minBorrow, maxBorrow);

        metadata = Governor(address(diamond)).getBorrowVault(newDToken);
        assertEq(metadata.asset, asset, 'Incorrect asset for new borrow vault');
        assertEq(metadata.supported, supported, 'Incorrect supported value for new borrow vault');
        assertEq(metadata.paused, paused, 'Incorrect paused value for new borrow vault');
        assertEq(metadata.minBorrowAmount, minBorrow, 'Incorrect minBorrowAmount for new borrow vault');
        assertEq(metadata.maxBorrowAmount, maxBorrow, 'Incorrect maxBorrowAmount for new borrow vault');

        vm.stopPrank();
    }

    function testSetBorrowVaultEventEmission() public {
        vm.startPrank(admin);

        address dToken = address(0x6);
        address asset = address(0x7);
        bool paused = false;
        bool supported = true;
        uint minBorrow = 50;
        uint maxBorrow = 500;

        BorrowVaultMetadata memory metadata = BorrowVaultMetadata({
            asset: asset,
            supported: supported,
            paused: paused,
            minBorrowAmount: minBorrow,
            maxBorrowAmount: maxBorrow
        });

        vm.expectEmit(true, true, false, true);
        emit BorrowVaultSet(dToken, metadata);

        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        vm.stopPrank();
    }

    function testSetBorrowVaultWithZeroAsset() public {
        vm.startPrank(admin);

        address dToken = address(0x6);
        address asset = address(0);
        bool paused = false;
        bool supported = true;
        uint minBorrow = 50;
        uint maxBorrow = 500;

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));

        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        vm.stopPrank();
    }

    function testSetBorrowVaultWithZeroDToken() public {
        vm.startPrank(admin);

        address dToken = address(0);
        address asset = address(0x7);
        bool paused = false;
        bool supported = true;
        uint minBorrow = 50;
        uint maxBorrow = 500;

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));

        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        vm.stopPrank();
    }

    function testSetBorrowVaultWithNonGovernor() public {
        address nonGovernor = address(123);

        vm.startPrank(nonGovernor);

        address dToken = address(0x6);
        address asset = address(0x7);
        bool paused = false;
        bool supported = true;
        uint minBorrow = 50;
        uint maxBorrow = 500;

        vm.expectRevert(abi.encodeWithSignature('INVALID_ACCESS()'));

        Governor(address(diamond)).setBorrowVault(dToken, asset, paused, supported, minBorrow, maxBorrow);

        vm.stopPrank();
    }
}
