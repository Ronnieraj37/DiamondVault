//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/diamond/facets/vaults/Vault.sol";
import {MockERC20} from "./helpers/MockToken.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 mockERC20;
    // Accounts
    address admin = address(1);
    address user1 = address(2);

    function setUp() public {
        vm.startPrank(admin);
        mockERC20 = new MockERC20();
        vault = new Vault();
        vault.initialize(mockERC20);
        vm.stopPrank();
    }

    function test_CheckOwner() public view {
        console.log(vault.totalAssets());
        assertEq(vault.owner(), admin);
    }
}
