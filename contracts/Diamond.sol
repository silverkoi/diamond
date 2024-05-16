// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {DiamondImpl} from "./impls/DiamondImpl.sol";

error FunctionNotFound(bytes4 _selector);

contract Diamond is DiamondImpl {
    struct Args {
        address owner;
        address init;
        bytes initCalldata;
    }

    constructor(IDiamondCut.FacetCut[] memory _cuts, Args memory _args) {
        _setOwner(_args.owner);
        _diamondCut(_cuts, _args.init, _args.initCalldata);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        DiamondImpl.DiamondStorage storage s = _getDiamondStorage();
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
