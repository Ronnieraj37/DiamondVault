// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SwapInfo, SpendLoanResult, RevertLoanResult } from '../../integrations/IntegrationStructs.sol';

interface IL3Integration {
    // Function to add a strategy
    function addStrategy(address strategyAddress) external;

    // Function to update a strategy
    function updateStrategy(uint8 strategyId, address strategyAddress) external;

    // Function to remove a strategy
    function removeStrategy(uint8 strategyId) external;

    // Function to add liquidity to a strategy
    function addLiquidity(uint8 strategyId, address token, uint amount) external returns (SpendLoanResult memory);

    // Function to remove liquidity from a strategy
    function removeLiquidity(uint8 strategyId, address token, uint amount) external returns (RevertLoanResult memory);

    // Function to swap tokens within a strategy
    function swapTokens(uint8 strategyId, SwapInfo memory swap_info) external returns (SpendLoanResult memory);

    // Function to revert a swap within a strategy
    function revertSwap(uint8 strategyId, SwapInfo memory swap_info) external returns (RevertLoanResult memory);

    // Function to get the current asset value for a given token
    function getAssetValue(uint8 strategyId, uint256 amount) external view returns (uint);

    // Public state variable to get the total number of strategies
    function totalStrategies() external view returns (uint8);

    function getStrategy(uint8 strategyId) external view returns (address);

    function getStrategyIndex(address strategy) external view returns (uint8);
}
