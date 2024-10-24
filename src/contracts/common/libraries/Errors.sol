// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 */
library Errors {
    /// @dev arithmetic underflow or overflow
    uint internal constant UNDER_OVERFLOW = 0x11;

    /// @dev division or modulo by zero
    uint internal constant DIVISION_BY_ZERO = 0x12;
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */

    error InsufficientBalance(uint balance, uint needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint code) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}
