// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestBase } from './utils/TestBase.sol';
import { SupplyProxy } from '../src/contracts/supply/SupplyProxy.sol';
import { ERC1967Proxy } from '@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol';
import { SupplyVault } from '../src/contracts/supply/SupplyVault.sol';
import { ERC20 } from './helpers/ERC20.sol';
import { Ownable } from './helpers/Ownable.sol';
import { AccessRegistry } from '../src/contracts/AccessRegistry/accessRegistry.sol';
import { mockSupplyVault } from './helpers/MockSupply.sol';
import { console } from 'forge-std/console.sol';

contract MockERC20 is ERC20, Ownable {
    constructor(
        address initialOwner,
        string memory name_,
        string memory symbol_,
        uint8 decimals
    )
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    {
        _setupDecimals(decimals);
        _mint(initialOwner, 100 * 10 ** 6);
        transferOwnership(initialOwner);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure override returns (bytes calldata) {
        return msg.data;
    }
}

contract TestSupply is TestBase {
    event Locked(address indexed user, uint rTokens_amount, uint total_locked);
    event Deposit(address from, address to, uint amount, uint shares);

    error EnforcePause();

    MockERC20 public mockAsset;

    //Access Registry Contract
    ERC1967Proxy public accessRegistryProxy;
    AccessRegistry public accessRegistryImplementation;
    AccessRegistry public wrappedAccessRegistryProxy;

    //Supply side
    ERC1967Proxy public supplyProxy;
    SupplyVault public supplyImplementation;
    SupplyVault public wrappedSupplyProxy;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public governor = address(0x3);

    function setUp() public {
        vm.startPrank(admin);

        // deploying the asset contracts:
        mockAsset = new MockERC20(admin, 'Sahitya', 'SAHI', 6);

        //deploy Access registry Contract

        accessRegistryImplementation = new AccessRegistry();

        bytes memory dataAccessRegistry = abi.encodeWithSelector(AccessRegistry.initializeAccessRegistry.selector, admin);

        accessRegistryProxy = new ERC1967Proxy(address(accessRegistryImplementation), dataAccessRegistry);

        wrappedAccessRegistryProxy = AccessRegistry(address(accessRegistryProxy));

        // Deploy supply side contract

        supplyImplementation = new SupplyVault();

        bytes memory data = abi.encodeWithSelector(
            SupplyVault.initializeSupply.selector,
            address(mockAsset),
            'r_Sahitya_vault',
            'rSAHI',
            governor,
            wrappedAccessRegistryProxy
        );

        supplyProxy = new ERC1967Proxy(address(supplyImplementation), data);

        wrappedSupplyProxy = SupplyVault(address(supplyProxy));

        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(wrappedSupplyProxy));
        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(user));

        vm.stopPrank();

        // Label addresses for easier debugging
        vm.label(address(supplyImplementation), 'SupplyVault');
        vm.label(address(mockAsset), 'MockAsset');
        vm.label(admin, 'Admin');
        vm.label(user, 'User');
        vm.label(governor, 'Governor');
        vm.label(address(wrappedAccessRegistryProxy), 'AccessControl');
    }

    function mintAndApproveTokens(uint amount,address _user) public {
        vm.startPrank(_user);
        mockAsset.mint(_user, amount);
        mockAsset.approve(address(wrappedSupplyProxy), amount);
        vm.stopPrank();
    }

    function testInitialization() public view {

    //vault Initialization
        assertEq(wrappedSupplyProxy.asset(), address(mockAsset));
        assertEq(wrappedSupplyProxy.name(), 'r_Sahitya_vault');
        assertEq(wrappedSupplyProxy.symbol(), 'rSAHI');
        assertEq(wrappedSupplyProxy.decimals(), 6);
    // Access Registry Check:
        bytes32 OPEN_ROLE  = keccak256('OPEN_ROLE');
        assertEq(wrappedAccessRegistryProxy.hasRole(OPEN_ROLE, address(wrappedSupplyProxy)), true);
        assertEq(wrappedAccessRegistryProxy.hasRole(OPEN_ROLE, address(user)), true);
        
    }

    /* 
    Deposit to SUPPLY VAULT
    */

    function testDepositZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert();
        wrappedSupplyProxy.deposit(user,0, user);
        vm.stopPrank();
    }

    function testDepositToZeroAddress() public {
        uint depositAmount = 1000 * 10 ** 6;
        mintAndApproveTokens(depositAmount,user);
        vm.startPrank(user);
        vm.expectRevert();
        wrappedSupplyProxy.deposit(user,depositAmount, address(0));
        vm.stopPrank();
    }

    function testDepositInsufficientAllowance() public {
        uint depositAmount = 1000 * 10 ** 6;
        mockAsset.mint(user, depositAmount);

        vm.startPrank(user);
        mockAsset.approve(address(wrappedSupplyProxy), depositAmount - 1);
        vm.expectRevert();
        wrappedSupplyProxy.deposit(user,depositAmount, user);
        vm.stopPrank();
    }

    function testDepositInsufficientBalance() public {
        uint depositAmount = 1000 * 10 ** 6;
        mockAsset.mint(user, depositAmount - 1);

        vm.startPrank(user);
        mockAsset.approve(address(wrappedSupplyProxy), depositAmount);
        vm.expectRevert();
        wrappedSupplyProxy.deposit(user,depositAmount, user);
        vm.stopPrank();
    }

    function testDepositEventEmission() public {
        uint depositAmount = 1000 * 10 ** 6;
        mintAndApproveTokens(depositAmount,user);
        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit Deposit(user, user, depositAmount, depositAmount);
        wrappedSupplyProxy.deposit(user,depositAmount, user);

        vm.stopPrank();
    }

    function testDepositUpdatesTotalAssets() public {
        uint depositAmount1 = 1000 * 10 ** 6;
        uint depositAmount2 = 500 * 10 ** 6;

        mintAndApproveTokens(depositAmount1 + depositAmount2,user);
        vm.startPrank(user);
        wrappedSupplyProxy.deposit(user,depositAmount1, user);
        assertEq(wrappedSupplyProxy.totalAssets(), depositAmount1);

        wrappedSupplyProxy.deposit(user,depositAmount2, user);
        assertEq(wrappedSupplyProxy.totalAssets(), depositAmount1 + depositAmount2);

        vm.stopPrank();
    }

    function testDepositUpdatesUserBalance() public {
        uint depositAmount1 = 1000 * 10 ** 6;
        uint depositAmount2 = 500 * 10 ** 6;

        mintAndApproveTokens(depositAmount1 + depositAmount2,user);
        vm.startPrank(user);

        wrappedSupplyProxy.deposit(user,depositAmount1, user);
        assertEq(wrappedSupplyProxy.balanceOf(user), depositAmount1);

        wrappedSupplyProxy.deposit(user,depositAmount2, user);
        assertEq(wrappedSupplyProxy.balanceOf(user), depositAmount1 + depositAmount2);

        vm.stopPrank();
    }

    function testDeposit() public {

        uint depositAmount = 1000 * 10 ** 6;

        mintAndApproveTokens(depositAmount,user);
        vm.startPrank(user);
        uint sharesBefore = wrappedSupplyProxy.balanceOf(user);
        uint sharesReceived = wrappedSupplyProxy.deposit(user,depositAmount, user);
        uint sharesAfter = wrappedSupplyProxy.balanceOf(user);

        assertEq(sharesAfter - sharesBefore, sharesReceived);
        assertEq(wrappedSupplyProxy.totalAssets(), depositAmount);
        vm.stopPrank();
    }

    function testDepositWhenPaused() external {
        vm.startPrank(admin);
        wrappedSupplyProxy.pause();
        vm.stopPrank();

        uint depositAmount = 1000 * 10 ** 6;

        // Mint mock assets to user
        mintAndApproveTokens(depositAmount,user);
        vm.startPrank(user);
        vm.expectRevert();
        uint sharesReceived = wrappedSupplyProxy.deposit(user,depositAmount, user);
        vm.stopPrank();
    }

    /*
    Withdraw
    */

    function depositHelper(uint amount) public {
        mintAndApproveTokens(amount,user);
        vm.startPrank(user);
        wrappedSupplyProxy.deposit(user,amount, user);
        vm.stopPrank();
    }

    function testPartialWithdraw() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint withdrawAmount = 500 * 10 ** 6;

        depositHelper(depositAmount);
        vm.startPrank(user);

        uint assetsBefore = mockAsset.balanceOf(user);
        uint sharesBefore = wrappedSupplyProxy.balanceOf(user);
        uint sharesBurned = wrappedSupplyProxy.withdraw(user, withdrawAmount, user, user);
        uint assetsAfter = mockAsset.balanceOf(user);

        assertEq(assetsAfter - assetsBefore, withdrawAmount, 'Incorrect withdrawal amount');
        assertEq(
            wrappedSupplyProxy.totalAssets(), depositAmount - withdrawAmount, 'Incorrect total assets after withdrawal'
        );
        assertEq(
            wrappedSupplyProxy.balanceOf(user), sharesBefore - sharesBurned, 'Incorrect shares balance after withdrawal'
        );
        vm.stopPrank();
    }

    function testFullWithdraw() public {
        uint depositAmount = 1000 * 10 ** 6;

        depositHelper(depositAmount);
        vm.startPrank(user);

        uint sharesBefore = wrappedSupplyProxy.balanceOf(user);
        uint sharesBurned = wrappedSupplyProxy.withdraw(user, depositAmount, user, user);

        assertEq(wrappedSupplyProxy.balanceOf(user), 0, 'User should have no shares left');
        assertEq(wrappedSupplyProxy.totalAssets(), 0, 'Vault should have no assets left');
        assertEq(sharesBurned, sharesBefore, 'All shares should be burned');
        assertEq(mockAsset.balanceOf(user), depositAmount, 'User should have all assets back');
        vm.stopPrank();
    }

    function testWithdrawToZeroAddress() public {
        uint depositAmount = 1000 * 10 ** 6;
        depositHelper(depositAmount);
        vm.startPrank(user);
        vm.expectRevert();
        wrappedSupplyProxy.withdraw(user, 0, address(0), user);

        vm.stopPrank();
    }

    function testWithdrawZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert();
        wrappedSupplyProxy.withdraw(user, 0, user, user);
        vm.stopPrank();
    }

    function testWithdrawMoreThanBalance() public {
        uint depositAmount = 1000 * 10 ** 6;

        depositHelper(depositAmount);
        vm.startPrank(user);

        vm.expectRevert();
        wrappedSupplyProxy.withdraw(user, depositAmount + 1, user, user);
        vm.stopPrank();
    }

    function testWithdrawToDifferentRecipient() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint withdrawAmount = 250 * 10 ** 6;
        address recipient = address(0x123);

        depositHelper(depositAmount);
         vm.startPrank(user);

        uint recipientBalanceBefore = mockAsset.balanceOf(recipient);
        wrappedSupplyProxy.withdraw(user, withdrawAmount, recipient, user);
        uint recipientBalanceAfter = mockAsset.balanceOf(recipient);

        assertEq(
            recipientBalanceAfter - recipientBalanceBefore, withdrawAmount, 'Recipient should receive correct amount'
        );
        vm.stopPrank();
    }

    function testWithdrawAfterAssetAppreciation() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint appreciationAmount = 500 * 10 ** 6;
        depositHelper(depositAmount);
         vm.startPrank(user);

        // Simulate asset appreciation
        mockAsset.mint(address(wrappedSupplyProxy), appreciationAmount);

        uint sharesBefore = wrappedSupplyProxy.balanceOf(user);
        uint totalAssetsBefore = wrappedSupplyProxy.totalAssets();
        uint withdrawAmount = totalAssetsBefore;

        uint sharesBurned = wrappedSupplyProxy.withdraw(user, withdrawAmount, user, user);

        assertEq(sharesBurned, sharesBefore, 'All shares should be burned');
        assertEq(mockAsset.balanceOf(user), totalAssetsBefore, 'User should receive all appreciated assets');
        assertEq(wrappedSupplyProxy.totalAssets(), 0, 'Vault should have no assets left');
        vm.stopPrank();
    }

    function testWithdraw() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint withdrawAmount = 500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);
         vm.startPrank(user);
        uint assetsBefore = mockAsset.balanceOf(user);
        uint sharesBurned = wrappedSupplyProxy.withdraw(user, withdrawAmount, user, user);
        uint assetsAfter = mockAsset.balanceOf(user);

        assertEq(assetsAfter - assetsBefore, withdrawAmount);
        assertEq(wrappedSupplyProxy.totalAssets(), depositAmount - withdrawAmount);
        vm.stopPrank();
    }

    function testWithdrawWhenPaused() external {
        uint depositAmount = 1000 * 10 ** 6;
        uint withdrawAmount = 500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);

        vm.startPrank(admin);
        wrappedSupplyProxy.pause();
        vm.stopPrank();

        vm.expectRevert();
        vm.startPrank(user);
        uint sharesBurned = wrappedSupplyProxy.withdraw(user, withdrawAmount, user, user);
        vm.stopPrank();
    }

    /*
    Locking rTokens
    */

    function testLockRTokens() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint lockAmount = 500 * 10 ** 6;

        vm.startPrank(admin);
        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(wrappedSupplyProxy));
        vm.stopPrank();

        // Deposit first
        depositHelper(depositAmount);
        vm.startPrank(address(wrappedSupplyProxy));

        uint freeBefore = wrappedSupplyProxy.getFreeRTokens(user);

        assertEq(freeBefore,depositAmount,'Amount::Misatch');
        wrappedSupplyProxy.lockRTokens(user, lockAmount);
        uint freeAfter = wrappedSupplyProxy.getFreeRTokens(user);

        assertEq(freeBefore - freeAfter, lockAmount);
        vm.stopPrank();
    }

    function testLockRTokensZeroAddress() public {
        vm.startPrank(address(wrappedSupplyProxy));
        vm.expectRevert();
        wrappedSupplyProxy.lockRTokens(address(0), 100 * 10 ** 6);
        vm.stopPrank();
    }

    function testLockRTokensZeroAmount() public {
        vm.startPrank(address(wrappedSupplyProxy));
        vm.expectRevert();
        wrappedSupplyProxy.lockRTokens(user, 0);
        vm.stopPrank();
    }

    function testLockRTokensExceedingBalance() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint lockAmount = 1500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);
        vm.stopPrank();

        vm.startPrank(address(wrappedSupplyProxy));
        vm.expectRevert();
        wrappedSupplyProxy.lockRTokens(user, lockAmount);
        vm.stopPrank();
    }

    function testTransferAfterLocking() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint lockAmount = 500 * 10 ** 6;
        uint transferAmount = 600 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);

        // Lock tokens
        vm.startPrank(address(wrappedSupplyProxy));
        wrappedSupplyProxy.lockRTokens(user, lockAmount);
        vm.stopPrank();

        uint freeTokens = wrappedSupplyProxy.getFreeRTokens(user);
        assertEq(freeTokens,lockAmount,"MisMatch");
        // Try to transfer more than free balance
        vm.startPrank(user);
        vm.expectRevert();
        // wrappedSupplyProxy.transfer(address(23), transferAmount);
        wrappedSupplyProxy.transferFrom(user,address(23), transferAmount);

        vm.stopPrank();
    }

    function testLockRTokensEventEmission() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint lockAmount = 500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);
        vm.stopPrank();

        vm.startPrank(address(wrappedSupplyProxy));

        // Get the free rTokens before locking
        uint freeRTokensBefore = wrappedSupplyProxy.getFreeRTokens(user);

        // Calculate the expected free rTokens after locking
        uint expectedFreeRTokens = freeRTokensBefore - lockAmount;

        vm.expectEmit(true, true, true, true);
        emit Locked(user, lockAmount, depositAmount - expectedFreeRTokens);
        wrappedSupplyProxy.lockRTokens(user, lockAmount);

        // Verify the free rTokens after locking
        uint freeRTokensAfter = wrappedSupplyProxy.getFreeRTokens(user);
        assertEq(freeRTokensAfter, expectedFreeRTokens);

        vm.stopPrank();
    }

    function testFreeLockedRTokens() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint lockAmount = 500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount);

        vm.startPrank(address(wrappedSupplyProxy));

        //Lock the tokens

        wrappedSupplyProxy.lockRTokens(user, lockAmount);

        uint freeBefore = wrappedSupplyProxy.getFreeRTokens(user);

        //free the tokens 
        wrappedSupplyProxy.freeLockedRTokens(user, lockAmount);
        uint freeAfter = wrappedSupplyProxy.getFreeRTokens(user);

        assertEq(freeAfter - freeBefore, lockAmount);
        vm.stopPrank();
    }

    function testExchangeRate() public {
        uint depositAmount = 1000 * 10 ** 6;

        // Deposit first
        mockAsset.mint(user, depositAmount);
        vm.startPrank(user);
        mockAsset.approve(address(wrappedSupplyProxy), depositAmount);
        wrappedSupplyProxy.deposit(user,depositAmount, user);

        (uint rTokenAmount, uint assetAmount) = wrappedSupplyProxy.exchangeRate();

        // console.log("rTokenAmount: ",rTokenAmount/10**6);
        // console.log("assetAmount: ",assetAmount/10**6);

        //10000000000000000000
        //10000000000000

        // assertEq(rTokenAmount, depositAmount);
        // assertEq(assetAmount, depositAmount);
        vm.stopPrank();
    }


    /*
    Test-Upgrade
    */

    function testUpgradeSupplyVault() external {
        vm.startPrank(admin);
        mockSupplyVault newImplementation = new mockSupplyVault();
        bytes32 SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
        assertEq(wrappedAccessRegistryProxy.hasRole(SUPER_ADMIN_ROLE,admin),true,"Role Not Granted");

        wrappedSupplyProxy.upgradeToAndCall(address(newImplementation), '');

        mockSupplyVault upgradedWrappedSupplyProxy = mockSupplyVault(address(supplyProxy));

        assertEq(upgradedWrappedSupplyProxy.get_a(), 0, 'Error:Storage collison');
        upgradedWrappedSupplyProxy.set_a(3);
        assertEq(upgradedWrappedSupplyProxy.get_a(), 3, 'Error:Storage collison');

        vm.stopPrank();
    }
}
