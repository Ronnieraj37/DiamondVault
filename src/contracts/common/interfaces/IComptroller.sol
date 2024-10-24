// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
    struct ProtocolFees {
        uint depositRequestFee;
        uint withdrawDepositFee;
        uint loanRequestFee;
        uint loanRepayFee;
        uint l3InteractionFee;
        uint revertL3InteractionFee;
        uint stakingFee;
        uint unstakingFee;
    }

    function setProtocolFees(
        uint depositRequestFee,
        uint withdrawDepositFee,
        uint loanRequestFee,
        uint loanRepayFee,
        uint l3InteractionFee,
        uint revertL3InteractionFee,
        uint stakingFee,
        uint unstakingFee
    )
        external;

    function setReserveFactor(uint factor) external;

    function setLiquidationCallFactor(uint32 factor) external;

    function setProtocolThresholdIncreaseFactor(uint factor) external;

    // View functions

    function getProtocolFees() external view returns (ProtocolFees memory);

    function getReserveFactor() external view returns (uint);

    function getLiquidationCallFactor() external view returns (uint32);

    function getProtocolThresholdIncreaseFactor() external view returns (uint);
    function transferAssetsToLoanFacet() external view returns (uint);
    function getLoanRepayFee() external view returns (uint);

    function checkPermissibleLtv(
        address user,
        address collateralMarket,
        uint collateralAmount
    )
        external
        pure
        returns (uint);
    function getL3InteractionFee() external view returns (uint);
    function getRevertL3InteractionFee() external view returns (uint);

    function getLoanRequestFee() external returns (uint);
}
