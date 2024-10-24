// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Test } from 'forge-std/Test.sol';
import { TestErrors } from 'test/utils/TestErrors.sol';
import { TestLogging } from 'test/utils/TestLogging.sol';

abstract contract TestBase is Test, TestErrors, TestLogging {
    address internal leet = address(0x1337);
    address internal alice = address(0xa11ce);
    address internal deployer = address(this);

    constructor() {
        vm.label(leet, 'L33T');
        vm.label(alice, 'Alice');
        vm.label(deployer, 'Deployer');
    }
}
