// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
// import { LibRouter } from '../libraries/LibRouter.sol';
// import { RouterStorage } from '../storages/RouterStorage.sol';
// import { Context } from '../../contracts/common/libraries/Context.sol';
// import { console } from 'forge-std/console.sol';
// import { IAccessRegistry } from '../../contracts/common/interfaces/IAccessRegistry.sol';

// contract OpenRouter is ReentrancyGuard {
//     bytes32 private constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN');

//     function initializeOpenRouter(address _diamond) external {
//         RouterStorage storage ds = LibRouter._routerStorage();
//         require(!ds.initialized, 'Already initialized');
//         ds.diamond = _diamond;
//         ds.initialized = true;
//     }

//     /// @notice Initiates a deposit request and mint rTokens
//     /// @param _asset Address of the asset to be deposited
//     /// @param _amount Amount of asset to be deposited
//     /// @param _receiver Address of the receiver
//     /// @return rShares Returns amount of rToken to be minted the receiver

//     function deposit(address _asset, uint _amount, address _receiver) external nonReentrant returns (uint rShares) {
//         // console.log('Deposit here: ');
//         rShares = LibRouter._deposit(_asset, _amount, _receiver);
//     }

//     /// @notice Withdraws the deposited assets from the deposit vault
//     /// @param _asset Address of the asset
//     /// @param _rTokenShares Amount of rTokens to be withdrawn
//     /// @param _receiver Address of the receiver of deposit
//     /// @param _owner Address of the owner of rTokens
//     /// @return asset Returns the amount of asset

//     function withdrawDeposit(
//         address _asset,
//         uint _rTokenShares,
//         address _receiver,
//         address _owner
//     )
//         external
//         nonReentrant
//         returns (uint asset)
//     {
//         asset = LibRouter._withdrawDeposit(_asset, _rTokenShares, _receiver, _owner);
//     }

//     function getDiamond() external view returns (address) {
//         return LibRouter._getGovernor();
//     }
// }
