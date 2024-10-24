// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SupplyVault} from "../../src/contracts/supply/Supply.sol";
import {console} from "forge-std/console.sol";

contract UpgradeSupply is Script{

    function run() external {
        // Start broadcast for actual deployment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        SupplyVault supplyImplementation = new SupplyVault();

        vm.stopBroadcast();

        // Log the addresses
        console.log("New Implementation Supply address:", address(supplyImplementation));
    }
}

////source .env && forge script scripts/deploySupplyII.s.sol:DeploySupply --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv