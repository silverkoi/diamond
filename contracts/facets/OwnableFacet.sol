// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableImpl} from "../impls/OwnableImpl.sol";
import {IERC173} from "../interfaces/IERC173.sol";

contract OwnableFacet is IERC173, OwnableImpl {
    function transferOwnership(address _newOwner) external override {
        _checkIsOwner();
        _setOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = _owner();
    }
}
