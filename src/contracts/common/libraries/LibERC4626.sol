// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from '../../common/interfaces/IERC20.sol';
import { IERC20Metadata } from '../../common/interfaces/IERC20Metadata.sol';
import { SafeERC20 } from '../../common/libraries/SafeERC20.sol';
import { Math } from '../../common/libraries/Math.sol';
import { console } from 'forge-std/console.sol';

error ERC20InsufficientBalance(address sender, uint balance, uint needed);
error ERC20InvalidSender(address sender);
error ERC20InvalidReceiver(address receiver);
error ERC20InsufficientAllowance(address spender, uint allowance, uint needed);
error ERC20InvalidApprover(address approver);
error ERC20InvalidSpender(address spender);
error ERC20ZeroAddress();
error ERC20AmountExceedBalance();

error ERC4626ZeroAssets();
error ERC4626ZeroShares();
error ERC4626ExceededMaxDeposit(address receiver, uint assets, uint max);
error ERC4626ExceededMaxMint(address receiver, uint shares, uint max);
error ERC4626ExceededMaxWithdraw(address owner, uint assets, uint max);
error ERC4626ExceededMaxRedeem(address owner, uint shares, uint max);

// ERC4626Storage
struct ERC4626Storage {
    address _asset;
    uint _totalSupply;
    string _symbol;
    string _name;
    mapping(address account => mapping(address spender => uint)) _allowances;
    mapping(address account => uint) _balances;
}

library LibERC4626 {
    using SafeERC20 for IERC20;
    using Math for uint;

    // keccak256("hashstack.erc4626.storage.balance")
    bytes32 constant ERC4626_STORAGE_BALANCE_POSITION =
        0xae9dc2c3c9afc8c7d79754f421d6d8287246039996d7b806929d2e6e2b596dfd;

    event Deposit(address from, address to, uint amount, uint shares);
    event Withdraw(address sender, address receiver, address owner, uint assets, uint shares);
    event Transfer(address from, address to, uint value);
    event Approval(address owner, address spender, uint value);

    /// @notice Gets the storage structure for ERC4626.
    /// @return ds The ERC4626Storage struct.
    function erc4626Storage() internal pure returns (ERC4626Storage storage ds) {
        bytes32 position = ERC4626_STORAGE_BALANCE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Initializes the ERC4626 storage with name, symbol, and asset address.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param asset The address of the underlying asset.
    /// @dev Reverts if the asset address is zero.
    function _initializeERC4626(string memory name, string memory symbol, address asset) internal {
        require(asset != address(0), 'asset address is not zero');
        ERC4626Storage storage info = erc4626Storage();
        info._asset = asset;
        info._name = name;
        info._symbol = symbol;
    }

    /// @notice Gets the address of the underlying asset.
    /// @return The asset address.
    function _asset() internal view returns (address) {
        return erc4626Storage()._asset;
    }

    /// @notice Gets the name of the token.
    /// @return The token name.
    function _name() internal view returns (string memory) {
        return erc4626Storage()._name;
    }

    /// @notice Gets the symbol of the token.
    /// @return The token symbol.
    function _symbol() internal view returns (string memory) {
        return erc4626Storage()._symbol;
    }

    /// @notice Gets the number of decimals for the token.
    /// @return The number of decimals.
    function _decimals() internal view returns (uint8) {
        return IERC20Metadata(_asset()).decimals();
    }

    /// @notice Handles the deposit of assets and mints shares to the receiver.
    /// @param sender The address of the sender.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The address to receive the minted shares.
    /// @return shares The amount of shares minted.
    /// @dev Reverts if the calculated shares are zero.
    function _deposit(address sender, uint assets, address receiver) internal returns (uint shares) {
        require((shares = _previewDeposit(assets)) != 0, 'zero Shares');
        IERC20(_asset()).safeTransferFrom(sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(sender, receiver, assets, shares);
        _afterDeposit(assets, shares);
    }

    /// @notice Mints new shares by transferring the required assets.
    /// @param sender The address of the sender.
    /// @param shares The amount of shares to mint.
    /// @param receiver The address to receive the shares.
    /// @return assets The amount of assets transferred.
    function _mint(address sender, uint shares, address receiver) internal returns (uint assets) {
        assets = _previewMint(shares);
        if (sender != address(this)) {
            IERC20(_asset()).safeTransferFrom(sender, address(this), assets);
        }
        _mint(receiver, shares);
        emit Deposit(sender, receiver, assets, shares);
        _afterDeposit(assets, shares);
    }

    /// @notice Withdraws assets by burning shares from the owner.
    /// @param sender The address of the sender.
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The address to receive the assets.
    /// @param owner The owner of the shares.
    /// @return shares The amount of shares burned.
    function _withdraw(address sender, uint assets, address receiver, address owner) internal returns (uint shares) {
        shares = _previewWithdraw(assets);
        if (sender != owner) {
            uint allowed = erc4626Storage()._allowances[owner][sender];
            console.log('allowed: ', allowed);
            if (allowed != type(uint).max) erc4626Storage()._allowances[owner][sender] = allowed - shares;
        }
        _beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(sender, receiver, owner, assets, shares);
        IERC20(IERC20(_asset())).safeTransfer(receiver, assets);
    }

    /// @notice Redeems shares for assets.
    /// @param sender The address of the sender.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address to receive the assets.
    /// @param owner The owner of the shares.
    /// @return assets The amount of assets received.
    function _redeem(address sender, uint shares, address receiver, address owner) internal returns (uint assets) {
        if (sender != owner) {
            uint allowed = erc4626Storage()._allowances[owner][sender];
            if (allowed != type(uint).max) erc4626Storage()._allowances[owner][sender] = allowed - shares;
        }
        require((assets = _previewRedeem(shares)) != 0, 'Zero Asset');
        _beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(sender, receiver, owner, assets, shares);
        if(sender != address(this)){
            IERC20(IERC20(_asset())).safeTransfer(receiver, assets);
        }
    }

    /// @notice Gets the total amount of assets held by this contract.
    /// @return The total assets held.
    function _totalAssets() internal view returns (uint) {
        return IERC20(_asset()).balanceOf(address(this));
    }

    /// @notice Gets the total supply of shares.
    /// @return The total supply of shares.
    function _totalSupply() internal view returns (uint) {
        return erc4626Storage()._totalSupply;
    }

    /// @notice Converts assets to shares based on current total supply.
    /// @param assets The amount of assets to convert.
    /// @return The equivalent amount of shares.
    function _convertToShares(uint assets) public view returns (uint) {
        uint supply = erc4626Storage()._totalSupply;
        return supply == 0 ? assets : assets.mulDiv(supply, _totalAssets());
    }

    /// @notice Converts shares to assets based on current total supply.
    /// @param shares The amount of shares to convert.
    /// @return The equivalent amount of assets.
    function _convertToAssets(uint shares) public view returns (uint) {
        uint supply = erc4626Storage()._totalSupply;
        return supply == 0 ? shares : shares.mulDiv(_totalAssets(), supply);
    }

    /// @notice Previews the shares received for a deposit of assets.
    /// @param assets The amount of assets to deposit.
    /// @return The estimated amount of shares received.
    function _previewDeposit(uint assets) public view returns (uint) {
        return _convertToShares(assets);
    }

    /// @notice Previews the assets needed to mint the specified amount of shares.
    /// @param shares The amount of shares to mint.
    /// @return The estimated amount of assets needed.
    function _previewMint(uint shares) public view returns (uint) {
        uint supply = erc4626Storage()._totalSupply;
        return supply == 0 ? shares : shares.mulDiv(_totalAssets(), supply);
    }

    /// @notice Previews the shares needed to withdraw the specified amount of assets.
    /// @param assets The amount of assets to withdraw.
    /// @return The estimated amount of shares needed.
    function _previewWithdraw(uint assets) public view returns (uint) {
        uint supply = erc4626Storage()._totalSupply;
        return supply == 0 ? assets : assets.mulDiv(supply, _totalAssets());
    }

    /// @notice Previews the assets received for redeeming the specified amount of shares.
    /// @param shares The amount of shares to redeem.
    /// @return The estimated amount of assets received.
    function _previewRedeem(uint shares) public view returns (uint) {
        return _convertToAssets(shares);
    }

    /// @notice Returns the maximum amount of assets that can be deposited.
    /// @param receiver The address of the receiver.
    /// @return The maximum amount of assets.
    function _maxDeposit(address receiver) public pure returns (uint) {
        return type(uint).max;
    }

    /// @notice Returns the maximum amount of shares that can be minted.
    /// @param receiver The address of the receiver.
    /// @return The maximum amount of shares.
    function _maxMint(address receiver) public pure returns (uint) {
        return type(uint).max;
    }

    /// @notice Returns the maximum amount of assets that can be withdrawn by the owner.
    /// @param owner The address of the owner.
    /// @return The maximum amount of assets.
    function _maxWithdraw(address owner) public view returns (uint) {
        return _convertToAssets(erc4626Storage()._balances[owner]);
    }

    /// @notice Returns the maximum amount of shares that can be redeemed by the owner.
    /// @param owner The address of the owner.
    /// @return The maximum amount of shares.
    function _maxRedeem(address owner) public view returns (uint) {
        return erc4626Storage()._balances[owner];
    }

    /// @notice Hook to perform actions before withdrawing assets.
    /// @param assets The amount of assets being withdrawn.
    /// @param shares The amount of shares being burned.
    function _beforeWithdraw(uint assets, uint shares) internal { }

    /// @notice Hook to perform actions after depositing assets.
    /// @param assets The amount of assets deposited.
    /// @param shares The amount of shares minted.
    function _afterDeposit(uint assets, uint shares) internal { }

    /// @notice Gets the balance of a specified account.
    /// @param account The address of the account.
    /// @return The balance of the specified account.
    function _balanceOf(address account) internal view returns (uint) {
        uint balanceOf = erc4626Storage()._balances[account];
        return balanceOf;
    }

    /// @notice Mints shares for a specified account.
    /// @param account The address of the account.
    /// @param value The amount of shares to mint.
    function _mint(address account, uint value) private {
        _update(address(0), account, value);
    }

    /// @notice Burns shares from a specified account.
    /// @param account The address of the account.
    /// @param value The amount of shares to burn.
    function _burn(address account, uint value) internal {
        _update(account, address(0), value);
    }

    /// @notice Gets the allowance for a spender from the owner.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The current allowance.
    function _allowance(address owner, address spender) internal view returns (uint) {
        uint allowance = erc4626Storage()._allowances[owner][spender];
        return allowance;
    }

    /// @notice Updates balances and emits Transfer event.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to transfer.
    function _update(address from, address to, uint value) private {
        ERC4626Storage storage ds = erc4626Storage();
        ERC4626Storage storage bs = erc4626Storage();

        if (from == address(0)) {
            bs._totalSupply += value;
        } else {
            uint fromBalance = ds._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                ds._balances[from] = fromBalance - value;
            }
        }
        if (to == address(0)) {
            unchecked {
                bs._totalSupply -= value;
            }
        } else {
            unchecked {
                ds._balances[to] += value;
            }
        }
        emit Transfer(from, to, value);
    }

    /// @notice Transfers tokens from sender to recipient.
    /// @param sender The address of the sender.
    /// @param recipient The address of the recipient.
    /// @param amount The amount to transfer.
    /// @return True if the transfer was successful.
    function _transfer(address sender, address recipient, uint amount) internal returns (bool) {
        ERC4626Storage storage ds = erc4626Storage();

        uint senderBalance = ds._balances[sender];
        uint newSenderBalance = senderBalance - amount;
        require(newSenderBalance > 0, 'amount exceeds balance');
        ds._balances[sender] = newSenderBalance;
        uint recipientBalance = ds._balances[recipient];
        uint newRecipientBalance = recipientBalance + amount;
        ds._balances[recipient] = newRecipientBalance;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /// @notice Transfers tokens from one account to another, spending allowance.
    /// @param sender The address of the sender.
    /// @param recipient The address of the recipient.
    /// @param amount The amount to transfer.
    /// @return True if the transfer was successful.
    function _transferFrom(address sender, address recipient, uint amount) internal returns (bool) {
        address caller = sender;
        _spendAllowance(sender, caller, amount);
        bool success = _transfer(sender, recipient, amount);
        return success;
    }

    /// @notice Reduces the allowance of a spender for an owner.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param amount The amount to reduce the allowance by.
    function _spendAllowance(address owner, address spender, uint amount) internal {
        ERC4626Storage storage ds = erc4626Storage();
        uint currentAllowance = ds._allowances[owner][spender];
        uint infinite = 2 ** 256 - 1;
        bool isInfinite = currentAllowance == infinite;
        if (!isInfinite) {
            uint newAllowance = currentAllowance - amount;
            _approve(owner, spender, newAllowance);
        }
    }

    /// @notice Sets the allowance for a spender from an owner.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param amount The amount to allow.
    /// @return True if the approval was successful.
    function _approve(address owner, address spender, uint amount) internal returns (bool) {
        ERC4626Storage storage ds = erc4626Storage();
        ds._allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    /// @notice Increases the allowance of a spender from the caller.
    /// @param caller The address of the caller.
    /// @param spender The address of the spender.
    /// @param addedValue The amount to increase the allowance by.
    function _increaseAllowance(address caller, address spender, uint addedValue) internal returns(bool){
        ERC4626Storage storage ds = erc4626Storage();
        uint currentAllowance = ds._allowances[caller][spender];
        uint newAllowance = currentAllowance + addedValue;
        return  _approve(caller, spender, newAllowance);
    }

    /// @notice Decreases the allowance of a spender from the caller.
    /// @param caller The address of the caller.
    /// @param spender The address of the spender.
    /// @param subtractedValue The amount to decrease the allowance by.
    function _decreaseAllowance(address caller, address spender, uint subtractedValue) internal returns(bool) {
        ERC4626Storage storage ds = erc4626Storage();
        uint currentAllowance = ds._allowances[caller][spender];
        uint newAllowance = currentAllowance - subtractedValue;
        return _approve(caller, spender, newAllowance);
    }

    /// @notice Manually decreases the allowance of a spender for an owner.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param subtractedValue The amount to decrease the allowance by.
    function _ERC20DecreaseAllowanceManual(address owner, address spender, uint subtractedValue) internal {
        if (spender == owner) {
            return;
        }
        ERC4626Storage storage ds = erc4626Storage();
        uint currentAllowance = ds._allowances[owner][spender];
        uint newAllowance = currentAllowance - subtractedValue;
        _approve(owner, spender, newAllowance);
    }
}