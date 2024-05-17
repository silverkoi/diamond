// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamond} from "../interfaces/IDiamond.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

error CannotAddSelectorThatAlreadyExists(bytes4 _selector);
error CannotAddSelectorsFromZeroAddress(bytes4[] _selectors);
error CannotRemoveImmutableFunction(bytes4 _selector);
error CannotRemoveSelectorThatDoesNotExist(bytes4 _selector);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceSelectorFromSameFacet(bytes4 _selector);
error CannotReplaceSelectorThatDoesNotExist(bytes4 _selector);
error CannotReplaceSelectorsWithZeroAddress(bytes4[] _selectors);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
error InvalidFacetCutAction(uint8 _action);
error NoBytecodeAtAddress(address _address);
error NoSelectorsProvidedForFacetForCut(address _facetAddress);
error RemoveFacetAddressMustBeZeroAddress(address _facetAddress);

abstract contract DiamondImpl {
    struct FacetAddressAndSelectorPosition {
        address facetAddress;
        uint16 selectorPosition;
    }

    /// @custom:storage-location erc7201:silverkoi.diamond.storage.diamond
    struct DiamondStorage {
        // function selector => facet address and selector position in selectors array
        mapping(bytes4 => FacetAddressAndSelectorPosition) facetAddressAndSelectorPosition;
        bytes4[] selectors;
    }

    // keccak256(abi.encode(uint256(keccak256("silverkoi.diamond.storage.diamond")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION =
        0xd789ad9d1731e9d82df8dd1a2f1a371da2ca98840c55f37a7c7ad2988d83c500;

    function _getDiamondStorage() internal pure returns (DiamondStorage storage $) {
        // solhint-disable no-inline-assembly
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    function _diamondCut(
        IDiamondCut.FacetCut[] memory _cuts,
        address _init,
        bytes memory _initCalldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _cuts.length; facetIndex++) {
            bytes4[] memory functionSelectors = _cuts[facetIndex].functionSelectors;
            address facetAddress = _cuts[facetIndex].facetAddress;
            if (functionSelectors.length == 0) {
                revert NoSelectorsProvidedForFacetForCut(facetAddress);
            }
            IDiamondCut.FacetCutAction action = _cuts[facetIndex].action;
            if (action == IDiamond.FacetCutAction.Add) {
                _addFunctions(facetAddress, functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Replace) {
                _replaceFunctions(facetAddress, functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Remove) {
                _removeFunctions(facetAddress, functionSelectors);
            } else {
                // NOTE: This does not seem to be reachable. As far as I can
                // tell, the EVM enforces that the enum is a valid value at
                // construction time.
                revert InvalidFacetCutAction(uint8(action));
            }
        }
        emit IDiamond.DiamondCut(_cuts, _init, _initCalldata);
        _initializeDiamondCut(_init, _initCalldata);
    }

    function _addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_facetAddress == address(0)) {
            revert CannotAddSelectorsFromZeroAddress(_functionSelectors);
        }
        DiamondStorage storage s = _getDiamondStorage();
        uint16 selectorCount = uint16(s.selectors.length);
        _enforceHasContractCode(_facetAddress);
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = s.facetAddressAndSelectorPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert CannotAddSelectorThatAlreadyExists(selector);
            }
            s.facetAddressAndSelectorPosition[selector] = FacetAddressAndSelectorPosition(
                _facetAddress,
                selectorCount
            );
            s.selectors.push(selector);
            selectorCount++;
        }
    }

    function _replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        DiamondStorage storage s = _getDiamondStorage();
        if (_facetAddress == address(0)) {
            revert CannotReplaceSelectorsWithZeroAddress(_functionSelectors);
        }
        _enforceHasContractCode(_facetAddress);
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = s.facetAddressAndSelectorPosition[selector].facetAddress;
            // can't replace immutable functions -- functions defined directly in the diamond in this case
            if (oldFacetAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if (oldFacetAddress == _facetAddress) {
                revert CannotReplaceSelectorFromSameFacet(selector);
            }
            if (oldFacetAddress == address(0)) {
                revert CannotReplaceSelectorThatDoesNotExist(selector);
            }
            // replace old facet address
            s.facetAddressAndSelectorPosition[selector].facetAddress = _facetAddress;
        }
    }

    function _removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        DiamondStorage storage s = _getDiamondStorage();
        uint256 selectorCount = s.selectors.length;
        if (_facetAddress != address(0)) {
            revert RemoveFacetAddressMustBeZeroAddress(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAddressAndSelectorPosition memory oldFacetAddressAndSelectorPosition = s
                .facetAddressAndSelectorPosition[selector];
            if (oldFacetAddressAndSelectorPosition.facetAddress == address(0)) {
                revert CannotRemoveSelectorThatDoesNotExist(selector);
            }

            // can't remove immutable functions -- functions defined directly in the diamond
            if (oldFacetAddressAndSelectorPosition.facetAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            selectorCount--;
            if (oldFacetAddressAndSelectorPosition.selectorPosition != selectorCount) {
                bytes4 lastSelector = s.selectors[selectorCount];
                s.selectors[oldFacetAddressAndSelectorPosition.selectorPosition] = lastSelector;
                s
                    .facetAddressAndSelectorPosition[lastSelector]
                    .selectorPosition = oldFacetAddressAndSelectorPosition.selectorPosition;
            }
            // delete last selector
            s.selectors.pop();
            delete s.facetAddressAndSelectorPosition[selector];
        }
    }

    function _initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        _enforceHasContractCode(_init);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                // solhint-disable no-inline-assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
                // solhint-enable no-inline-assembly
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function _enforceHasContractCode(address _contract) internal view {
        uint256 contractSize;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) {
            revert NoBytecodeAtAddress(_contract);
        }
    }
}
