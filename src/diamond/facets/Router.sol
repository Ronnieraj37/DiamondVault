// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./vaults/Vault.sol"; // Import the USDC vault contract
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultRouter is OwnableUpgradeable {
    // Mapping to store vault contracts for different tokens
    mapping(address => Vault) public vaults;

    event VaultAdded(address indexed token, address indexed vault);
    event Deposit(address indexed user, uint256 amount, address token);
    event Withdraw(address indexed user, uint256 amount, address token);

    // Initialize the router contract
    function initialize() public initializer {
        __Ownable_init(_msgSender());
    }

    // Add and initialize a new vault for a specific token
    function addVault(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");

        Vault usdcVault = new Vault();
        usdcVault.initialize(IERC20(token));

        vaults[token] = usdcVault;
        emit VaultAdded(token, address(usdcVault));
    }

    // Deposit assets into the vault associated with the given token
    function deposit(address token, uint256 amount, address receiver) external {
        Vault vault = vaults[token];
        require(address(vault) != address(0), "Vault not found for token");

        // Transfer the token from the user to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Approve the vault to spend the token and then deposit
        IERC20(token).approve(address(vault), amount);
        vault.deposit(amount, receiver);

        emit Deposit(receiver, amount, token);
    }

    // Withdraw assets from the vault associated with the given token
    function withdraw(
        address token,
        uint256 amount,
        address receiver
    ) external {
        Vault vault = vaults[token];
        require(address(vault) != address(0), "Vault not found for token");

        vault.withdraw(amount, receiver, msg.sender);
        emit Withdraw(msg.sender, amount, token);
    }

    // Set reserve factor for a specific vault (onlyOwner)
    function setReserveFactor(
        address token,
        uint256 reserveFactor
    ) external onlyOwner {
        Vault vault = vaults[token];
        require(address(vault) != address(0), "Vault not found for token");

        vault.setReserveFactor(reserveFactor);
    }

    // Withdraw reserves from a specific vault (onlyOwner)
    function withdrawReserves(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        Vault vault = vaults[token];
        require(address(vault) != address(0), "Vault not found for token");

        vault.withdrawReserves(to, amount);
    }
}
