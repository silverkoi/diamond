// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Diamond, FunctionNotFound} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../contracts/facets/OwnershipFacet.sol";
import {IDiamond} from "../contracts/interfaces/IDiamond.sol";
import {IERC173} from "../contracts/interfaces/IERC173.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/impls/DiamondImpl.sol";

import "./TestContracts.sol";

contract BaseTest is Test {
    TestHelper internal h;

    function setUp() public {
        h = new TestHelper();
    }
}

contract OwnershipTest is BaseTest {
    function testOwnerReturnsCorrectAddress(address owner) public {
        vm.assume(owner != address(0));
        vm.startPrank(owner);

        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        assertEq(IERC173(diamond).owner(), owner);
    }

    function testCannotTransferOwnershipIfNotOwner(address owner, address notOwner) public {
        vm.assume(owner != address(0));
        vm.assume(notOwner != address(0));
        vm.assume(owner != notOwner);

        vm.startPrank(owner);
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        vm.stopPrank();

        vm.startPrank(notOwner);

        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector, notOwner, owner));
        IERC173(diamond).transferOwnership(notOwner);
    }

    function testTransferOwnership(address owner, address newOwner) public {
        vm.assume(owner != address(0));
        vm.assume(newOwner != address(0));
        vm.assume(owner != newOwner);
        vm.startPrank(owner);

        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        assertEq(IERC173(diamond).owner(), owner);

        vm.expectEmit();
        emit IERC173.OwnershipTransferred(owner, newOwner);
        IERC173(diamond).transferOwnership(newOwner);

        assertEq(IERC173(diamond).owner(), newOwner);
    }
}

contract DiamondCutTest is BaseTest {
    function testDeployDiamondEmitsDiamondCutEvent() public {
        IDiamond.FacetCut[] memory cuts = h.deployV0Facets();
        address init = cuts[cuts.length - 1].facetAddress;
        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(uint256,uint256,string)",
            123,
            456,
            "hello"
        );

        vm.expectEmit();
        emit IDiamond.DiamondCut(cuts, init, initCalldata);

        new Diamond(
            cuts,
            Diamond.Args({owner: msg.sender, init: init, initCalldata: initCalldata})
        );
    }

    function testDiamondInitializationErrorBubblesUp() public {
        IDiamond.FacetCut[] memory cuts = h.deployV0Facets();
        address init = cuts[cuts.length - 1].facetAddress;
        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(uint256,uint256,string)",
            0,
            456,
            "hello"
        );

        vm.expectRevert("cannot initialize x to zero");
        new Diamond(
            cuts,
            Diamond.Args({owner: msg.sender, init: init, initCalldata: initCalldata})
        );
    }

    function testDiamondInitializationFailWithoutError() public {
        IDiamond.FacetCut[] memory cuts = h.deployV0Facets();
        address init = cuts[cuts.length - 1].facetAddress;
        bytes memory initCalldata = abi.encodeWithSignature(
            "initialize(uint256,uint256,string)",
            123,
            0,
            "hello"
        );

        vm.expectRevert(
            abi.encodeWithSelector(InitializationFunctionReverted.selector, init, initCalldata)
        );
        new Diamond(
            cuts,
            Diamond.Args({owner: msg.sender, init: init, initCalldata: initCalldata})
        );
    }

    function testCallKnownMethodsSuccessfully() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        assertEq(IExampleV0(diamond).getX(), 123);
        assertEq(IExampleV0(diamond).getY(), 456);
        assertEq(IExampleV0(diamond).getText(), "hello");
        IExampleV0(diamond).setText("world");
        assertEq(IExampleV0(diamond).getText(), "world");
    }

    function testCannotCallUnknownMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        vm.expectRevert(
            abi.encodeWithSelector(FunctionNotFound.selector, IFake.fakeMethod.selector)
        );
        IFake(diamond).fakeMethod(123, false);
    }

    function testCannotCallDiamondCutIfNotOwner(address owner, address notOwner) public {
        vm.assume(owner != address(0));
        vm.assume(notOwner != address(0));
        vm.assume(owner != notOwner);

        vm.prank(owner);
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        vm.startPrank(notOwner);
        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector, notOwner, owner));
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotProviderZeroSelectorsToDiamondCut() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        address facetAddress = IDiamondLoupe(diamond).facetAddress(IExampleV0.getX.selector);

        bytes4[] memory selectors;
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(NoSelectorsProvidedForFacetForCut.selector, facetAddress)
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testRemoveSelectorEmitsDiamondCutEvent() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );
        vm.expectEmit();
        emit IDiamond.DiamondCut(cuts, address(0), "");
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotCallMethodAfterItIsRemoved() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        assertEq(IExampleV0(diamond).getX(), 123);

        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        vm.expectRevert(
            abi.encodeWithSelector(FunctionNotFound.selector, IExampleV0.getX.selector)
        );
        IExampleV0(diamond).getX();
    }

    function testFacetAddressMustBeZeroWhenRemovingSelector() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        address facetAddress = IDiamondLoupe(diamond).facetAddress(IExampleV0.getX.selector);

        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );
        vm.expectRevert(
            abi.encodeWithSelector(RemoveFacetAddressMustBeZeroAddress.selector, facetAddress)
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotRemoveUnregisteredMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );
        vm.expectRevert(
            abi.encodeWithSelector(CannotRemoveSelectorThatDoesNotExist.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotRemoveImmutableMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        // Register immutable method.
        bytes4[] memory selectors = h.makeArray(TestDiamond.immutableFn.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: diamond,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        assertEq(IExampleV0(diamond).immutableFn(), 135);

        cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: selectors
            })
        );
        vm.expectRevert(
            abi.encodeWithSelector(CannotRemoveImmutableFunction.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testAddSelectorEmitsDiamondCutEvent() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV1()),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        vm.expectEmit();
        emit IDiamond.DiamondCut(cuts, address(0), "");
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCallNewlyAddedMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        vm.expectRevert(
            abi.encodeWithSelector(FunctionNotFound.selector, IExampleV1.getZ.selector)
        );
        IExampleV1(diamond).getZ();

        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV1()),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        assertEq(IExampleV1(diamond).getZ(), 0);
    }

    function testCannotAddSelectorIfItIsAlreadyRegistered() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV0()),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(CannotAddSelectorThatAlreadyExists.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testFacetAddressCannotBeZeroWhenAddingSelector() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(CannotAddSelectorsFromZeroAddress.selector, selectors)
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testFacetAddressCannotBeAccountWhenAddingSelector() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address account = address(uint160(1234567890));
        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: account,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(abi.encodeWithSelector(NoBytecodeAtAddress.selector, account));
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testReplaceSelectorEmitsDiamondCutEvent() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV0.getY.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV1()),
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );
        vm.expectEmit();
        emit IDiamond.DiamondCut(cuts, address(0), "");
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCallReplacedMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        assertEq(IExampleV0(diamond).getY(), 456);

        bytes4[] memory selectors = h.makeArray(IExampleV0.getY.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV1()),
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        assertEq(IExampleV0(diamond).getY(), 228);
    }

    function testFacetAddressCannotBeZeroWhenReplacingSelector() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV0.getY.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(CannotReplaceSelectorsWithZeroAddress.selector, selectors)
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotReplaceMethodUsingSameFacet() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = IDiamondLoupe(diamond).facetAddress(IExampleV0.getX.selector);

        bytes4[] memory selectors = h.makeArray(IExampleV0.getX.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(CannotReplaceSelectorFromSameFacet.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotReplaceUnregisteredMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(new Example1FacetV1()),
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(CannotReplaceSelectorThatDoesNotExist.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testCannotReplaceImmutableMethod() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        // Register immutable method.
        bytes4[] memory selectors = h.makeArray(TestDiamond.immutableFn.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: diamond,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        assertEq(IExampleV0(diamond).immutableFn(), 135);

        cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: diamond,
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );
        vm.expectRevert(
            abi.encodeWithSelector(CannotReplaceImmutableFunction.selector, selectors[0])
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testFacetAddressCannotBeAccountWhenReplacingSelector() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address account = address(uint160(1234567890));
        bytes4[] memory selectors = h.makeArray(IExampleV0.getY.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: account,
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: selectors
            })
        );

        vm.expectRevert(abi.encodeWithSelector(NoBytecodeAtAddress.selector, account));
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    function testInitializeDuringDiamondCut() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = address(new Example1FacetV1());
        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        IDiamondCut(diamond).diamondCut(
            cuts,
            facetAddress,
            abi.encodeWithSignature("setZ(uint256)", 654)
        );

        assertEq(IExampleV1(diamond).getZ(), 654);
    }

    function testInitializeErrorDuringDiamondCutBubblesUp() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = address(new Example1FacetV1());
        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );
        vm.expectRevert("cannot set z to zero");
        IDiamondCut(diamond).diamondCut(
            cuts,
            facetAddress,
            abi.encodeWithSignature("setZ(uint256)", 0)
        );
    }

    function testInitializeFailureWithoutErrorMessageDuringDiamondCut() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = address(new Example1FacetV1());
        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        bytes memory initCalldata = abi.encodeWithSignature("setZ(uint256)", 1337);
        vm.expectRevert(
            abi.encodeWithSelector(
                InitializationFunctionReverted.selector,
                facetAddress,
                initCalldata
            )
        );
        IDiamondCut(diamond).diamondCut(cuts, facetAddress, initCalldata);
    }

    function testInitAddressCannotBeAccount() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = address(new Example1FacetV1());
        bytes4[] memory selectors = h.makeArray(IExampleV1.getZ.selector);
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        address account = address(uint160(1234567890));
        bytes memory initCalldata = abi.encodeWithSignature("setZ(uint256)", 1337);
        vm.expectRevert(abi.encodeWithSelector(NoBytecodeAtAddress.selector, account));
        IDiamondCut(diamond).diamondCut(cuts, account, initCalldata);
    }

    function testMultipleCutsAtATime() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");

        address facetAddress = address(new Example1FacetV1());
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: h.makeArray(IExampleV0.getX.selector)
            }),
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: h.makeArray(IExampleV0.getY.selector)
            }),
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: h.makeArray(IExampleV1.getZ.selector, IExampleV1.setZ.selector)
            })
        );

        bytes memory initCalldata = abi.encodeWithSignature("setZ(uint256)", 654);

        vm.expectEmit();
        emit IDiamond.DiamondCut(cuts, facetAddress, initCalldata);

        IDiamondCut(diamond).diamondCut(cuts, facetAddress, initCalldata);

        vm.expectRevert(
            abi.encodeWithSelector(FunctionNotFound.selector, IExampleV0.getX.selector)
        );
        IExampleV1(diamond).getX();

        assertEq(IExampleV1(diamond).getY(), 228);
        assertEq(IExampleV1(diamond).getZ(), 654);
        IExampleV1(diamond).setZ(531);
        assertEq(IExampleV1(diamond).getZ(), 531);
    }
}

contract DiamondLoupeTest is BaseTest {
    function testFacetsReturnsCorrectFacets() public {
        (address diamond, IDiamond.FacetCut[] memory cuts) = h.deployDiamond(123, 456, "hello");
        IDiamondLoupe.Facet[] memory expectedFacets = h.makeFacetsFromCuts(cuts);

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
        assertTrue(h.equal(facets, expectedFacets));
    }

    function testRemoveLastSelectorForFacetPreservesSelectorOrder() public {
        (address diamond, IDiamond.FacetCut[] memory oldCuts) = h.deployDiamond(123, 456, "hello");
        IDiamondLoupe.Facet[] memory oldExpectedFacets = h.makeFacetsFromCuts(oldCuts);

        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: h.makeArray(ExampleInit.initialize.selector)
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        IDiamondLoupe.Facet[] memory expectedFacets = new IDiamondLoupe.Facet[](5);
        expectedFacets[0] = oldExpectedFacets[0]; // DiamondCutFacet
        expectedFacets[1] = oldExpectedFacets[1]; // DiamondLoupeFacet
        expectedFacets[2] = oldExpectedFacets[2]; // OwnershipFacet
        expectedFacets[3] = oldExpectedFacets[3]; // Example1FacetV0
        expectedFacets[4] = oldExpectedFacets[4]; // Example2Facet

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
        assertEq(facets.length, expectedFacets.length);

        for (uint256 i; i < facets.length; ++i) {
            IDiamondLoupe.Facet memory facet = facets[i];
            IDiamondLoupe.Facet memory expectedFacet = expectedFacets[i];

            assertEq(facet.facetAddress, expectedFacet.facetAddress);
            assertEq(facet.functionSelectors.length, expectedFacet.functionSelectors.length);
            for (uint256 j; j < facet.functionSelectors.length; ++j) {
                assertEq(facet.functionSelectors[j], expectedFacet.functionSelectors[j]);
            }
        }
    }

    function testFacetsReturnsCorrectFacetsAfterDiamondCut() public {
        (address diamond, IDiamond.FacetCut[] memory oldCuts) = h.deployDiamond(123, 456, "hello");
        IDiamondLoupe.Facet[] memory oldExpectedFacets = h.makeFacetsFromCuts(oldCuts);

        address facetAddress = address(new Example1FacetV1());
        IDiamond.FacetCut[] memory cuts = h.makeArray(
            IDiamond.FacetCut({
                facetAddress: address(0),
                action: IDiamond.FacetCutAction.Remove,
                functionSelectors: h.makeArray(IExampleV0.getX.selector)
            }),
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Replace,
                functionSelectors: h.makeArray(IExampleV0.getY.selector)
            }),
            IDiamond.FacetCut({
                facetAddress: facetAddress,
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: h.makeArray(IExampleV1.getZ.selector, IExampleV1.setZ.selector)
            })
        );
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        IDiamondLoupe.Facet[] memory expectedFacets = new IDiamondLoupe.Facet[](6);
        expectedFacets[0] = oldExpectedFacets[0]; // DiamondCutFacet
        expectedFacets[1] = oldExpectedFacets[1]; // DiamondLoupeFacet
        expectedFacets[2] = oldExpectedFacets[2]; // OwnershipFacet
        expectedFacets[3] = oldExpectedFacets[5]; // ExampleInit
        expectedFacets[4] = IDiamondLoupe.Facet({
            facetAddress: facetAddress,
            functionSelectors: h.makeArray(
                IExampleV0.getY.selector,
                IExampleV1.getZ.selector,
                IExampleV1.setZ.selector
            )
        });
        expectedFacets[5] = oldExpectedFacets[4]; // Example2Facet

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
        assertEq(facets.length, expectedFacets.length);

        for (uint256 i; i < facets.length; ++i) {
            IDiamondLoupe.Facet memory facet = facets[i];
            IDiamondLoupe.Facet memory expectedFacet = expectedFacets[i];

            assertEq(facet.facetAddress, expectedFacet.facetAddress);
            assertEq(facet.functionSelectors.length, expectedFacet.functionSelectors.length);
            for (uint256 j; j < facet.functionSelectors.length; ++j) {
                assertEq(facet.functionSelectors[j], expectedFacet.functionSelectors[j]);
            }
        }
    }

    function testFacetFunctionSelectorsReturnCorrectSelectors() public {
        (address diamond, IDiamond.FacetCut[] memory cuts) = h.deployDiamond(123, 456, "hello");
        for (uint256 i; i < cuts.length; ++i) {
            assertTrue(
                h.equal(
                    IDiamondLoupe(diamond).facetFunctionSelectors(cuts[i].facetAddress),
                    cuts[i].functionSelectors
                )
            );
        }
    }

    function testFacetFunctionSelectorsReturnEmptyArrayForUnknownFacet() public {
        (address diamond, ) = h.deployDiamond(123, 456, "hello");
        bytes4[] memory selectors = IDiamondLoupe(diamond).facetFunctionSelectors(diamond);
        assertEq(selectors.length, 0);
    }

    function testFacetAddressesReturnsCorrectAddresses() public {
        (address diamond, IDiamond.FacetCut[] memory cuts) = h.deployDiamond(123, 456, "hello");
        address[] memory addresses = IDiamondLoupe(diamond).facetAddresses();
        assertEq(addresses.length, cuts.length);
        for (uint256 i; i < addresses.length; ++i) {
            assertEq(addresses[i], cuts[i].facetAddress);
        }
    }
}
