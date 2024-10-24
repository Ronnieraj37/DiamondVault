// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SupplyVault } from '../../src/contracts/supply/SupplyVault.sol';

contract mockSupplyVault is SupplyVault {
    bytes32 private constant _varSlot = 0x981fabd528ef35c15bd9eeb2c2d9c8e56ea8f58c48a3d2c3b0556934281e1c60;

    function get_a() external view returns (uint a) {
        assembly {
            a := sload(_varSlot)
        }
    }

    function set_a(uint b) external {
        assembly {
            sstore(_varSlot, b)
        }
    }
}
