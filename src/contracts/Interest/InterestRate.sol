// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IGovernor } from '../common/interfaces/IGovernor.sol';
import { IBorrowVault } from '../common/interfaces/IBorrowVault.sol';
import { ISupplyVault } from '../common/interfaces/ISupplyVault.sol';
import { Math } from '../common/libraries/Math.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IAccessRegistry} from '../common/interfaces/IAccessRegistry.sol';

struct InterestCurveParameters {
    uint baseMultiplier;
    uint jumpMultiplier;
    uint borrowBaseRate;
    uint optimalUR;
    uint reserveFactor;
}

contract InterestRate is UUPSUpgradeable {

    error INVALID_ACCESS();
    error ZERO_ADDRESS();


    bytes32 private constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN_ROLE');
    uint constant BASE = 1e18; // Scaling factor
    mapping(address => InterestCurveParameters) public marketToInterestRateParams;
    address public diamond;
    address public accessRegistry;

    modifier notZeroAddress(address check){
    if(check==address(0)){
        revert ZERO_ADDRESS();
    }
    _;
   }

   modifier onlySuperAdminRole(){
    address caller = msg.sender;
    if (!IAccessRegistry(accessRegistry).hasRole(SUPER_ADMIN_ROLE, caller)) {
            revert INVALID_ACCESS();
        }
        _;
   } 

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the diamond and access control addresses.
    /// @param _diamond The address of the diamond contract.
    /// @param _accessRegistry The address of the access Registry contract.
    function initializeInterestRate(address _diamond, address _accessRegistry) external initializer {
        accessRegistry = _accessRegistry;
        diamond = _diamond;
    }

    /// @notice Sets interest rate parameters for a specific market.
    /// @param market The address of the market for which to set parameters.
    /// @param baseMultiplier The base multiplier for interest rate calculation.
    /// @param jumpMultiplier The multiplier for jump rate calculations.
    /// @param borrowBaseRate The base borrowing rate.
    /// @param optimalUR The optimal utilization rate.
    /// @param reserveFactor The reserve factor for the market.
    function setInterestRateParameters(
        address market,
        uint baseMultiplier,  
        uint jumpMultiplier,  
        uint borrowBaseRate,  
        uint optimalUR,       
        uint reserveFactor    
    )
        external
    {
        // assertRole(GOVERNOR_ROLE);
        marketToInterestRateParams[market] =
            InterestCurveParameters(baseMultiplier, jumpMultiplier, borrowBaseRate, optimalUR, reserveFactor);
    }

    /// @notice Retrieves the interest rate parameters for a specific market.
    /// @param market The address of the market.
    /// @return InterestCurveParameters The interest rate parameters for the market.
    function getInterestRateParameters(address market) external view returns (InterestCurveParameters memory) {
        return marketToInterestRateParams[market];
    }

    /// @notice Calculates the current supply and borrow interest rates for a market.
    /// @param market The address of the market.
    /// @return supplyRate The current supply interest rate.
    /// @return borrowRate The current borrow interest rate.
    function getInterestRates(address market) external returns (uint, uint) {
        return _getInterestRates(market);
    }

    /// @notice Calculates the annual percentage rates (APRs) for supply and borrow rates.
    /// @param market The address of the market.
    /// @return supplyAPR The supply APR.
    /// @return borrow_apr The borrow APR.
    function getAPRs(address market) external returns (uint, uint) {
        (uint supplyRate, uint borrowRate) = _getInterestRates(market);
        uint secondsPerYear = 60 * 60 * 24 * 365;
        uint supplyAPR = supplyRate / secondsPerYear * 100;
        uint borrow_apr = borrowRate / secondsPerYear * 100;
        return (supplyAPR, borrow_apr);
    }

    /// @notice Calculates the supply APR for a market.
    /// @param market The address of the market.
    /// @return supplyAPR The calculated supply APR.
    function getSupplyAPR(address market) external returns (uint) {
        (uint supplyRate,) = _getInterestRates(market);
        uint secondsPerYear = 60 * 60 * 24 * 365;
        uint supplyAPR = supplyRate / secondsPerYear * 100;
        return supplyAPR;
    }

    /// @notice Calculates the borrow APR for a market.
    /// @param market The address of the market.
    /// @return borrow_apr The calculated borrow APR.
    function getBorrowAPR(address market) external returns (uint) {
        (, uint borrowRate) = _getInterestRates(market);
        uint secondsPerYear = 60 * 60 * 24 * 365;
        uint borrow_apr = borrowRate / secondsPerYear * 100;
        return borrow_apr;
    }

    /// @notice Retrieves the current utilization rate for a market.
    /// @param market The address of the market.
    /// @return utilizationRate The current utilization rate.
    function getUtilizationRate(address market) public returns (uint) {
        address deposit_vault = IGovernor(diamond).getRTokenFromAsset(market);
        address borrow_vault = IGovernor(diamond).getDTokenFromAsset(market);
        return _getUtilizationRate(borrow_vault, deposit_vault);
    }

    /// @notice Calculates the current interest rates for a market.
    /// @param market The address of the market.
    /// @return supplyRate The current supply interest rate.
    /// @return borrowRate The current borrow interest rate.
    function _getInterestRates(address market) internal notZeroAddress(market) returns (uint, uint) {
        InterestCurveParameters memory interest_curve_params = marketToInterestRateParams[market];
        uint utilization_rate = getUtilizationRate(market) / BASE;
        uint borrowRate = interest_curve_params.borrowBaseRate
            + Math.min(utilization_rate, interest_curve_params.optimalUR)
            + interest_curve_params.jumpMultiplier * Math.max(0, (utilization_rate - interest_curve_params.optimalUR));
        uint supplyRate = borrowRate * utilization_rate * (BASE - interest_curve_params.reserveFactor);

        return (supplyRate, borrowRate);
    }

    /// @notice Calculates the current utilization rate based on borrow and supply vaults.
    /// @param borrow_vault The address of the borrow vault.
    /// @param deposit_vault The address of the deposit vault.
    /// @return utilizationRate The current utilization rate.
    function _getUtilizationRate(address borrow_vault, address deposit_vault) internal returns (uint) {
        uint borrow_reserves = IBorrowVault(borrow_vault).getUnderlyingDebt();
        uint supply_reserves = ISupplyVault(deposit_vault).unaccruedTotalAssets();

        return (borrow_reserves * BASE / supply_reserves);
    }

    /// @notice Authorizes an upgrade to a new implementation.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal virtual override onlySuperAdminRole { }
}