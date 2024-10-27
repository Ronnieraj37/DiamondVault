// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { TestBase } from './utils/TestBase.sol';
// import { Diamond } from '../src/diamond/Diamond.sol';
// import { DiamondCutFacet } from '../src/diamond/facets/DiamondCutFacet.sol';
// import { DiamondLoupeFacet } from '../src/diamond/facets/DiamondLoupeFacet.sol';
// import { OwnershipFacet } from '../src/diamond/facets/OwnershipFacet.sol';
// import { Test1Facet } from '../src/diamond/facets/Test1Facet.sol';
// import { IDiamondCut } from '../src/diamond/interfaces/IDiamondCut.sol';
// import { IDiamondLoupe } from '../src/diamond/interfaces/IDiamondLoupe.sol';
// import { DiamondHelpers } from './helpers/DiamondHelpers.sol';
// // import { LoanModuleFacet } from '../src/diamond/facets/LoanModuleFacet.sol';
// import { console } from 'forge-std/console.sol';

// contract DiamondTest is DiamondHelpers, TestBase {
//     Diamond diamond;
//     DiamondCutFacet diamondCutFacet;
//     DiamondLoupeFacet diamondLoupeFacet;
//     OwnershipFacet ownershipFacet;
//     Test1Facet test1Facet;
//     LoanModuleFacet openRouter;
//     address governor;

//     address[] facetAddresses;

//     function setUp() public {
//         // Deploy facets
//         diamondCutFacet = new DiamondCutFacet();
//         diamondLoupeFacet = new DiamondLoupeFacet();
//         ownershipFacet = new OwnershipFacet();
//         openRouter = new LoanModuleFacet();

//         // Deploy diamond
//         diamond = new Diamond(address(this), address(diamondCutFacet));

//         debug('Calle here :1');

//         // Add facets
//         IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
//         cut[0] = IDiamondCut.FacetCut({
//             facetAddress: address(diamondLoupeFacet),
//             action: IDiamondCut.FacetCutAction.Add,
//             functionSelectors: getSelectors('DiamondLoupeFacet')
//         });
//         debug('Calle here :2');
//         cut[1] = IDiamondCut.FacetCut({
//             facetAddress: address(ownershipFacet),
//             action: IDiamondCut.FacetCutAction.Add,
//             functionSelectors: getSelectors('OwnershipFacet')
//         });
//         debug('Calle here :3');
//         cut[2] = IDiamondCut.FacetCut({
//             facetAddress: address(openRouter),
//             action: IDiamondCut.FacetCutAction.Add,
//             functionSelectors: getSelectors('LoanModuleFacet')
//         });
//         debug('Calle here :4');

//         // // Ensure that each facet has selectors
//         require(cut[0].functionSelectors.length > 0, 'DiamondLoupeFacet has no selectors');
//         bytes4[] memory ownershipSelectors = getSelectors('OwnershipFacet');
//         // debug(
//         //     "OwnershipFacet selectors count:",
//         //     ownershipSelectors.length
//         // );
//         require(cut[1].functionSelectors.length > 0, 'OwnershipFacet has no selectors');

//         IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

//         // // Initialize facet addresses array
//         facetAddresses = IDiamondLoupe(address(diamond)).facetAddresses();
//     }

//     function testFacetCount() public {
//         assertEq(facetAddresses.length, 4);
//         // debug("hello ");
//     }

//     function testFacetFunctionSelectors() public {
//         bytes4[] memory selectors;
//         bytes4[] memory result;

//         selectors = getSelectors('DiamondCutFacet');
//         result = IDiamondLoupe(address(diamond)).facetFunctionSelectors(facetAddresses[0]);
//         assertEq(selectors.length, result.length);
//         for (uint i = 0; i < selectors.length; i++) {
//             assertEq(selectors[i], result[i]);
//         }

//         selectors = getSelectors('DiamondLoupeFacet');
//         result = IDiamondLoupe(address(diamond)).facetFunctionSelectors(facetAddresses[1]);
//         assertEq(selectors.length, result.length);
//         for (uint i = 0; i < selectors.length; i++) {
//             assertEq(selectors[i], result[i]);
//         }

//         selectors = getSelectors('OwnershipFacet');
//         result = IDiamondLoupe(address(diamond)).facetFunctionSelectors(facetAddresses[2]);
//         assertEq(selectors.length, result.length);
//         for (uint i = 0; i < selectors.length; i++) {
//             assertEq(selectors[i], result[i]);
//         }
//         selectors = getSelectors('LoanModuleFacet');
//         result = IDiamondLoupe(address(diamond)).facetFunctionSelectors(facetAddresses[3]);
//         assertEq(selectors.length, result.length);
//         for (uint i = 0; i < selectors.length; i++) {
//             assertEq(selectors[i], result[i]);
//         }
//     }

//     function testFacetAddresses() public {
//         assertEq(facetAddresses[0], IDiamondLoupe(address(diamond)).facetAddress(DiamondCutFacet.diamondCut.selector));
//         assertEq(facetAddresses[1], IDiamondLoupe(address(diamond)).facetAddress(DiamondLoupeFacet.facets.selector));
//         assertEq(
//             facetAddresses[2], IDiamondLoupe(address(diamond)).facetAddress(OwnershipFacet.transferOwnership.selector)
//         );
//         assertEq(facetAddresses[3], IDiamondLoupe(address(diamond)).facetAddress(LoanModuleFacet.deposit.selector));
//     }

//     function testAddTest1Functions() public {
//         test1Facet = new Test1Facet();
//         bytes4[] memory selectors = getSelectors('Test1Facet');

//         // debug("Number of selectors for Test1Facet:", selectors.length);

//         require(selectors.length > 0, 'No selectors for Test1Facet');

//         IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
//         cut[0] = IDiamondCut.FacetCut({
//             facetAddress: address(test1Facet),
//             action: IDiamondCut.FacetCutAction.Add,
//             functionSelectors: selectors
//         });

//         IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

//         // Verify that all selectors were
//         bytes4[] memory addedSelectors = IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(test1Facet));
//         assertEq(selectors.length, addedSelectors.length, 'Not all selectors were added');
//         for (uint i = 0; i < selectors.length; i++) {
//             assertEq(selectors[i], addedSelectors[i], 'Selector mismatch');
//         }
//     }

//     function testAddAndCallTest1Function() public {
//         testAddTest1Functions(); // Add Test1Facet functions first

//         bytes4[] memory selectors = IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(test1Facet));
//         // debug(
//         //     "Number of selectors added for Test1Facet:",
//         //     selectors.length
//         // );

//         // for (uint i = 0; i < selectors.length; i++) {
//         //     address facetAddress = IDiamondLoupe(address(diamond)).facetAddress(
//         //         selectors[i]
//         //     );
//         //     console.logBytes4(selectors[i]);
//         //     debug("Facet address:", facetAddress);
//         // }

//         // Check if the functions exist in the diamond
//         // debug(
//         //     "test1Func1 exists:",
//         //     IDiamondLoupe(address(diamond)).facetAddress(
//         //         Test1Facet.test1Func1.selector
//         //     ) != address(0)
//         // );
//         // debug(
//         //     "test1Func2 exists:",
//         //     IDiamondLoupe(address(diamond)).facetAddress(
//         //         Test1Facet.test1Func2.selector
//         //     ) != address(0)
//         // );

//         // Try to call each function and log the result
//         // try Test1Facet(address(diamond)).test1Func1() {
//         //     debug("test1Func1 called successfully");
//         // } catch Error(string memory reason) {
//         //     debug("test1Func1 failed:", reason);
//         // } catch (bytes memory lowLevelData) {
//         //     debug("test1Func1 failed with low-level error");
//         //     console.logBytes(lowLevelData);
//         // }

//         // try Test1Facet(address(diamond)).test1Func2() returns (address addr) {
//         //     debug("test1Func2 called successfully, returned:", addr);
//         // } catch Error(string memory reason) {
//         //     debug("test1Func2 failed:", reason);
//         // } catch (bytes memory lowLevelData) {
//         //     debug("test1Func2 failed with low-level error");
//         //     console.logBytes(lowLevelData);
//         // }

//         // Original assertions
//         Test1Facet(address(diamond)).test1Func1();
//         assertEq(Test1Facet(address(diamond)).test1Func2(), address(diamond));
//     }

//     function testRemoveFacet() public {
//         // First, add the Test1Facet
//         testAddTest1Functions();

//         // Verify that Test1Facet functions exist
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func1.selector) != address(0));
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func2.selector) != address(0));

//         // Prepare the cut to remove Test1Facet functions
//         IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
//         bytes4[] memory functionSelectors = new bytes4[](2);
//         functionSelectors[0] = Test1Facet.test1Func1.selector;
//         functionSelectors[1] = Test1Facet.test1Func2.selector;

//         cut[0] = IDiamondCut.FacetCut({
//             facetAddress: address(0), // Use address(0) to remove functions
//             action: IDiamondCut.FacetCutAction.Remove,
//             functionSelectors: functionSelectors
//         });

//         // Execute the cut to remove the facet
//         IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

//         // Verify that Test1Facet functions no longer exist
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func1.selector) == address(0));
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func2.selector) == address(0));

//         // Try to call a removed function (this should revert)
//         vm.expectRevert('Diamond: Function does not exist');
//         Test1Facet(address(diamond)).test1Func1();
//     }

//     function testUpgradeTest1Facet() public {
//         testAddTest1Functions(); // Add the original Test1Facet

//         upgradeTest1Facet = new UpgradeTest1Facet();

//         // Prepare the cut to upgrade Test1Facet
//         IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

//         // Only add the new function selectors
//         bytes4[] memory functionSelectors = new bytes4[](2);
//         functionSelectors[0] = UpgradeTest1Facet.test1Func21.selector;
//         functionSelectors[1] = UpgradeTest1Facet.test1Func22.selector;

//         cut[0] = IDiamondCut.FacetCut({
//             facetAddress: address(upgradeTest1Facet),
//             action: IDiamondCut.FacetCutAction.Add,
//             functionSelectors: functionSelectors
//         });

//         // Execute the cut to upgrade the facet
//         IDiamondCut(address(diamond)).diamondCut(cut, address(0), '');

//         // Verify that the new functions exist and point to the new facet
//         assertTrue(
//             IDiamondLoupe(address(diamond)).facetAddress(UpgradeTest1Facet.test1Func21.selector)
//                 == address(upgradeTest1Facet)
//         );
//         assertTrue(
//             IDiamondLoupe(address(diamond)).facetAddress(UpgradeTest1Facet.test1Func22.selector)
//                 == address(upgradeTest1Facet)
//         );

//         // Verify that the original functions still exist and point to the original facet
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func1.selector) == address(test1Facet));
//         assertTrue(IDiamondLoupe(address(diamond)).facetAddress(Test1Facet.test1Func2.selector) == address(test1Facet));

//         // Test calling functions from both facets
//         Test1Facet(address(diamond)).test1Func1();
//         assertEq(Test1Facet(address(diamond)).test1Func2(), address(diamond));
//         assertEq(UpgradeTest1Facet(address(diamond)).test1Func21(), 'This is a new function in the upgraded facet');
//         assertEq(UpgradeTest1Facet(address(diamond)).test1Func22(), 42);
//     }
// }
