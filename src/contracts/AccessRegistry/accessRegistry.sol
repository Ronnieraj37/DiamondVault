// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControlUpgradeable } from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract AccessRegistry is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN_ROLE');
    bytes32 public constant OPEN_ROLE = keccak256('OPEN_ROLE');
    bytes32 public constant LIQUIDATOR_ROLE = keccak256('LIQUIDATOR_ROLE');

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeAccessRegistry(address superAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(SUPER_ADMIN_ROLE, superAdmin);
        _grantRole(OPEN_ROLE, superAdmin);
        _grantRole(LIQUIDATOR_ROLE, superAdmin);


        _setRoleAdmin(SUPER_ADMIN_ROLE, SUPER_ADMIN_ROLE);
        _setRoleAdmin(OPEN_ROLE, SUPER_ADMIN_ROLE);
        _setRoleAdmin(LIQUIDATOR_ROLE, SUPER_ADMIN_ROLE);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(SUPER_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(SUPER_ADMIN_ROLE) { }
}
