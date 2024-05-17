// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamond} from "./IDiamond.sol";

interface IDiamondCut is IDiamond {
    /// @notice Add/replace/remove any number of functions and optionally
    /// execute a function with delegatecall
    /// @param _cuts Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and
    /// arguments calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _cuts,
        address _init,
        bytes calldata _calldata
    ) external;
}
