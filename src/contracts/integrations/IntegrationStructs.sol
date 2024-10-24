// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct SpendParams {
    uint loan_id;
    uint8 strategyId;
    IntegrationMethod method;
    uint min_amount_out; // min lp tokens or underlying asset after spend
    SwapInfo swap_info;
    bytes[] additional_params; // additional params. e.g. pool id for myswap
}

enum IntegrationMethod {
    Swap,
    RevertSwap,
    AddLiquidity,
    RemoveLiquidity
}

struct RevertSpendParams {
    uint loan_id;
    uint8 strategyId;
    IntegrationMethod method;
    uint min_amount_out; // min lp tokens or underlying asset after spend
    SwapInfo swap_info;
    bytes[] additional_params;
}

struct SwapInfo {
    address fromToken;
    address toToken;
    uint amount;
}

struct SpendLoanResult {
    uint loan_id;
    address spent_market;
    uint return_amount;
    bytes[] additional_params;
}

struct RevertLoanResult {
    //previous term - convert spent market to debt.
    uint loan_id;
    address current_market; //current_market_address
    //current_market_symbol
    uint current_amount; //current_amount
}
