// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC173} from "../interfaces/IERC173.sol";

error NotContractOwner(address _user, address _owner);

abstract contract OwnableImpl {
    /// @custom:storage-location erc7201:silverkoi.diamond.storage.ownable
    struct OwnableStorage {
        address owner;
    }

    // keccak256(abi.encode(uint256(keccak256("silverkoi.diamond.storage.ownable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION =
        0x0be3d9d83d2b0f043dd4da92e8b82c04b982e5bd83fdbf1e548b99284066d100;

    function _getOwnableStorage() internal pure returns (OwnableStorage storage $) {
        // solhint-disable no-inline-assembly
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    function _setOwner(address _newOwner) internal {
        OwnableStorage storage s = _getOwnableStorage();
        address previousOwner = s.owner;
        s.owner = _newOwner;
        emit IERC173.OwnershipTransferred(previousOwner, _newOwner);
    }

    function _owner() internal view returns (address owner_) {
        owner_ = _getOwnableStorage().owner;
    }

    function _checkIsOwner() internal view {
        if (msg.sender != _getOwnableStorage().owner) {
            revert NotContractOwner(msg.sender, _getOwnableStorage().owner);
        }
    }
}
