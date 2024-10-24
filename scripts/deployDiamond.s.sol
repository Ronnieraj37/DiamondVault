// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../test/helpers/MockERC20.sol";
import {console} from "forge-std/console.sol";
import {AccessRegistry} from "../src/contracts/AccessRegistry/accessRegistry.sol";
import { ERC1967Proxy } from '@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol';
import {SupplyVault} from "../src/contracts/supply/Supply.sol";
import {Diamond} from "../src/diamond/Diamond.sol";
import { DiamondCutFacet } from '../src/diamond/facets/DiamondCutFacet.sol';
import { DiamondLoupeFacet } from '../src/diamond/facets/DiamondLoupeFacet.sol';
import { OwnershipFacet } from '../src/diamond/facets/OwnershipFacet.sol';
import { OpenRouter } from '../src/diamond/facets/OpenRouter.sol';
import { Governor } from '../src/diamond/facets/Governor.sol';
import { IDiamondCut } from '../src/diamond/interfaces/IDiamondCut.sol';
import { IDiamondLoupe } from '../src/diamond/interfaces/IDiamondLoupe.sol';
import { DiamondHelpers } from '../test/helpers/DiamondHelpers.sol' ;


contract DeployDiamond is Script, DiamondHelpers {

    MockERC20 mockAssetUSDT;
    MockERC20 mockAssetUSDC;
    MockERC20 mockAssetDAI;

    AccessRegistry wrappedAccessProxy;

    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    OpenRouter public openRouter;
    Governor public governor;

    address[] facetAddresses;


    ERC1967Proxy rSupplyProxyUSDC;
    ERC1967Proxy rSupplyProxyUSDT;
    ERC1967Proxy rSupplyProxyDAI;


    address public admin=0xE4f3B256c27cE7c76C5D16Ae81838aA14d8846C8;

    function deployMocks(address owner,string memory name, string memory symbol, uint8 decimals) public returns(MockERC20){
        MockERC20 mockERC20 = new MockERC20(owner, name, symbol, decimals);
        return mockERC20;
    }

    function deployAccessRegistry(address owner) public {
          // Deploy Access Registry Conracts

        AccessRegistry accessRegistryImplementation = new  AccessRegistry();

        bytes memory data_AccessRegistry = abi.encodeWithSelector(AccessRegistry.initialize.selector, owner);

        ERC1967Proxy accessProxy = new ERC1967Proxy(address(accessRegistryImplementation), data_AccessRegistry);

        wrappedAccessProxy = AccessRegistry(address(accessProxy));


        // Log the addresses
        console.log("Implementation AcessRegistry address:", address(accessRegistryImplementation));
        console.log("Proxy Access address:", address(accessProxy));

    }

    function deployDiamond(address owner) public {

        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        governor = new Governor();
        openRouter = new OpenRouter();

        // Deploy diamond
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Add facets
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('DiamondLoupeFacet')
        });
        // console.log("Calle here :2");
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('OwnershipFacet')
        });
        // console.log("Calle here :3");
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(governor),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('Governor')
        });

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(openRouter),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('OpenRouter')
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

        // Initialize facet addresses array
        facetAddresses = IDiamondLoupe(address(diamond)).facetAddresses();
        
        // assert(facetAddresses.length, 5,"Diamond Not set Correctly");

    }

    function deploySupplyVault(address mockAsset,string memory rName,string memory rSymbol) public returns(ERC1967Proxy){

        // Deploy the implementation contract
        SupplyVault supplyImplementation = new SupplyVault();

        // Encode the initializer data
        bytes memory data = abi.encodeWithSelector(
            SupplyVault.initialize.selector,
            address(mockAsset),
            rName,
            rSymbol,
            address(governor),
            address(wrappedAccessProxy)
        );

        ERC1967Proxy supplyProxy = new ERC1967Proxy(address(supplyImplementation), data);

        // Log the addresses
        console.log("Token Info: ",rName);
        console.log("Implementation Supply address:", address(supplyImplementation));
        console.log("Proxy Supply address:", address(supplyProxy));
        
        return supplyProxy;
    }

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        mockAssetUSDT = deployMocks(admin,'USDT','USDT',6);
        mockAssetUSDC = deployMocks(admin,'USDC','USDC',6);
        mockAssetDAI = deployMocks(admin,'DAI','DAI',18);

        deployAccessRegistry(admin);

        deployDiamond(admin);

        rSupplyProxyUSDT = deploySupplyVault(address(mockAssetUSDT),'rUSDT','rUSDT');
        rSupplyProxyUSDC = deploySupplyVault(address(mockAssetUSDC),'rUSDC','rUSDC');
        rSupplyProxyDAI = deploySupplyVault(address(mockAssetDAI),'rDAI','rDAI');
        

        // Initialize Data SetUp

        // Diamond 

        Governor(address(diamond)).initializeGovernor(address(wrappedAccessProxy));

        OpenRouter(address(diamond)).initializeOpenRouter(address(diamond));

        // Access Registry Contract

        wrappedAccessProxy.grantRole(keccak256('GOVERNOR_ROLE'), address(governor));
        // accessProxy.grantRole(keccak256('GOVERNOR_ROLE'), address(diamond));

        // accessProxy.grantRole(keccak256('OPEN_ROLE'), address(openRouter));
        // accessProxy.grantRole(keccak256('OPEN_ROLE'), address(diamond));

        wrappedAccessProxy.grantRole(keccak256('ROUTER_ROLE'), address(openRouter));

        // accessProxy.grantRole(keccak256('GOVERNOR_ROLE'), address(admin));

        wrappedAccessProxy.grantRole(keccak256('OPEN_ROLE'), address(rSupplyProxyUSDC));
        wrappedAccessProxy.grantRole(keccak256('OPEN_ROLE'), address(rSupplyProxyUSDT));
        wrappedAccessProxy.grantRole(keccak256('OPEN_ROLE'), address(rSupplyProxyDAI));


        // SET Vault Metadata

        Governor(address(diamond)).setDepositVault(
            address(rSupplyProxyUSDT), address(mockAssetUSDT), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetUSDT), address(rSupplyProxyUSDT), address(0), 0
        );

        Governor(address(diamond)).setDepositVault(
            address(rSupplyProxyUSDC), address(mockAssetUSDC), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetUSDC), address(rSupplyProxyUSDC), address(0), 0
        );

        Governor(address(diamond)).setDepositVault(
            address(rSupplyProxyDAI), address(mockAssetDAI), true, false, false, 0, 0
        );

        Governor(address(diamond)).setAssetMetadata(
            address(mockAssetDAI), address(rSupplyProxyDAI), address(0), 0
        );

        vm.stopBroadcast();

    }

    ////source .env && forge script scripts/deployDiamond.s.sol:DeployDiamond --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv

}