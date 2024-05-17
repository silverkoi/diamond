// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Diamond, FunctionNotFound} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {OwnableFacet} from "../contracts/facets/OwnableFacet.sol";
import {IDiamond} from "../contracts/interfaces/IDiamond.sol";
import {IERC173} from "../contracts/interfaces/IERC173.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/impls/DiamondImpl.sol";

contract TestDiamond is Diamond {
    constructor(IDiamondCut.FacetCut[] memory cuts, Diamond.Args memory args) Diamond(cuts, args) {}

    function immutableFn() public pure returns (uint256) {
        return 135;
    }
}

contract TestHelper {
    function deployV0Facets() public returns (IDiamond.FacetCut[] memory cuts) {
        // Deploy facets.
        cuts = _deployCommonFacets();
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, Example1FacetV0.getX.selector);
            selectors = _append(selectors, Example1FacetV0.getY.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new Example1FacetV0()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, Example2Facet.getText.selector);
            selectors = _append(selectors, Example2Facet.setText.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new Example2Facet()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, ExampleInit.initialize.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new ExampleInit()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
    }

    function deployDiamond(
        uint256 x,
        uint256 y,
        string memory text
    ) public returns (address diamond, IDiamond.FacetCut[] memory cuts) {
        cuts = deployV0Facets();
        diamond = address(
            new TestDiamond(
                cuts,
                Diamond.Args({
                    owner: msg.sender,
                    init: address(cuts[cuts.length - 1].facetAddress),
                    initCalldata: abi.encodeWithSignature(
                        "initialize(uint256,uint256,string)",
                        x,
                        y,
                        text
                    )
                })
            )
        );
    }

    function makeArray(bytes4 x0) public pure returns (bytes4[] memory xs) {
        xs = new bytes4[](1);
        xs[0] = x0;
    }

    function makeArray(bytes4 x0, bytes4 x1) public pure returns (bytes4[] memory xs) {
        xs = new bytes4[](2);
        xs[0] = x0;
        xs[1] = x1;
    }

    function makeArray(bytes4 x0, bytes4 x1, bytes4 x2) public pure returns (bytes4[] memory xs) {
        xs = new bytes4[](3);
        xs[0] = x0;
        xs[1] = x1;
        xs[2] = x2;
    }

    function makeArray(
        IDiamond.FacetCut memory x0
    ) public pure returns (IDiamond.FacetCut[] memory xs) {
        xs = new IDiamond.FacetCut[](1);
        xs[0] = x0;
    }

    function makeArray(
        IDiamond.FacetCut memory x0,
        IDiamond.FacetCut memory x1,
        IDiamond.FacetCut memory x2
    ) public pure returns (IDiamond.FacetCut[] memory xs) {
        xs = new IDiamond.FacetCut[](3);
        xs[0] = x0;
        xs[1] = x1;
        xs[2] = x2;
    }

    function makeFacetsFromCuts(
        IDiamond.FacetCut[] memory cuts
    ) public pure returns (IDiamondLoupe.Facet[] memory facets) {
        facets = new IDiamondLoupe.Facet[](cuts.length);
        for (uint256 i; i < cuts.length; ++i) {
            facets[i] = IDiamondLoupe.Facet({
                facetAddress: cuts[i].facetAddress,
                functionSelectors: cuts[i].functionSelectors
            });
        }
    }

    function contains(
        IDiamondLoupe.Facet[] memory xs,
        IDiamondLoupe.Facet memory x
    ) public pure returns (bool) {
        for (uint256 i; i < xs.length; ++i) {
            if (equal(xs[i], x)) return true;
        }
        return false;
    }

    function equal(
        IDiamondLoupe.Facet[] memory xs,
        IDiamondLoupe.Facet[] memory ys
    ) public pure returns (bool) {
        if (xs.length != ys.length) return false;
        for (uint256 i; i < xs.length; ++i) {
            if (!equal(xs[i], ys[i])) return false;
        }
        return true;
    }

    function equal(
        IDiamondLoupe.Facet memory x,
        IDiamondLoupe.Facet memory y
    ) public pure returns (bool) {
        if (x.facetAddress != y.facetAddress) return false;
        if (x.functionSelectors.length != y.functionSelectors.length) return false;
        for (uint256 i; i < x.functionSelectors.length; ++i) {
            if (x.functionSelectors[i] != y.functionSelectors[i]) return false;
        }
        return true;
    }

    function equal(bytes4[] memory xs, bytes4[] memory ys) public pure returns (bool) {
        if (xs.length != ys.length) return false;
        for (uint256 i; i < xs.length; ++i) {
            if (xs[i] != ys[i]) return false;
        }
        return true;
    }

    function _append(
        IDiamond.FacetCut[] memory xs,
        IDiamond.FacetCut memory x
    ) internal pure returns (IDiamond.FacetCut[] memory result) {
        result = new IDiamond.FacetCut[](xs.length + 1);
        for (uint256 i; i < xs.length; ++i) {
            result[i] = xs[i];
        }
        result[xs.length] = x;
    }

    function _append(bytes4[] memory xs, bytes4 x) internal pure returns (bytes4[] memory result) {
        result = new bytes4[](xs.length + 1);
        for (uint256 i; i < xs.length; ++i) {
            result[i] = xs[i];
        }
        result[xs.length] = x;
    }

    function _deployCommonFacets() internal returns (IDiamond.FacetCut[] memory cuts) {
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, DiamondCutFacet.diamondCut.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new DiamondCutFacet()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, DiamondLoupeFacet.facets.selector);
            selectors = _append(selectors, DiamondLoupeFacet.facetFunctionSelectors.selector);
            selectors = _append(selectors, DiamondLoupeFacet.facetAddresses.selector);
            selectors = _append(selectors, DiamondLoupeFacet.facetAddress.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new DiamondLoupeFacet()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
        {
            bytes4[] memory selectors;
            selectors = _append(selectors, OwnableFacet.owner.selector);
            selectors = _append(selectors, OwnableFacet.transferOwnership.selector);

            cuts = _append(
                cuts,
                IDiamond.FacetCut({
                    facetAddress: address(new OwnableFacet()),
                    action: IDiamond.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }
    }
}

interface IExampleV0 {
    function immutableFn() external pure returns (uint256);
    function getX() external view returns (uint256);
    function getY() external view returns (uint256);
    function setText(string calldata text) external;
    function getText() external view returns (string memory);
}

interface IExampleV1 is IExampleV0 {
    function setZ(uint256 z) external;
    function getZ() external view returns (uint256);
}

interface IFake {
    function fakeMethod(uint256 x, bool y) external;
}

contract Example1FacetV0 {
    /// @custom:storage-location erc7201:test.example1
    struct Example1StorageV0 {
        uint256 x;
        uint256 y;
    }

    // keccak256(abi.encode(uint256(keccak256("test.example1")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION =
        0x42ec60d07f9010681bd4aaf2909df0ecd51e9859b622d5efe89f1e916108db00;

    function $Example1() internal pure returns (Example1StorageV0 storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    function getX() external view returns (uint256) {
        return $Example1().x;
    }

    function getY() external view returns (uint256) {
        return $Example1().y;
    }
}

contract Example1FacetV1 {
    /// @custom:storage-location erc7201:test.example1
    struct Example1StorageV1 {
        uint256 x;
        uint256 y;
        uint256 z;
    }

    // keccak256(abi.encode(uint256(keccak256("test.example1")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION =
        0x42ec60d07f9010681bd4aaf2909df0ecd51e9859b622d5efe89f1e916108db00;

    function $Example1() internal pure returns (Example1StorageV1 storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    function getX() external view returns (uint256) {
        return $Example1().x;
    }

    function getY() external view returns (uint256) {
        return $Example1().y / 2;
    }

    function setZ(uint256 z) external {
        require(z != 0, "cannot set z to zero");
        require(z != 1337); // Intentially have no error message.
        $Example1().z = z;
    }

    function getZ() external view returns (uint256) {
        return $Example1().z;
    }
}

contract Example2Facet {
    /// @custom:storage-location erc7201:test.example2
    struct Example2Storage {
        string text;
    }

    // keccak256(abi.encode(uint256(keccak256("test.example2")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION =
        0x11d25c1a3bd4514bb87463ed4074cbb2e8fdff5edc2b49e2aec28d63bb6d2500;

    function $Example2() internal pure returns (Example2Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    function setText(string calldata text) external {
        $Example2().text = text;
    }

    function getText() external view returns (string memory) {
        return $Example2().text;
    }
}

contract ExampleInit is Example1FacetV0, Example2Facet {
    function initialize(uint256 x, uint256 y, string calldata text) external {
        require(x != 0, "cannot initialize x to zero");
        require(y != 0); // Intentially have no error message.
        $Example1().x = x;
        $Example1().y = y;
        $Example2().text = text;
    }
}
