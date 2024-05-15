import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { BaseContract, ZeroAddress } from "ethers"
import { ethers } from "hardhat"

import { FacetCutAction } from "../utils/diamond"
import { deployDiamond } from "./fixtures"

interface Facet {
  facetAddress: string
  functionSelectors: string[]
}

async function getSelector(contractName: string, functionName: string): Promise<string> {
  const c = await ethers.getContractAt(contractName, ZeroAddress)
  const frag = c.interface.getFunction(functionName)
  if (!frag) {
    throw new Error(`unknown function: ${contractName}.${functionName}`)
  }
  return frag.selector
}

async function getFacets(diamond: BaseContract): Promise<Facet[]> {
  const c = await ethers.getContractAt("IDiamondLoupe", diamond)
  const raw = await c.facets()
  return raw.map((r) => ({
    facetAddress: r.facetAddress,
    functionSelectors: r.functionSelectors,
  }))
}

describe("DiamondLoupe", function () {
  it("facets returns correct results", async function () {
    const { diamond, cuts } = await loadFixture(deployDiamond)
    const facets = await getFacets(diamond)

    const expectedFacets = cuts.map((c) => ({
      facetAddress: c.facetAddress,
      functionSelectors: c.functionSelectors,
    }))
    expect(facets).to.deep.equal(expectedFacets)
  })

  it("remove last selector preserves selector order", async function () {
    const { diamond, cuts } = await loadFixture(deployDiamond)

    const c = await ethers.getContractAt("IDiamondCut", diamond)
    const newFacet = await ethers.deployContract("Example1FacetV1")
    const addCuts = [
      {
        facetAddress: newFacet.target,
        action: FacetCutAction.Add,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    await (await c.diamondCut(addCuts, ZeroAddress, "0x")).wait()
    const removeCuts = [
      {
        facetAddress: ZeroAddress,
        action: FacetCutAction.Remove,
        functionSelectors: [newFacet.getZ.fragment.selector],
      },
    ]
    await (await c.diamondCut(removeCuts, ZeroAddress, "0x")).wait()

    const facets = await getFacets(diamond)

    const expectedFacets = cuts.map((c) => ({
      facetAddress: c.facetAddress,
      functionSelectors: c.functionSelectors,
    }))
    expect(facets).to.deep.equal(expectedFacets)
  })

  it("facet function selectors returns correct result", async function () {
    const { diamond, cuts } = await loadFixture(deployDiamond)

    const c = await ethers.getContractAt("IDiamondLoupe", diamond)
    for (const cut of cuts) {
      const selectors = await c.facetFunctionSelectors(cut.facetAddress)
      expect(selectors).to.deep.equal(cut.functionSelectors)
    }
  })

  it("facet addresses returns correct result", async function () {
    const { diamond, cuts } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IDiamondLoupe", diamond)
    expect(await c.facetAddresses()).to.deep.equal(cuts.map((c) => c.facetAddress))
  })
})
