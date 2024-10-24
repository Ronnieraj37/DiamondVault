// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from 'forge-std/console.sol';
import { TestBase } from './utils/TestBase.sol';
import { MockERC20 } from './helpers/MockERC20.sol';
import { ERC1967Proxy } from '@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol';
import { SupplyVault } from '../src/contracts/supply/SupplyVault.sol';
import { ERC20 } from './helpers/ERC20.sol';
import { Ownable } from './helpers/Ownable.sol';
import { AccessRegistry } from '../src/contracts/AccessRegistry/accessRegistry.sol';
import { Diamond } from '../src/diamond/Diamond.sol';
import { DiamondCutFacet } from '../src/diamond/facets/DiamondCutFacet.sol';
import { DiamondLoupeFacet } from '../src/diamond/facets/DiamondLoupeFacet.sol';
import { OwnershipFacet } from '../src/diamond/facets/OwnershipFacet.sol';
import { LoanModuleFacet } from '../src/diamond/facets/LoanModuleFacet.sol';
import { Governor } from '../src/diamond/facets/Governor.sol';
import { IDiamondCut } from '../src/diamond/interfaces/IDiamondCut.sol';
import { IDiamondLoupe } from '../src/diamond/interfaces/IDiamondLoupe.sol';
import { DiamondHelpers } from './helpers/DiamondHelpers.sol';
import {InterestRate} from '../src/contracts/Interest/InterestRate.sol';
import {BorrowVault} from '../src/contracts/borrow/BorrowVault.sol';

contract TestHelpers is TestBase, DiamondHelpers {
    MockERC20 public mockAssetUSDT;
    MockERC20 public mockAssetUSDC;
    MockERC20 public mockAssetDAI;

    //Access Registry Contract
    ERC1967Proxy public accessRegistryProxy;
    AccessRegistry public accessRegistryImplementation;
    AccessRegistry public wrappedAccessRegistryProxy;

    //Supply side USDT
    SupplyVault public wrappedSupplyProxyUSDT;

    //Supply side USDT
    SupplyVault public wrappedSupplyProxyUSDC;

    //Supply side USDT
    SupplyVault public wrappedSupplyProxyDAI;

    BorrowVault public wrappedBorrowProxyUSDT;

    //Supply side USDT
    BorrowVault public wrappedBorrowProxyUSDC;

    //Supply side USDT
    BorrowVault public wrappedBorrowProxyDAI;

    // address public admin = address(0x1);
    // address public user = address(0x2);

    //Diamond
    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    LoanModuleFacet public openRouter;
    Governor public governor;

    address[] facetAddresses;

    function setUpMocks(
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals
    )
        public
        returns (MockERC20)
    {
        vm.startPrank(owner);
        MockERC20 mockERC20 = new MockERC20(owner, name, symbol, decimals);
        vm.stopPrank();
        return mockERC20;
    }

    function setUpDiamond(address owner) public {
        vm.startPrank(owner);
        // Deploy other facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        governor = new Governor();
        openRouter = new LoanModuleFacet();

        // Deploy diamond
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Add facets
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('DiamondLoupeFacet')
        });
        // debug("Calle here :2");
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('OwnershipFacet')
        });
        // debug("Calle here :3");
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(governor),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('Governor')
        });

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(openRouter),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectors('LoanModuleFacet')
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

        // Initialize facet addresses array
        facetAddresses = IDiamondLoupe(address(diamond)).facetAddresses();

        //intialize the facets

        vm.stopPrank();
    }

    function setUpAccessRegistry(address owner) public {
        vm.startPrank(owner);

        accessRegistryImplementation = new AccessRegistry();

        bytes memory dataAccessRegistry =
            abi.encodeWithSelector(AccessRegistry.initializeAccessRegistry.selector, owner);

        accessRegistryProxy = new ERC1967Proxy(address(accessRegistryImplementation), dataAccessRegistry);

        wrappedAccessRegistryProxy = AccessRegistry(address(accessRegistryProxy));

        vm.stopPrank();

        vm.label(address(wrappedAccessRegistryProxy), 'AccessControl');
    }

    function setUpSupplyVault(
        address owner,
        address mockAsset,
        string memory rName,
        string memory rSymbol
    )
        public
        returns (SupplyVault)
    {
        vm.startPrank(owner);

        // Deploy the implementation contract
        SupplyVault supplyImplementation = new SupplyVault();

        // Encode the initializer data
        bytes memory data = abi.encodeWithSelector(
            SupplyVault.initializeSupply.selector,
            address(mockAsset),
            rName,
            rSymbol,
            address(governor),
            address(wrappedAccessRegistryProxy)
        );

        ERC1967Proxy supplyProxy = new ERC1967Proxy(address(supplyImplementation), data);

        SupplyVault wrappedSupplyProxy = SupplyVault(address(supplyProxy));

        // Log the addresses
        vm.label(address(supplyImplementation), 'SupplyVault');
        vm.label(address(mockAsset), 'Asset');
        vm.label(address(wrappedSupplyProxy), 'SupplyProxy');

        vm.stopPrank();

        return wrappedSupplyProxy;
    }


    function setUpBorrowVault(address owner,address mockAsset, string memory dName ,string memory dSymbol) public returns(BorrowVault){

        vm.startPrank(owner);

        // Deploy the implementation contract
        BorrowVault borrowImplementation = new BorrowVault();

        // Encode the initializer data
        bytes memory data = abi.encodeWithSelector(
            BorrowVault.initialize.selector,
            address(mockAsset),
            dName,
            dSymbol,
            address(wrappedAccessRegistryProxy),
            address(diamond)
        );

        ERC1967Proxy borrowProxy = new ERC1967Proxy(address(borrowImplementation), data);

        BorrowVault wrappedBorrowProxy = BorrowVault(address(borrowProxy));

        // Log the addresses
        vm.label(address(borrowImplementation), 'Borrow Vault Implementation');
        vm.label(address(mockAsset), 'Asset');
        vm.label(address(wrappedBorrowProxy), 'BorrowProxy');

        vm.stopPrank();

        return wrappedBorrowProxy;
    }

    function setUpInterestRate(address owner) public returns(InterestRate){

        vm.startPrank(owner);

        InterestRate interestRate = new InterestRate();
        address accessRegistry = address(wrappedAccessRegistryProxy);
        bytes memory data = abi.encodeWithSelector(
            InterestRate.initializeInterestRate.selector,
            address(diamond),
            address(accessRegistry)
        );

        ERC1967Proxy interestRateProxy = new ERC1967Proxy(address(interestRate), data);

        InterestRate wrappedInterestRateProxy = InterestRate(address(interestRateProxy));


        // Log the addresses
        vm.label(address(interestRate), 'Interest Rate Implementation');
        vm.label(address(wrappedInterestRateProxy), 'Interest Proxy');

        vm.stopPrank();
        return wrappedInterestRateProxy;
    }


}

//   function setInterestRateParameters(
//         address market,
//         uint baseMultiplier,  //1
//         uint jumpMultiplier,  //1.5
//         uint borrowBaseRate,  //
//         uint optimalUR,       //70
//         uint reserveFactor    //25
//     )
