// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInterestRate {
    struct InterestCurveParameters {
        uint base_multiplier;
        uint jump_multiplier;
        uint borrow_base_rate;
        uint optimal_ur;
        uint reserve_factor;
    }

    function getInterestRateParameters(address market) external view returns (InterestCurveParameters memory);

    function getInterestRates(address market) external view returns (uint, uint);

    function getAPRs(address market) external view returns (uint, uint);

    function getSupplyAPR(address market) external view returns (uint);

    function getBorrowAPR(address market) external view returns (uint);

    function getUtilizationRate(address market) external view returns (uint);
}