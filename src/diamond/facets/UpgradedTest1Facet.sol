// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test1Facet, TestLib } from './Test1Facet.sol';

contract UpgradeTest1Facet is Test1Facet {
    // Override an existing function to change its behavior
    function test1Func1() external override {
        TestLib.setMyAddress(msg.sender); // Changed from address(this) to msg.sender
    }

    // Add a new function
    function test1Func21() external pure returns (string memory) {
        return 'This is a new function in the upgraded facet';
    }

    // Add another new function
    function test1Func22() external pure returns (uint) {
        return 42;
    }
}
