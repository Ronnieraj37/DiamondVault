// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IGovernor } from '../common/interfaces/IGovernor.sol';
import { IERC20 } from '../common/interfaces/IERC20.sol';
import { SafeERC20 } from '../common/libraries/SafeERC20.sol';
import { Security } from '../common/security/security.sol';

contract Collector is Security {
    using SafeERC20 for IERC20;

    // Custom Errors
    error Collector__ZeroAmount();
    error Collector__LengthMismatched();
    error Collector__SharesOverflow();
    error Collector__ZeroShareHolders();
    error Collector__InvalidCaller();
    error Collector__InvalidAmount();

    bytes32 private constant GOVERNOR_ROLE = keccak256('GOVERNOR_ROLE');

    mapping(address => mapping(address => uint)) public allowance; // [account][asset] = allowance
    mapping(address => uint8) public addressToReserveShare; // [account] = % share
    mapping(uint8 => address) public indexToShareHolder; // [index_account] = account
    mapping(address => uint8) public shareHolderToIndex; // [account] = index
    mapping(address => uint) public marketToFeeAccumulated; // [market] = fee

    address public feeReceipent;
    uint8 public totalShareHolders = 1;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with access control.
    /// @param _accessControl The address of the access control contract.
    function initializeCollector(address _accessControl) external initializer {
        initilaizeSecurity(_accessControl);
    }

    /// @notice Fallback function to receive Ether.
    receive() external payable { }

    /// @notice Retrieves the total reserves of a specific asset.
    /// @param asset The address of the asset.
    /// @return The total balance of the asset in the contract.
    function getTotalReserves(address asset) external view returns (uint) {
        return IERC20(asset).balanceOf(address(this));
    }

    /// @notice Retrieves the total reserves of Ether held by the contract.
    /// @return The total Ether balance of the contract.
    function getTotalReserves() external view returns (uint) {
        return address(this).balance;
    }

    /// @notice Gets the balance of a specific account in Ether.
    /// @param account The address of the account.
    /// @return The balance of the account in Ether.
    function balanceOf(address account) external view returns (uint) {
        return allowance[address(0)][account];
    }

    /// @notice Gets the balance of a specific account for a given asset.
    /// @param asset The address of the asset.
    /// @param account The address of the account.
    /// @return The balance of the account for the specified asset.
    function balanceOf(address asset, address account) external view returns (uint) {
        return allowance[account][asset];
    }

    /// @notice Adds a new reserve shareholder.
    /// @param _shareHolder The address of the new shareholder.
    /// @param _reserveShare The percentage share of the shareholder.
    function addReserveShareHolder(address _shareHolder, uint8 _reserveShare) external {
        assertRole(GOVERNOR_ROLE);

        uint8 totalReserveShares = _reserveShare;
        for (uint8 i = 0; i < totalShareHolders; ++i) {
            totalReserveShares += addressToReserveShare[indexToShareHolder[i]];
        }
        if (totalReserveShares > 100) revert Collector__SharesOverflow();

        indexToShareHolder[totalShareHolders] = _shareHolder;
        shareHolderToIndex[_shareHolder] = totalShareHolders;
        addressToReserveShare[_shareHolder] = _reserveShare;
        totalShareHolders += 1;
    }

    /// @notice Removes a reserve shareholder by index.
    /// @param index The index of the shareholder to remove.
    function removeReserveShareHolder(uint8 index) external {
        assertRole(GOVERNOR_ROLE);
        if (totalShareHolders <= 1) revert Collector__ZeroShareHolders();

        addressToReserveShare[indexToShareHolder[index]] = 0;
        shareHolderToIndex[indexToShareHolder[index]] = 0;
        indexToShareHolder[index] = address(0);
        totalShareHolders -= 1;
    }

    /// @notice Transfers funds to a specified address.
    /// @param asset The address of the asset to transfer.
    /// @param amount The amount of the asset to transfer.
    /// @param to The recipient address.
    function transferFunds(address asset, uint amount, address to) external notZeroAddress(to) nonReentrant {
        _transferFunds(asset, to, amount);
    }

    /// @notice Withdraws funds from the contract to the caller's address.
    /// @param asset The address of the asset to withdraw.
    /// @param amount The amount of the asset to withdraw.
    function withdrawFunds(address asset, uint amount) external nonReentrant {
        _transferFunds(asset, msg.sender, amount);
    }

    /// @notice Withdraws fees for the designated fee recipient.
    /// @param asset The address of the asset to withdraw.
    /// @param amount The amount of fees to withdraw.
    function withdrawFees(address asset, uint amount) external notZeroAddress(asset) nonReentrant {
        if (msg.sender != feeReceipent) revert Collector__InvalidCaller();
        if (amount > IERC20(asset).balanceOf(address(this))) revert Collector__InvalidAmount();
        IERC20(asset).safeTransfer(feeReceipent, amount);
        _decreaseAllowances(asset, amount);
    }

    /// @notice Collects fees from a specified market.
    /// @param market The address of the market from which fees are collected.
    /// @param amount The amount of fees to collect.
    function collectFees(address market, uint amount) external notZeroAddress(market) nonReentrant {
        if (amount <= 0) revert Collector__ZeroAmount();
        IERC20(market).safeTransferFrom(msg.sender, address(this), amount);
        marketToFeeAccumulated[market] += amount;
        _increaseAllowances(market, amount);
    }

    /// @notice Increases allowances for shareholders based on collected fees.
    /// @param asset The address of the asset.
    /// @param amount The amount of fees collected.
    function _increaseAllowances(address asset, uint amount) private {
        for (uint8 i = 0; i < totalShareHolders; ++i) {
            address shareHolder = indexToShareHolder[i];
            uint amountToIncrease = (amount * addressToReserveShare[shareHolder]) / 100;
            uint updatedAllowance = allowance[shareHolder][asset] + amountToIncrease;
            _updateAllowance(asset, i, updatedAllowance);
        }
    }

    /// @notice Transfers funds while managing allowances.
    /// @param asset The address of the asset to transfer.
    /// @param receiver The address of the recipient.
    /// @param amount The amount to transfer.
    function _transferFunds(address asset, address receiver, uint amount) private {
        address caller = msg.sender;
        uint currentAllowance = allowance[caller][asset];
        if (currentAllowance < amount) revert Collector__InvalidAmount();
        if (amount > IERC20(asset).balanceOf(address(this))) revert Collector__InvalidAmount();
        IERC20(asset).safeTransfer(receiver, amount);

        _updateAllowance(asset, shareHolderToIndex[caller], currentAllowance - amount);
    }

    /// @notice Decreases allowances for shareholders when fees are withdrawn.
    /// @param asset The address of the asset.
    /// @param amount The amount of fees withdrawn.
    function _decreaseAllowances(address asset, uint amount) private {
        for (uint8 i = 0; i < totalShareHolders; ++i) {
            address shareHolder = indexToShareHolder[i];
            uint amountToDecrease = (amount * addressToReserveShare[shareHolder]) / 100;
            uint updatedAllowance = allowance[shareHolder][asset] - amountToDecrease;
            _updateAllowance(asset, i, updatedAllowance);
        }
    }

    /// @notice Updates the allowance for a specific shareholder.
    /// @param asset The address of the asset.
    /// @param index The index of the shareholder.
    /// @param amount The new allowance amount.
    function _updateAllowance(address asset, uint8 index, uint amount) private {
        allowance[indexToShareHolder[index]][asset] = amount;
    }

    /// @notice Authorizes the upgrade of the contract.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOpenRole { }
}