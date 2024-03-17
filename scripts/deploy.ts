import hre, { run, ethers } from "hardhat";

async function main() {
  await run("compile");

  // Sepolia constants
  const ENS = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
  const ENS_REVERSE_RESOLVER = "0x8FADE66B79cC9f707aB26799354482EB93a5B7dD";
  const World_ID_Router = "0x469449f251692E0779667583026b5A1E99512157";

  const accounts = await ethers.getSigners();
  const deployer = accounts[0];

  console.log("Deployer is " + deployer.address);

  let myNonce = await deployer.getNonce();

  const GovernorDelegate = (
    await ethers.getContractFactory("GovernorDelegate")
  ).connect(deployer);
  const governorDelegate = await GovernorDelegate.deploy({ nonce: myNonce++ });

  console.log({ governorDelegate });

  const GovernanceToken = (
    await ethers.getContractFactory("GovernanceToken")
  ).connect(deployer);
  const governanceToken = GovernanceToken.attach(
    "0xbb8f6b8df8cca184d54e58019cd8b71bdc26360e"
  );

  console.log({ governanceToken });

  const ENSWorldIdRegistry = (
    await ethers.getContractFactory("ENSWorldIdRegistry")
  ).connect(deployer);
  const ensWorldIdRegistry = await ENSWorldIdRegistry.deploy(
    World_ID_Router,
    "app_staging_1b0aee8169e8e96effda6718b3d14c65",
    "register-ens",
    ENS,
    ENS_REVERSE_RESOLVER,
    { nonce: myNonce++ }
  );

  console.log({ ensWorldIdRegistry });
  await sleep(2_000);

  const Timelock = (await ethers.getContractFactory("Timelock")).connect(
    deployer
  );
  const timelock = await Timelock.deploy(deployer.address, 60, {
    nonce: myNonce++,
  });

  console.log({ timelock });

  await sleep(2_000);

  const GovernorDelegator = (
    await ethers.getContractFactory("GovernorDelegator")
  ).connect(deployer);
  const governorDelegator = await GovernorDelegator.deploy(
    "My Governance",
    timelock,
    governanceToken,
    deployer.address,
    governorDelegate,
    100,
    1,
    100,
    ensWorldIdRegistry,
    { nonce: myNonce++ }
  );

  console.log({ governorDelegator });

  await sleep(2_000);

  await timelock.setAdmin(governorDelegator, { nonce: myNonce++ });

  console.log(
    "Deployment complete. Waiting for 20 seconds to verify contract on etherscan"
  );

  await sleep(20_000);

  await hre.run("verify:verify", {
    address: await governorDelegator.getAddress(),
    constructorArguments: [
      "My Governance",
      await timelock.getAddress(),
      governanceToken,
      deployer.address,
      governorDelegate,
      100,
      1,
      100,
      ensWorldIdRegistry,
    ],
  });

  await hre.run("verify:verify", {
    address: await governanceToken.getAddress(),
    constructorArguments: [
      "My Governance Token",
      "MGT",
      deployer.address,
      ENS,
      ENS_REVERSE_RESOLVER,
    ],
  });

  await hre.run("verify:verify", {
    address: await governorDelegate.getAddress(),
  });

  await hre.run("verify:verify", {
    address: await ensWorldIdRegistry.getAddress(),
    constructorArguments: [
      World_ID_Router,
      "app_staging_1b0aee8169e8e96effda6718b3d14c65",
      "register-ens",
      ENS,
      ENS_REVERSE_RESOLVER,
    ],
  });

  await hre.run("verify:verify", {
    address: await timelock.getAddress(),
    constructorArguments: [deployer.address, 60],
  });
}

function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

main();
