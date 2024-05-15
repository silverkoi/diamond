// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";

error FunctionNotFound(bytes4 _selector);

contract Diamond {
    struct Args {
        address owner;
        address init;
        bytes initCalldata;
    }

    constructor(IDiamondCut.FacetCut[] memory _diamondCut, Args memory _args) {
        LibDiamond.setContractOwner(_args.owner);
        LibDiamond.diamondCut(_diamondCut, _args.init, _args.initCalldata);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        LibDiamond.DiamondStorage storage s = LibDiamond._s();
        // Get facet from function selector.
        address facet = s.facetAddressAndSelectorPosition[msg.sig].facetAddress;
        if (facet == address(0)) {
            revert FunctionNotFound(msg.sig);
        }
        // Execute external function from facet using delegatecall and return
        // any value.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy function selector and any arguments.
            calldatacopy(0, 0, calldatasize())
            // Execute function call using the facet.
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // Get any return value.
            returndatacopy(0, 0, returndatasize())
            // Return any return value or error back to the caller.
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
