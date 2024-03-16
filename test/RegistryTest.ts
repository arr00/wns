import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Registry Test", function () {
  async function deployFixtures() {
    const [owner, otherAccount, otherAccount2] = await ethers.getSigners();

    const MockWorldIdFactory = await ethers.getContractFactory("MockWorldID");
    const mockWorldId = await MockWorldIdFactory.deploy();

    const MockResolver = await ethers.getContractFactory("MockResolver");
    const MockENS = await ethers.getContractFactory("MockENS");

    const resolver = await MockResolver.deploy();
    const ens = await MockENS.deploy(resolver);

    const RegistryFactory = await ethers.getContractFactory("Registry");
    const registry = await RegistryFactory.deploy(
      mockWorldId,
      "App Id",
      "Action Id",
      ens,
      resolver
    );

    return { owner, otherAccount, otherAccount2, registry, ens, resolver };
  }

  it("Test validate ens node", async function () {
    const { owner, registry, ens, resolver } = await loadFixture(
      deployFixtures
    );
    await ens.setResolver(ethers.namehash("cool.eth"), resolver);
    await resolver.setAddr(ethers.namehash("cool.eth"), owner.address);

    await registry.registerEns(
      ethers.namehash("cool.eth"),
      0,
      0,
      [0, 0, 0, 0, 0, 0, 0, 0]
    );

    expect(await registry.validatedEnsNodes(ethers.namehash("cool.eth"))).to.be
      .true;
  });
});
