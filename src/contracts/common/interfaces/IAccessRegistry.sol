// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessRegistry {
    function hasRole(bytes32, address) external view returns (bool);
}
