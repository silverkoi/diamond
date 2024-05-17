import { ethers } from "hardhat"

import { FacetCut, FacetCutAction, getSelectors } from "../utils/diamond"

async function deployFacetAndGetCut(name: string, functionNames?: string[]): Promise<FacetCut> {
  const contract = await ethers.deployContract(name)
  const cut = {
    facetAddress: contract.target,
    action: FacetCutAction.Add,
    functionSelectors: getSelectors(contract, functionNames),
  }
  return cut
}

export async function deployFacets(): Promise<FacetCut[]> {
  return [
    await deployFacetAndGetCut("DiamondCutFacet"),
    await deployFacetAndGetCut("DiamondLoupeFacet"),
    await deployFacetAndGetCut("OwnableFacet"),
    await deployFacetAndGetCut("Example1FacetV0"),
    await deployFacetAndGetCut("Example2Facet"),
    await deployFacetAndGetCut("ExampleInit", ["initialize"]),
  ]
}

export async function deployDiamond() {
  const [owner, notOwner, user] = await ethers.getSigners()

  const cuts = await deployFacets()
  const initAddress = cuts.at(-1)!.facetAddress as string
  const initFacet = await ethers.getContractAt("ExampleInit", initAddress)

  // Deploy diamond.
  const args = {
    owner: owner.address,
    init: initFacet.target,
    initCalldata: initFacet.interface.encodeFunctionData("initialize", [123, 456, "hello"]),
  }
  const diamond = await ethers.deployContract("Diamond", [cuts, args])

  return { diamond, cuts, owner, notOwner, user }
}
