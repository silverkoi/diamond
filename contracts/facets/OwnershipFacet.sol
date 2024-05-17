// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DiamondImpl} from "../impls/DiamondImpl.sol";
import {IERC173} from "../interfaces/IERC173.sol";

contract OwnershipFacet is IERC173, DiamondImpl {
    function transferOwnership(address _newOwner) external override {
        _checkIsOwner();
        _setOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = _owner();
    }
}
