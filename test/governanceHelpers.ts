import { time, mine } from "@nomicfoundation/hardhat-network-helpers";
import {
  BigNumberish,
  EventLog,
  AddressLike,
  Addressable,
  BytesLike,
  isAddressable,
} from "ethers";
import { ethers } from "hardhat";
import { GovernorDelegate } from "../typechain-types";

/**
 * Propose and fast forward to voting period of given governor
 * @returns Proposal id
 */
export async function propose(
  governor: GovernorDelegate,
  targets: AddressLike[] = [ethers.ZeroAddress],
  values: BigNumberish[] = [0],
  callDatas: string[] = ["0x"],
  description = "Test Proposal"
): Promise<bigint> {
  const tx = await governor.propose(
    targets,
    values,
    Array(values.length).fill(""),
    callDatas,
    description
  );

  await mine((await governor.votingDelay()) + 1n);

  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  return ((await tx.wait())!.logs[0] as EventLog).args[0];
}

export async function proposeAndPass(
  governor: GovernorDelegate,
  targets: AddressLike[] = [ethers.ZeroAddress],
  values: BigNumberish[] = [0],
  callDatas: string[] = ["0x"],
  description = "Test Proposal"
): Promise<bigint> {
  const proposalId = await propose(
    governor,
    targets,
    values,
    callDatas,
    description
  );
  await governor.castVote(proposalId, 1);

  await mine(await governor.votingPeriod());

  return proposalId;
}

/**
 *
 * @param governor The governor to use (must have a signer with sufficient delegations)
 * @param targets Targets for each proposal action
 * @param values Value for each proposal action
 * @param callDatas Calldata for each proposal action
 * @param description The proposal description
 * @returns Proposal id for the new proposal
 */
export async function proposeAndQueue(
  governor: GovernorDelegate,
  targets: AddressLike[] = [ethers.ZeroAddress],
  values: BigNumberish[] = [0],
  callDatas: string[] = ["0x"],
  description = "Test Proposal"
): Promise<bigint> {
  const proposalId = await proposeAndPass(
    governor,
    targets,
    values,
    callDatas,
    description
  );

  await governor.queue(proposalId);

  return proposalId;
}

/**
 * Propose, pass, queue, and execute a proposal
 * @param governor The governor to use (must have a signer with sufficient delegations)
 * @param targets Targets for each proposal action
 * @param values Value for each proposal action
 * @param callDatas Calldata for each proposal action
 * @param description The proposal description
 * @returns Proposal id for the new proposal
 */
export async function proposeAndExecute(
  governor: GovernorDelegate,
  targets: AddressLike[] = [ethers.ZeroAddress],
  values: BigNumberish[] = [0],
  callDatas: string[] = ["0x"],
  description = "Test Proposal"
): Promise<bigint> {
  const proposalId = await proposeAndQueue(
    governor,
    targets,
    values,
    callDatas,
    description
  );
  await time.increase(
    await ethers.provider.call({
      to: await governor.timelock(),
      data: ethers.id("delay()").substring(0, 10),
    })
  );
  await governor.execute(proposalId);
  return proposalId;
}

export async function setupGovernor(
  forked: boolean,
  ensWorldIdRegistry: AddressLike
) {
  const [owner] = await ethers.getSigners();

  const Timelock = await ethers.getContractFactory("Timelock");
  const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
  const GovernorDelegator = await ethers.getContractFactory(
    "GovernorDelegator"
  );
  const GovernorDelegate = await ethers.getContractFactory("GovernorDelegate");

  const timelock = await Timelock.deploy(owner, 172800);
  const governorDelegate = await GovernorDelegate.deploy();

  const governanceToken = await (async function () {
    if (forked) {
      return await GovernanceToken.deploy(
        "Governance Token",
        "GT",
        owner,
        "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
        "0x8FADE66B79cC9f707aB26799354482EB93a5B7dD"
      );
    } else {
      // Need to deploy mock contracts for testing
      const MockResolver = await ethers.getContractFactory("MockResolver");
      const MockENS = await ethers.getContractFactory("MockENS");

      const mockResolver = await MockResolver.deploy();
      const mockEns = await MockENS.deploy(mockResolver);

      return await GovernanceToken.deploy(
        "Governance Token",
        "GT",
        owner,
        mockEns,
        mockResolver
      );
    }
  })();
  await governanceToken.delegate(await addressToBytes(owner));

  let governor: GovernorDelegate = (await GovernorDelegator.deploy(
    "Governor",
    timelock,
    governanceToken,
    owner,
    governorDelegate,
    5760,
    100,
    1000n * 10n ** 18n,
    ensWorldIdRegistry
  )) as unknown as GovernorDelegate;
  governor = GovernorDelegate.attach(
    await governor.getAddress()
  ) as GovernorDelegate;

  const eta =
    BigInt(await time.latest()) + 100n + (await timelock.MINIMUM_DELAY());
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const txData = (await timelock.setPendingAdmin.populateTransaction(governor))
    .data!;
  await timelock.queueTransaction(timelock, 0, "", txData, eta);
  await time.increaseTo(eta);
  await timelock.executeTransaction(timelock, 0, "", txData, eta);
  await governor.acceptAdmin();

  return { governor, governanceToken, timelock };
}

export async function getTypedDomain(address: Addressable, chainId: bigint) {
  return {
    name: "Governor",
    chainId: chainId.toString(),
    verifyingContract: await address.getAddress(),
  };
}

export function getVoteTypes() {
  return {
    Ballot: [
      { name: "proposalId", type: "uint256" },
      { name: "support", type: "uint8" },
      { name: "useEns", type: "bool" },
    ],
  };
}
export function getVoteWithReasonTypes() {
  return {
    Ballot: [
      { name: "proposalId", type: "uint256" },
      { name: "support", type: "uint8" },
      { name: "useEns", type: "bool" },
      { name: "reason", type: "string" },
    ],
  };
}

export async function getTypedDomainGovernanceToken(
  address: Addressable,
  chainId: bigint
) {
  return {
    name: "Governance Token",
    chainId: chainId.toString(),
    verifyingContract: await address.getAddress(),
  };
}

export function getDelegationTypes() {
  return {
    Delegation: [
      { name: "delegatee", type: "bytes32" },
      { name: "nonce", type: "uint256" },
      { name: "expiry", type: "uint256" },
    ],
  };
}

export function getProposeTypes() {
  return {
    Proposal: [
      { name: "targets", type: "address[]" },
      { name: "values", type: "uint256[]" },
      { name: "signatures", type: "string[]" },
      { name: "calldatas", type: "bytes[]" },
      { name: "description", type: "string" },
      { name: "proposalId", type: "uint256" },
    ],
  };
}

export enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed,
}

export async function addressToBytes(
  address: Addressable | string
): Promise<BytesLike> {
  let val = address;
  if (isAddressable(val)) {
    val = await val.getAddress();
  }
  return ethers.AbiCoder.defaultAbiCoder().encode(["address"], [val]);
}
