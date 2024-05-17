import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ZeroAddress } from "ethers"
import { ethers } from "hardhat"

import { FacetCutAction } from "../utils/diamond"
import { deployDiamond } from "./fixtures"

async function getSelector(contractName: string, functionName: string): Promise<string> {
  const c = await ethers.getContractAt(contractName, ZeroAddress)
  const frag = c.interface.getFunction(functionName)
  if (!frag) {
    throw new Error(`unknown function: ${contractName}.${functionName}`)
  }
  return frag.selector
}

describe("DiamondCut", function () {
  it("call known methods after deploy", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const c = await ethers.getContractAt("IExampleV0", diamond)
    expect(await c.getX()).to.equal(123)
    expect(await c.getY()).to.equal(456)
    expect(await c.getText()).to.equal("hello")
  })

  it("cannot call unknown method", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const c = await ethers.getContractAt("IExampleV1", diamond)
    await expect(c.getZ())
      .to.be.revertedWithCustomError(diamond, "FunctionNotFound")
      .withArgs(c.getZ.fragment.selector)
  })

  it("cannot cut if not owner", async function () {
    const { diamond, owner, notOwner } = await loadFixture(deployDiamond)

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("IExampleV0", "getX")],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    const errorContract = await ethers.getContractAt("DiamondCutFacet", ZeroAddress)
    await expect(c.connect(notOwner).diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(errorContract, "NotContractOwner")
      .withArgs(notOwner, owner)
  })

  it("cannot provide zero selectors for cut", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "NoSelectorsProvidedForFacetForCut")
      .withArgs(ZeroAddress)
  })

  it("remove selector emits DiamondCut event", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("IExampleV0", "getX")],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x")).to.emit(diamond, "DiamondCut")
  })

  it("cannot call method after it is removed", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("IExampleV0", "getX")],
      },
    ]
    {
      const c = await ethers.getContractAt("IDiamondCut", diamond)
      await (await c.diamondCut(cuts, ZeroAddress, "0x")).wait()
    }

    const c = await ethers.getContractAt("IExampleV0", diamond)
    await expect(c.getX())
      .to.be.revertedWithCustomError(diamond, "FunctionNotFound")
      .withArgs(c.getX.fragment.selector)
  })

  it("facet address must be zero when removing selector", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const facetAddress = (await ethers.getContractAt("IDiamondLoupe", diamond)).facetAddress(
      await getSelector("IExampleV0", "getX"),
    )

    const cuts = [
      {
        facetAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("IExampleV0", "getX")],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "RemoveFacetAddressMustBeZeroAddress")
      .withArgs(facetAddress)
  })

  it("cannot remove unknown method", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("IExampleV1", "getZ")],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotRemoveSelectorThatDoesNotExist")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("cannot remove immutable method", async function () {
    const { diamond } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondCut", diamond)

    const immutableFnCuts = [
      {
        facetAddress: diamond.target,
        action: FacetCutAction.Add,
        functionSelectors: [await getSelector("TestDiamond", "immutableFn")],
      },
    ]
    await (await c.diamondCut(immutableFnCuts, ZeroAddress, "0x")).wait()

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [await getSelector("TestDiamond", "immutableFn")],
      },
    ]
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotRemoveImmutableFunction")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("add selector emits DiamondCut event", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x")).to.emit(diamond, "DiamondCut")
  })

  it("can call newly added method", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    {
      const c = await ethers.getContractAt("IDiamondCut", diamond)
      await (await c.diamondCut(cuts, ZeroAddress, "0x")).wait()
    }

    const c = await ethers.getContractAt("IExampleV1", diamond)
    expect(await c.getZ()).to.equal(0)
  })

  it("cannot add selector that already exists", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getX.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotAddSelectorThatAlreadyExists")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("facet address cannot be zero when adding selector", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotAddSelectorsFromZeroAddress")
      .withArgs(cuts[0].functionSelectors)
  })

  it("facet address cannot be account when adding selector", async function () {
    const { diamond, user } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: user.address,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "NoBytecodeAtAddress")
      .withArgs(user.address)
  })

  it("replace selector emits DiamondCut event", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Replace,
        functionSelectors: [newFacet.getY.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x")).to.emit(diamond, "DiamondCut")
  })

  it("call replaced method", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Replace,
        functionSelectors: [newFacet.getY.fragment.selector],
      },
    ]
    {
      const c = await ethers.getContractAt("IDiamondCut", diamond)
      await (await c.diamondCut(cuts, ZeroAddress, "0x")).wait()
    }

    const c = await ethers.getContractAt("IExampleV1", diamond)
    expect(await c.getY()).to.equal(228)
  })

  it("cannot replace selector that does not exist", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Replace,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotReplaceSelectorThatDoesNotExist")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("facet address cannot be zero when replacing selector", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Replace,
        functionSelectors: [newFacet.getY.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotReplaceSelectorsWithZeroAddress")
      .withArgs(cuts[0].functionSelectors)
  })

  it("facet address must be different when replacing selector", async function () {
    const { diamond } = await loadFixture(deployDiamond)

    const facetAddress = (await ethers.getContractAt("IDiamondLoupe", diamond)).facetAddress(
      await getSelector("IExampleV0", "getX"),
    )

    const cuts = [
      {
        facetAddress,
        action: FacetCutAction.Replace,
        functionSelectors: [await getSelector("IExampleV0", "getX")],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotReplaceSelectorFromSameFacet")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("facet address cannot be account when replacing selector", async function () {
    const { diamond, user } = await loadFixture(deployDiamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")

    const cuts = [
      {
        facetAddress: user.address,
        action: FacetCutAction.Replace,
        functionSelectors: [newFacet.getY.fragment.selector],
      },
    ]
    const c = await ethers.getContractAt("IDiamondCut", diamond)
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "NoBytecodeAtAddress")
      .withArgs(user.address)
  })

  it("cannot replace immutable method", async function () {
    const { diamond } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondCut", diamond)

    const immutableFnCuts = [
      {
        facetAddress: diamond.target,
        action: FacetCutAction.Add,
        functionSelectors: [await getSelector("TestDiamond", "immutableFn")],
      },
    ]
    await (await c.diamondCut(immutableFnCuts, ZeroAddress, "0x")).wait()

    const newFacet = await ethers.deployContract("Example1FacetV1")
    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Replace,
        functionSelectors: [await getSelector("TestDiamond", "immutableFn")],
      },
    ]
    await expect(c.diamondCut(cuts, ZeroAddress, "0x"))
      .to.be.revertedWithCustomError(diamond, "CannotReplaceImmutableFunction")
      .withArgs(cuts[0].functionSelectors[0])
  })

  it("initialize error during cut bubbles up", async function () {
    const { diamond } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondCut", diamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")
    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [await getSelector("IExampleV1", "getZ")],
      },
    ]
    const initCalldata = newFacet.interface.encodeFunctionData("setZ", [0])
    await expect(c.diamondCut(cuts, newFacet.target, initCalldata)).to.be.revertedWith(
      "cannot set z to zero",
    )
  })

  it("initialize error without message during cut", async function () {
    const { diamond } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondCut", diamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")
    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [await getSelector("IExampleV1", "getZ")],
      },
    ]
    const initCalldata = newFacet.interface.encodeFunctionData("setZ", [1337])
    await expect(c.diamondCut(cuts, newFacet.target, initCalldata))
      .to.be.revertedWithCustomError(diamond, "InitializationFunctionReverted")
      .withArgs(newFacet.target, initCalldata)
  })

  it("init address cannot be account", async function () {
    const { diamond, user } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondCut", diamond)

    const newFacet = await ethers.deployContract("Example1FacetV1")
    const cuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [await getSelector("IExampleV1", "getZ")],
      },
    ]
    const initCalldata = newFacet.interface.encodeFunctionData("setZ", [1337])
    await expect(c.diamondCut(cuts, user, initCalldata))
      .to.be.revertedWithCustomError(diamond, "NoBytecodeAtAddress")
      .withArgs(user.address)
  })
})
