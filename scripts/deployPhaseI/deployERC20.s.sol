// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../../test/helpers/MockERC20.sol";
import {console} from "forge-std/console.sol";

contract DeployERC20 is Script{

    MockERC20 public mockERC20;
    address public admin=0x641BB2596D8c0b32471260712566BF933a2f1a8e;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        mockERC20 = new MockERC20(admin, 'Sahitya', 'SAHI', 6);
        vm.stopBroadcast();

        console.log("Implementation addressV2:", address(mockERC20));
    }

    ////source .env && forge script scripts/deployERC20.s.sol:DeployERC20 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv

}