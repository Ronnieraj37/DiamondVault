// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
// import { SwapInfo, SpendLoanResult, RevertLoanResult } from './IntegrationStructs.sol';

// interface IStrategy {
//     function addLiquidity(address token, uint amount) external;
//     function removeLiquidity(address token, uint amount) external;
//     function swapTokens(address fromToken, address toToken, uint amount) external;
//     function revertSwap(address fromToken, address toToken, uint amount) external;
//     function getAssetValue(address token) external view returns (uint);
// }

// contract L3Integration is Ownable {
//     mapping(uint8 => address) private strategies;
//     mapping(address => uint8) private strategy_to_index;
//     uint8 public totalStrategies;

//     // Custom Errors
//     error L3Integration__StrategyNotFound();
//     error L3Integration__InvalidStrategyAddress();
//     error L3Integration__StrategyAlreadyExists();
//     error L3Integration__InvalidStrategyUpdate();
//     error L3Integration__StrategyUpdateFailed();
//     error L3Integration__StrategyRemovalFailed();
//     error L3Integration__ActionFailed(uint8 strategyId, string action);

//     // Events
//     event StrategyAdded(uint8 indexed strategyId, address strategyAddress);
//     event StrategyUpdated(uint8 indexed strategyId, address strategyAddress);
//     event StrategyRemoved(uint8 indexed strategyId);
//     event Interaction(uint8 indexed strategyId, string action, address token, uint amount);
//     event LiquidityAction(uint8 indexed strategyId, string action, address indexed token, uint amount);
//     event SwapAction(
//         uint8 indexed strategyId, string action, address indexed fromToken, address indexed toToken, uint amount
//     );

//     modifier validStrategy(uint8 strategyId) {
//         if (strategies[strategyId] == address(0)) revert L3Integration__StrategyNotFound();
//         _;
//     }

//     /// @notice Constructor that sets the owner of the contract.
//     /// @param owner The address of the contract owner.
//     constructor(address owner) Ownable(owner) { }

//     /// @notice Retrieves the strategy address associated with a given strategy ID.
//     /// @param strategyId The ID of the strategy.
//     /// @return The address of the strategy.
//     function getStrategy(uint8 strategyId) external view returns (address) {
//         return strategies[strategyId];
//     }

//     /// @notice Retrieves the strategy index associated with a given strategy address.
//     /// @param strategy The address of the strategy.
//     /// @return The index of the strategy.
//     function getStrategyIndex(address strategy) external view returns (uint8) {
//         return strategy_to_index[strategy];
//     }

//     /// @notice Adds a new strategy to the integration.
//     /// @param strategyAddress The address of the strategy to add.
//     function addStrategy(address strategyAddress) external onlyOwner {
//         if (strategyAddress == address(0)) revert L3Integration__InvalidStrategyAddress();
//         if (strategies[totalStrategies] != address(0)) revert L3Integration__StrategyAlreadyExists();

//         strategies[totalStrategies] = strategyAddress;
//         strategy_to_index[strategyAddress] = totalStrategies;
//         emit StrategyAdded(totalStrategies++, strategyAddress);
//     }

//     /// @notice Updates an existing strategy's address.
//     /// @param strategyId The ID of the strategy to update.
//     /// @param strategyAddress The new address of the strategy.
//     function updateStrategy(uint8 strategyId, address strategyAddress) external onlyOwner validStrategy(strategyId) {
//         if (strategyAddress == address(0)) revert L3Integration__InvalidStrategyAddress();
//         if (strategies[strategyId] == address(0)) revert L3Integration__StrategyUpdateFailed();

//         delete strategy_to_index[strategies[strategyId]];
//         strategies[strategyId] = strategyAddress;
//         strategy_to_index[strategyAddress] = strategyId;
//         emit StrategyUpdated(strategyId, strategyAddress);
//     }

//     /// @notice Removes a strategy from the integration.
//     /// @param strategyId The ID of the strategy to remove.
//     function removeStrategy(uint8 strategyId) external onlyOwner validStrategy(strategyId) {
//         delete strategy_to_index[strategies[strategyId]];
//         delete strategies[strategyId];
//         if (totalStrategies > 0) {
//             --totalStrategies;
//         }
//         emit StrategyRemoved(strategyId);
//     }

//     /// @notice Adds liquidity to a specified strategy.
//     /// @param strategyId The ID of the strategy to which liquidity will be added.
//     /// @param token The address of the token to add liquidity.
//     /// @param amount The amount of the token to add.
//     /// @return A SpendLoanResult indicating the result of the operation.
//     function addLiquidity(
//         uint8 strategyId,
//         address token,
//         uint amount
//     )
//         external
//         validStrategy(strategyId)
//         returns (SpendLoanResult memory)
//     {
//         IStrategy strategy = IStrategy(strategies[strategyId]);

//         try strategy.addLiquidity(token, amount) {
//             emit LiquidityAction(strategyId, 'addLiquidity', token, amount);
//         } catch (bytes memory reason) {
//             revert L3Integration__ActionFailed(strategyId, 'addLiquidity');
//         }

//         return SpendLoanResult();
//     }

//     /// @notice Removes liquidity from a specified strategy.
//     /// @param strategyId The ID of the strategy to which liquidity will be removed.
//     /// @param token The address of the token to remove liquidity.
//     /// @param amount The amount of the token to remove.
//     /// @return A RevertLoanResult indicating the result of the operation.
//     function removeLiquidity(
//         uint8 strategyId,
//         address token,
//         uint amount
//     )
//         external
//         validStrategy(strategyId)
//         returns (RevertLoanResult memory)
//     {
//         IStrategy strategy = IStrategy(strategies[strategyId]);
//         try strategy.removeLiquidity(token, amount) {
//             emit LiquidityAction(strategyId, 'removeLiquidity', token, amount);
//         } catch (bytes memory reason) {
//             revert L3Integration__ActionFailed(strategyId, 'removeLiquidity');
//         }

//         return RevertLoanResult();
//     }

//     /// @notice Swaps tokens within a specified strategy.
//     /// @param strategyId The ID of the strategy where the swap will occur.
//     /// @param swap_info The swap information including tokens and amount.
//     /// @return A SpendLoanResult indicating the result of the swap.
//     function swapTokens(
//         uint8 strategyId,
//         SwapInfo memory swap_info
//     )
//         external
//         validStrategy(strategyId)
//         returns (SpendLoanResult memory)
//     {
//         IStrategy strategy = IStrategy(strategies[strategyId]);

//         try strategy.swapTokens(swap_info.fromToken, swap_info.toToken, swap_info.amount) {
//             emit SwapAction(strategyId, 'swapTokens', swap_info.fromToken, swap_info.toToken, swap_info.amount);
//         } catch (bytes memory reason) {
//             revert L3Integration__ActionFailed(strategyId, 'swapTokens');
//         }

//         return SpendLoanResult();
//     }

//     /// @notice Reverts a swap within a specified strategy.
//     /// @param strategyId The ID of the strategy where the swap will be reverted.
//     /// @param swap_info The swap information including tokens and amount.
//     /// @return A RevertLoanResult indicating the result of the revert.
//     function revertSwap(
//         uint8 strategyId,
//         SwapInfo memory swap_info
//     )
//         external
//         validStrategy(strategyId)
//         returns (RevertLoanResult memory)
//     {
//         IStrategy strategy = IStrategy(strategies[strategyId]);

//         try strategy.revertSwap(swap_info.fromToken, swap_info.toToken, swap_info.amount) {
//             emit SwapAction(strategyId, 'revertSwap', swap_info.fromToken, swap_info.toToken, swap_info.amount);
//         } catch (bytes memory reason) {
//             revert L3Integration__ActionFailed(strategyId, 'revertSwap');
//         }

//         return RevertLoanResult();
//     }

//     /// @notice Retrieves the asset value for a specific token and strategy.
//     /// @param strategyId The ID of the strategy.
//     /// @param amount The amount of the token for which to get the asset value.
//     /// @return The value of the specified asset.
//     function getAssetValue(uint8 strategyId, uint amount) external view validStrategy(strategyId) returns (uint) {
//         IStrategy strategy = IStrategy(strategies[strategyId]);

//         try strategy.getAssetValue(strategy, amount) returns (uint value) {
//             return value;
//         } catch (bytes memory reason) {
//             revert L3Integration__ActionFailed(strategyId, 'getAssetValue');
//         }
//     }
// }
