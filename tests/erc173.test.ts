import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ethers } from "hardhat"

import { deployDiamond } from "./fixtures"

describe("ERC173", function () {
  it("owner returns correct address", async function () {
    const { diamond, owner } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IERC173", diamond)
    expect(await c.owner()).to.equal(owner)
  })

  it("cannot transfer ownership if not owner", async function () {
    const { diamond, owner, notOwner, user } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IERC173", diamond)
    const errorContract = await ethers.getContractAt("ERC173Facet", "0x0")
    await expect(c.connect(notOwner).transferOwnership(user))
      .to.be.revertedWithCustomError(errorContract, "NotContractOwner")
      .withArgs(notOwner, owner)
  })

  it("transfer ownership", async function () {
    const { diamond, owner, user: newOwner } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IERC173", diamond)
    await expect(c.transferOwnership(newOwner))
      .to.emit(diamond, "OwnershipTransferred")
      .withArgs(owner, newOwner)

    expect(await c.owner()).to.equal(newOwner)
  })
})
