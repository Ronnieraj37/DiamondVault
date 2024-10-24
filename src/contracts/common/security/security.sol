// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { IAccessRegistry } from '../interfaces/IAccessRegistry.sol';

abstract contract Security is UUPSUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    error INVALID_ACCESS();
    error INVALID_ADDRESS();
    error ZERO_VALUE();

    bytes32 private constant OPEN_ROLE = keccak256('OPEN_ROLE');
    bytes32 private constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN_ROLE');

    bytes32 public constant AccessRegistrySlot = 0x4e5f991bca30eca2d4643aaefa807e88f96a4a97398933d572a3c0d973004a01;

    function initilaizeSecurity(address accessRegistry) internal initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _setAccessRegistry(accessRegistry);
    }

    function getAccessRegistry() public view returns (address accessRegistry) {
        assembly {
            accessRegistry := sload(AccessRegistrySlot)
        }
    }

    function assertRole(bytes32 role) internal view returns (bool) {
        address caller = _msgSender();
        address accessRegistry = getAccessRegistry();
        bool hasRole = IAccessRegistry(accessRegistry).hasRole(role, caller);
        return hasRole;
    }

    function isInitialized() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function pause() external whenNotPaused {
        assertRole(SUPER_ADMIN_ROLE);
        _pause();
    }

    function unPause() external whenPaused {
        assertRole(SUPER_ADMIN_ROLE);
        _unpause();
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    function _setAccessRegistry(address accessRegistry) internal {
        assembly {
            sstore(AccessRegistrySlot, accessRegistry)
        }
    }

    modifier notZeroAddress(address check) {
        if (check == address(0)) {
            revert INVALID_ADDRESS();
        }
        _;
    }

    modifier notZeroValue(uint value) {
        if (value == 0) {
            revert ZERO_VALUE();
        }
        _;
    }

    modifier onlyOpenRole() {
        if (!assertRole(OPEN_ROLE)) {
            revert INVALID_ACCESS();
        }
        _;
    }
      modifier onlySuperAdminRole() {
        if (!assertRole(SUPER_ADMIN_ROLE)) {
            revert INVALID_ACCESS();
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlySuperAdminRole{
    }
}