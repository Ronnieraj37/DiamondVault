// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

library LibRouterStorage {
    bytes32 constant ROUTER_STORAGE_POSITION =
        keccak256("diamond.router.storage");

    struct RouterStorage {
        // Mapping to store the vault address for each token (e.g., USDC, USDT, DAI)
        mapping(address => address) vaults;
        // Enum to handle supported tokens
    }

    function routerStorage() internal pure returns (RouterStorage storage ds) {
        bytes32 position = ROUTER_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            ds.slot := position
        }
    }

    function getTokenAddress(
        address _tokenAddress
    ) internal view returns (address contractOwner_) {
        RouterStorage storage ds = routerStorage();
        return ds.vaults[_tokenAddress];
    }
}
