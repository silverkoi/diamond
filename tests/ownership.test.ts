import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ethers } from "hardhat"

import { deployDiamond } from "./fixtures"

describe("Ownership", function () {
  it("owner returns correct address", async function () {
    const { diamond, owner } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IERC173", diamond)
    expect(await c.owner()).to.equal(owner)
  })

  it("cannot transfer ownership if not owner", async function () {
    const { diamond, owner, notOwner, user } = await loadFixture(deployDiamond)
    const c = await ethers.getContractAt("IERC173", diamond)
    await expect(c.connect(notOwner).transferOwnership(user))
      .to.be.revertedWithCustomError(
        await ethers.getContractAt("OwnershipFacet", "0x0"),
        "NotContractOwner",
      )
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
