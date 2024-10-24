// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SupplyVault} from "../../src/contracts/supply/Supply.sol";
import {console} from "forge-std/console.sol";
import { ERC1967Proxy } from '@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol';
import {AccessRegistry} from "../../src/contracts/AccessRegistry/accessRegistry.sol";

contract DeploySupplyVault is Script{

    address mockAsset = 0x82426494326A5870d9AE0D3145F441bA0D5Ca4A3; //address of the Erc20 asset
    address public admin= 0x641BB2596D8c0b32471260712566BF933a2f1a8e;
    address governor = address(1);

     function run() external {
        // Start broadcast for actual deployment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Access Registry Conracts

        AccessRegistry accessRegistryImplementation = new  AccessRegistry();

        bytes memory data_AccessRegistry = abi.encodeWithSelector(AccessRegistry.initialize.selector, admin);

        ERC1967Proxy accessProxy = new ERC1967Proxy(address(accessRegistryImplementation), data_AccessRegistry);


         // Log the addresses
        console.log("Implementation AcessRegistry address:", address(accessRegistryImplementation));
        console.log("Proxy Access address:", address(accessProxy));


        // Deploy Supply side Contracts

        // Deploy the implementation contract
        SupplyVault supplyImplementation = new SupplyVault();

        // Encode the initializer data
        bytes memory data = abi.encodeWithSelector(
            SupplyVault.initialize.selector,
            address(mockAsset),
            'r_Sahitya_vault',
            'rSAHI',
            governor,
            address(accessProxy)
        );

        ERC1967Proxy supplyProxy = new ERC1967Proxy(address(supplyImplementation), data);

        vm.stopBroadcast();

        // Log the addresses
        console.log("Implementation Supply address:", address(supplyImplementation));
        console.log("Proxy Supply address:", address(supplyProxy));
    }

}
////source .env && forge script scripts/deploySupply.s.sol:DeploySupplyVault --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv



// == Logs ==
//   Implementation AcessRegistry address: 0xC837670e895D5Bd4F4882Ab4a88AAB7BC2DbF9b6
//   Proxy Access address: 0x7117A1AB21cfB7bbF88ADE0E5d5bd9f0ad806b73
//   Implementation Supply address: 0xf3d78B6E7AE01710f942B75FcF220eeCb1cf9baf
//   Proxy Supply address: 0x9d02822936761269684c22bf230304dFbDbC889D