// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISecurity {
    function upgrade(address newImplmenatation) external;
    function pause() external;
    function unpause() external;
    function is_paused() external returns (bool);
    function set_access_control() external;
}
