// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DiamondImpl} from "../impls/DiamondImpl.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

// WARNING: The functions in DiamondCutFacet MUST be added to a diamond. The
// EIP-2535 Diamond standard requires these functions.

contract DiamondCutFacet is IDiamondCut, DiamondImpl {
    /// @inheritdoc IDiamondCut
    function diamondCut(
        FacetCut[] calldata _cuts,
        address _init,
        bytes calldata _initCalldata
    ) external override {
        _checkIsOwner();
        _diamondCut(_cuts, _init, _initCalldata);
    }
}
