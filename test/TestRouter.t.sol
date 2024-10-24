// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from 'forge-std/console.sol';
import { TestBase } from './utils/TestBase.sol';
import { TestHelpers } from './TestHelpers.t.sol';
import { MockERC20 } from './helpers/MockERC20.sol';
import { Governor } from '../src/diamond/facets/Governor.sol';
import { LoanModuleFacet } from '../src/diamond/facets/LoanModuleFacet.sol';

contract TestRouter is TestBase, TestHelpers {
    //general
    address public admin = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        mockAssetUSDT = setUpMocks(admin, 'USDT', 'USDT', 6);
        mockAssetUSDC = setUpMocks(admin, 'USDC', 'USDC', 6);
        mockAssetDAI = setUpMocks(admin, 'DAI', 'DAI', 18);

        setUpAccessRegistry(admin);

        setUpDiamond(admin);

        wrappedSupplyProxyUSDT = setUpSupplyVault(admin, address(mockAssetUSDT), "rUSDT", "rUSDT");
        wrappedSupplyProxyUSDC = setUpSupplyVault(admin, address(mockAssetUSDC), "rUSDC", "rUSDC");
        wrappedSupplyProxyDAI = setUpSupplyVault(admin, address(mockAssetDAI), "rDAI", "rDAI");

        vm.startPrank(admin);

        //Initialize Diamond:

        Governor(address(diamond)).initializeGovernor(address(wrappedAccessRegistryProxy));

        LoanModuleFacet(address(diamond)).initializeOpenRouter(address(diamond));

        //SET Up required Access

        wrappedAccessRegistryProxy.grantRole(keccak256('GOVERNOR_ROLE'), address(governor));
     
        wrappedAccessRegistryProxy.grantRole(keccak256('ROUTER_ROLE'), address(openRouter));

        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(wrappedSupplyProxyUSDT));
        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(wrappedSupplyProxyUSDC));
        wrappedAccessRegistryProxy.grantRole(keccak256('OPEN_ROLE'), address(wrappedSupplyProxyDAI));

        wrappedAccessRegistryProxy.grantRole(keccak256('GOVERNOR_ROLE'), address(diamond));

        wrappedAccessRegistryProxy.grantRole(keccak256('ROUTER_ROLE'), address(diamond));

        Governor(address(diamond)).setDepositVault(
            address(wrappedSupplyProxyUSDT), address(mockAssetUSDT), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetUSDT), address(wrappedSupplyProxyUSDT), address(12), 0
        );

        Governor(address(diamond)).setDepositVault(
            address(wrappedSupplyProxyUSDC), address(mockAssetUSDC), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetUSDC), address(wrappedSupplyProxyUSDC), address(156), 0
        );

        Governor(address(diamond)).setDepositVault(
            address(wrappedSupplyProxyDAI), address(mockAssetDAI), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetDAI), address(wrappedSupplyProxyDAI), address(67), 0
        );

        vm.stopPrank();

        vm.label(address(openRouter), 'Router');
        vm.label(address(governor), 'Governor');
    }

    function mintAndApproveTokens(uint amount, MockERC20 mockERC20, address _user) internal {
        vm.startPrank(_user);
        mockERC20.mint(_user, amount);
        mockERC20.approve(address(wrappedSupplyProxyUSDT), amount);
        vm.stopPrank();
    }

    function depositHelper(uint amount, MockERC20 mockERC20, address _user) public {
        mintAndApproveTokens(amount, mockERC20, _user);
        vm.startPrank(_user);
        LoanModuleFacet(address(diamond)).deposit(address(mockERC20), amount, _user);
        vm.stopPrank();
    }

    function testRouterIntialization() public view {
        assertEq(facetAddresses.length, 5);
        assertEq(
            Governor(address(diamond)).getAccessRegistry(),
            address(wrappedAccessRegistryProxy),
            'Initialization Governor failed'
        );
        assertEq(LoanModuleFacet(address(diamond)).getDiamond(), address(diamond), 'Initialization Router failed');
    }

    function testRouterMultipleInitialization() public {
        vm.startPrank(admin);

        vm.expectRevert();
        LoanModuleFacet(address(diamond)).initializeOpenRouter(address(diamond));

        vm.stopPrank();
    }

    function testDepositRouterWithAdmin() public {
        uint depositAmount = 1000 * 10 ** 6;

        mintAndApproveTokens(depositAmount, mockAssetUSDT, admin);
        uint sharesBefore = wrappedSupplyProxyUSDT.balanceOf(admin);
        vm.startPrank(admin);
        uint sharesReceived = LoanModuleFacet(address(diamond)).deposit(address(mockAssetUSDT), depositAmount, admin);
        uint sharesAfter = wrappedSupplyProxyUSDT.balanceOf(admin);

        assertEq(sharesAfter - sharesBefore, sharesReceived);
        assertEq(wrappedSupplyProxyUSDT.totalAssets(), depositAmount);
        vm.stopPrank();
    }

    function testDepositRouterWithUser() public {
        uint depositAmount = 1000 * 10 ** 6;

        mintAndApproveTokens(depositAmount, mockAssetUSDT, user);
        uint sharesBefore = wrappedSupplyProxyUSDT.balanceOf(user);
        vm.startPrank(user);
        uint sharesReceived = LoanModuleFacet(address(diamond)).deposit(address(mockAssetUSDT), depositAmount, user);
        uint sharesAfter = wrappedSupplyProxyUSDT.balanceOf(user);

        assertEq(sharesAfter - sharesBefore, sharesReceived);
        assertEq(wrappedSupplyProxyUSDT.totalAssets(), depositAmount);
        vm.stopPrank();
    }

    function testWithdrawRouter() public {
        uint depositAmount = 1000 * 10 ** 6;
        uint withdrawAmount = 500 * 10 ** 6;

        // Deposit first
        depositHelper(depositAmount, mockAssetUSDT, user);
        uint assetsBefore = mockAssetUSDT.balanceOf(user);
        vm.startPrank(user);
        uint sharesBurned =
            LoanModuleFacet(address(diamond)).withdrawDeposit(address(mockAssetUSDT), withdrawAmount, user, user);
        uint assetsAfter = mockAssetUSDT.balanceOf(user);

        assertEq(assetsAfter - assetsBefore, withdrawAmount);
        assertEq(wrappedSupplyProxyUSDT.totalAssets(), depositAmount - withdrawAmount);
        vm.stopPrank();
    }

    //Fuzz test

    function testFuzzDeposit(uint128 depositAmount) public {
        vm.assume(depositAmount > 0);

        mintAndApproveTokens(depositAmount, mockAssetUSDT, user);
        uint sharesBefore = wrappedSupplyProxyUSDT.balanceOf(user);
        vm.startPrank(user);
        uint sharesReceived = LoanModuleFacet(address(diamond)).deposit(address(mockAssetUSDT), depositAmount, user);
        uint sharesAfter = wrappedSupplyProxyUSDT.balanceOf(user);

        assertEq(sharesAfter - sharesBefore, sharesReceived);
        assertEq(wrappedSupplyProxyUSDT.totalAssets(), depositAmount);
        vm.stopPrank();
    }

    function testFuzzWithdraw(uint128 withdrawAmount) public {
        uint128 depositAmount = uint128(type(uint128).max);

        depositHelper(depositAmount, mockAssetUSDT, user);
        uint assetsBefore = mockAssetUSDT.balanceOf(user);
        vm.startPrank(user);
        uint sharesBurned =
            LoanModuleFacet(address(diamond)).withdrawDeposit(address(mockAssetUSDT), withdrawAmount, user, user);
        uint assetsAfter = mockAssetUSDT.balanceOf(user);

        assertEq(assetsAfter - assetsBefore, withdrawAmount);
        assertEq(wrappedSupplyProxyUSDT.totalAssets(), depositAmount - withdrawAmount);
        vm.stopPrank();
    }
}
