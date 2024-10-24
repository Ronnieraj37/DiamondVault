// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1967Proxy } from '@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol';

contract ComptrollerProxy is ERC1967Proxy {
    constructor(address _implementation, bytes memory data) ERC1967Proxy(_implementation, data) { }
}
