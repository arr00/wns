import { expect } from "chai";
import {
  reset,
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { setupGovernor } from "./governanceHelpers";

describe("ENS Fork Test", function () {
  async function deployFixtures() {
    try {
      await reset(process.env.SEPOLIA_URL);
    } catch (e) {
      throw new Error("Fork network unreachable");
    }

    const [owner, otherAccount, otherAccount2] = await ethers.getSigners();
    const { governor, governanceToken } = await setupGovernor(
      true,
      ethers.ZeroAddress
    );

    return { owner, otherAccount, otherAccount2, governor, governanceToken };
  }

  it("Delegate to tester", async function () {
    const { governanceToken } = await loadFixture(deployFixtures);
    const testerSigner = await ethers.getSigner(
      "0x337Ac11F9031835CA88b3814D638d3B8b0dF680A"
    );

    const checkpointBlock1 = await ethers.provider.getBlockNumber();
    await mine();

    await governanceToken.delegate(ethers.namehash("biggerdog.eth"));

    await mine();
    const checkpointBlock2 = await ethers.provider.getBlockNumber();
    await mine(10);

    const initialVotes = (
      await governanceToken.getPriorVotesWithENS(
        testerSigner.address,
        checkpointBlock1
      )
    )[0];

    const finalVotes = (
      await governanceToken.getPriorVotesWithENS(
        testerSigner.address,
        checkpointBlock2
      )
    )[0];

    expect(finalVotes).to.be.gt(initialVotes);
  });
});
