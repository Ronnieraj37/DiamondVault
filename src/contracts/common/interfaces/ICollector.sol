// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollector {
    function collectFees(address market, uint amount) external;
}
