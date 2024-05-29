// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC173Impl} from "../impls/ERC173Impl.sol";
import {IERC173} from "../interfaces/IERC173.sol";

contract ERC173Facet is IERC173, ERC173Impl {
    function transferOwnership(address _newOwner) external override {
        _checkIsOwner();
        _setOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = _owner();
    }
}
