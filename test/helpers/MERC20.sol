// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from './ERC20.sol';
import { Ownable } from './Ownable.sol';

contract MERC20 is ERC20, Ownable {
    uint256 private constant MINTING_LIMIT = 10000; // 10,000 tokens in wei
    uint256 private constant MINTING_INTERVAL = 24 hours;

    mapping(address => uint256) private lastMintTime;
    mapping(address => uint256) private mintedAmount;

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
        _mint(initialOwner, MINTING_LIMIT * 10**decimals);
        transferOwnership(initialOwner);
    }

    function mint() public {
        require(
            block.timestamp >= lastMintTime[msg.sender] + MINTING_INTERVAL,
            "Minting interval not elapsed"
        );
        lastMintTime[msg.sender] = block.timestamp;
        _mint(msg.sender,MINTING_LIMIT * 10**decimals() );
    }

    function _msgSender() internal view override returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure override returns (bytes calldata) {
        return msg.data;
    }
}