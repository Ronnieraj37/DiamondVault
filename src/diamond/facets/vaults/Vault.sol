//OpenZeppelin/openzeppelin-contracts-upgradeable

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Vault is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    uint256 public reserveFactor; // Reserve factor
    uint256 private constant FACTOR_BASE = 10000; // Basis points

    uint256 public reserveBalance;
    IPool public lendingPool; // Aave's lending pool

    mapping(address => uint256) public depositBalances; // Tracks deposit balances per user

    // Initialize the contract and setup the ERC4626 vault for USDC (or any ERC20 asset)
    function initialize(IERC20 _asset) public initializer {
        reserveFactor = 500;
        __ERC4626_init(_asset); // Initialize ERC4626 with the USDC token as the asset
        __ERC20_init("Vault Tokens", "vTKN"); // Initialize the ERC20 vault shares (e.g., "vTKN")
        __Ownable_init(_msgSender()); // Initialize Ownable for access control
        __UUPSUpgradeable_init(); // Initialize UUPS proxy support
        lendingPool = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
    }

    // Required override function to authorize contract upgrades (onlyOwner)
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // You can override ERC4626 deposit/withdraw methods to include custom logic if necessary
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        // Transfer assets from user to the vault
        SafeERC20.safeTransferFrom(
            IERC20(asset()),
            msg.sender,
            address(this),
            assets
        );

        // Deposit the assets into Aave
        lendingPool.deposit(address(asset()), assets, address(this), 0);

        // Calculate shares to mint (Vault ERC4626 logic)
        uint256 shares = previewDeposit(assets);

        // Mint corresponding vault tokens (vTKN) for the receiver
        _mint(receiver, shares);

        // Track deposited assets for the receiver
        depositBalances[receiver] += assets;

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    // Override withdraw function to apply reserve factor on profits only
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        // Calculate the user's initial deposit balance
        uint256 userDepositBalance = depositBalances[owner];

        // Calculate profits (if any) and apply reserve factor
        uint256 profit = 0;
        if (assets > userDepositBalance) {
            profit = assets - userDepositBalance;
        }

        uint256 reserveAmount = (profit * reserveFactor) / FACTOR_BASE;
        uint256 netAssetsToWithdraw = assets - reserveAmount;

        // Update reserve balance
        reserveBalance += reserveAmount;

        // Update deposit balances
        if (assets <= userDepositBalance) {
            depositBalances[owner] -= assets;
        } else {
            depositBalances[owner] = 0;
        }

        // Redeem the necessary amount of aTokens from Aave
        lendingPool.withdraw(address(asset()), netAssetsToWithdraw, receiver);

        return netAssetsToWithdraw;
    }

    // Set the reserve factor (only the owner can modify)
    function setReserveFactor(uint256 _reserveFactor) external onlyOwner {
        require(_reserveFactor <= 2000, "Reserve factor cannot exceed 20%");
        reserveFactor = _reserveFactor;
    }

    // Allows the owner to withdraw from the reserve balance if needed
    function withdrawReserves(address to, uint256 amount) external onlyOwner {
        require(amount <= reserveBalance, "Not enough reserves");
        reserveBalance -= amount;
        IERC20(asset()).transfer(to, amount); // Transfer the reserve amount to the owner
    }
}
