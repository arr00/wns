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
      await reset(process.env.RPC_URL);
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

  it("Delegate to Arr00.eth", async function () {
    const { governanceToken } = await loadFixture(deployFixtures);
    const arr00Signer = await ethers.getSigner(
      "0x2B384212EDc04Ae8bB41738D05BA20E33277bf33"
    );

    const checkpointBlock1 = await ethers.provider.getBlockNumber();
    await mine();

    await governanceToken.delegate(ethers.namehash("arr00.eth"));

    await mine();
    const checkpointBlock2 = await ethers.provider.getBlockNumber();
    await mine(10);

    const initialVotes = (
      await governanceToken.getPriorVotesWithENS(
        arr00Signer.address,
        checkpointBlock1
      )
    )[0];

    const finalVotes = (
      await governanceToken.getPriorVotesWithENS(
        arr00Signer.address,
        checkpointBlock2
      )
    )[0];

    expect(finalVotes).to.be.gt(initialVotes);
  });
});
