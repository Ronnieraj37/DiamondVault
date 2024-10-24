// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from './ERC20.sol';
import { Ownable } from './Ownable.sol';

contract MockERC20 is ERC20, Ownable {
    constructor(
        address initialOwner,
        string memory name_,
        string memory symbol_,
        uint8 decimals
    )
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    {
        _setupDecimals(decimals);
        _mint(initialOwner, 100 * 10 ** 6);
        transferOwnership(initialOwner);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure override returns (bytes calldata) {
        return msg.data;
    }
}
