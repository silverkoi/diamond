// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ERC-173 Contract Ownership Standard
interface IERC173 {
    /// @dev This is emitted when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Gets the address of the owner
    /// @return owner_ The address of the owner
    function owner() external view returns (address owner_);

    /// @notice Sets the address of the new owner of the contract
    /// @dev Sets _newOwner to address(0) to renounce any ownership
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}
