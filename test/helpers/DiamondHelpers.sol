// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/diamond/facets/OwnershipFacet.sol";
import {Test1Facet} from "../../src/diamond/facets/Test1Facet.sol";

// import {LoanModuleFacet} from "../../src/diamond/facets/LoanModuleFacet.sol";

contract DiamondHelpers {
    function getSelectors(
        string memory _facetName
    ) internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors;
        if (
            keccak256(abi.encodePacked(_facetName)) ==
            keccak256(abi.encodePacked("DiamondCutFacet"))
        ) {
            selectors = new bytes4[](1);
            selectors[0] = DiamondCutFacet.diamondCut.selector;
        } else if (
            keccak256(abi.encodePacked(_facetName)) ==
            keccak256(abi.encodePacked("DiamondLoupeFacet"))
        ) {
            selectors = new bytes4[](4);
            selectors[0] = DiamondLoupeFacet.facetFunctionSelectors.selector;
            selectors[1] = DiamondLoupeFacet.facets.selector;
            selectors[2] = DiamondLoupeFacet.facetAddress.selector;
            selectors[3] = DiamondLoupeFacet.facetAddresses.selector;
        } else if (
            keccak256(abi.encodePacked(_facetName)) ==
            keccak256(abi.encodePacked("OwnershipFacet"))
        ) {
            selectors = new bytes4[](2);
            selectors[0] = OwnershipFacet.transferOwnership.selector;
            selectors[1] = OwnershipFacet.owner.selector;
        } else if (
            keccak256(abi.encodePacked(_facetName)) ==
            keccak256(abi.encodePacked("Test1Facet"))
        ) {
            selectors = new bytes4[](20);
            selectors[0] = Test1Facet.test1Func1.selector;
            selectors[1] = Test1Facet.test1Func2.selector;
            selectors[2] = Test1Facet.test1Func3.selector;
            selectors[3] = Test1Facet.test1Func4.selector;
            selectors[4] = Test1Facet.test1Func5.selector;
            selectors[5] = Test1Facet.test1Func6.selector;
            selectors[6] = Test1Facet.test1Func7.selector;
            selectors[7] = Test1Facet.test1Func8.selector;
            selectors[8] = Test1Facet.test1Func9.selector;
            selectors[9] = Test1Facet.test1Func10.selector;
            selectors[10] = Test1Facet.test1Func11.selector;
            selectors[11] = Test1Facet.test1Func12.selector;
            selectors[12] = Test1Facet.test1Func13.selector;
            selectors[13] = Test1Facet.test1Func14.selector;
            selectors[14] = Test1Facet.test1Func15.selector;
            selectors[15] = Test1Facet.test1Func16.selector;
            selectors[16] = Test1Facet.test1Func17.selector;
            selectors[17] = Test1Facet.test1Func18.selector;
            selectors[18] = Test1Facet.test1Func19.selector;
            selectors[19] = Test1Facet.test1Func20.selector;
        }
        //  else if (
        //     keccak256(abi.encodePacked(_facetName)) ==
        //     keccak256(abi.encodePacked("LoanModuleFacet"))
        // ) {
        //     selectors = new bytes4[](4);
        //     selectors[0] = LoanModuleFacet.deposit.selector;
        //     selectors[1] = LoanModuleFacet.withdrawDeposit.selector;
        //     selectors[2] = LoanModuleFacet.initializeOpenRouter.selector;
        //     selectors[3] = LoanModuleFacet.getDiamond.selector;
        // }
        return selectors;
    }

    function removeSelectors(
        bytes4[] memory _selectors,
        bytes4[] memory _selectorsToRemove
    ) internal pure returns (bytes4[] memory) {
        bytes4[] memory newSelectors = new bytes4[](
            _selectors.length - _selectorsToRemove.length
        );
        uint index = 0;
        for (uint i = 0; i < _selectors.length; i++) {
            bool shouldRemove = false;
            for (uint j = 0; j < _selectorsToRemove.length; j++) {
                if (_selectors[i] == _selectorsToRemove[j]) {
                    shouldRemove = true;
                    break;
                }
            }
            if (!shouldRemove) {
                newSelectors[index] = _selectors[i];
                index++;
            }
        }
        return newSelectors;
    }

    function getDynamicBytes4Array(
        bytes4[1] memory input
    ) internal pure returns (bytes4[] memory) {
        bytes4[] memory result = new bytes4[](input.length);
        for (uint i = 0; i < input.length; i++) {
            result[i] = input[i];
        }
        return result;
    }
}
