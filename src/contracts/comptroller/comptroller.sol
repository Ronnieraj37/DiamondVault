// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Security } from '../common/security/security.sol';

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

contract Comptroller is Security {
    bytes32 public constant COMPTROLLER_ROLE = keccak256('COMPTROLLER_ROLE');

    ProtocolFees public protocolFees;
    uint public leverage;
    uint public reserveFactor;
    uint32 public liquidationCallFactor;
    uint public protocolThresholdIncreaseFactor;

    event ProtocolFeesSet(ProtocolFees fees);
    event ReserveFactorSet(uint factor);
    event LiquidationCallFactorSet(uint32 factor);
    event ProtocolThresholdIncreaseFactorSet(uint factor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address accessControl) external initializer {
        initilaizeSecurity(accessControl);
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
        external
        onlyComptroller
    {
        protocolFees = ProtocolFees({
            depositRequestFee: depositRequestFee,
            withdrawDepositFee: withdrawDepositFee,
            loanRequestFee: loanRequestFee,
            loanRepayFee: loanRepayFee,
            l3InteractionFee: l3InteractionFee,
            revertL3InteractionFee: revertL3InteractionFee,
            stakingFee: stakingFee,
            unstakingFee: unstakingFee
        });
        emit ProtocolFeesSet(protocolFees);
    }

    function setReserveFactor(uint factor) external onlyComptroller {
        reserveFactor = factor;
        emit ReserveFactorSet(factor);
    }

    function setLiquidationCallFactor(uint32 factor) external onlyComptroller {
        liquidationCallFactor = factor;
        emit LiquidationCallFactorSet(factor);
    }

    function setProtocolThresholdIncreaseFactor(uint factor) external onlyComptroller {
        protocolThresholdIncreaseFactor = factor;
        emit ProtocolThresholdIncreaseFactorSet(factor);
    }

    // View functions

    function getProtocolFees() external view returns (ProtocolFees memory) {
        return protocolFees;
    }

    function getReserveFactor() external view returns (uint) {
        return reserveFactor;
    }

    function getLiquidationCallFactor() external view returns (uint32) {
        return liquidationCallFactor;
    }

    function getProtocolThresholdIncreaseFactor() external view returns (uint) {
        return protocolThresholdIncreaseFactor;
    }

    function checkPermissibleLtv()
        // address user,
        // address collateralMarket,
        // uint256 collateralAmount
        external
        pure
        returns (uint)
    {
        // Placeholder implementation
        return 500;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyComptroller { }

    modifier onlyComptroller() {
        if (!assertRole(COMPTROLLER_ROLE)) {
            revert INVALID_ACCESS();
        }
        _;
    }
}
