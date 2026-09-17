import { ethers } from "hardhat";

/**
 * PAIDBALL deploy sequence
 * -------------------------------------------------------------------------
 * The router and vault reference each other, so we resolve the vault's
 * nonce-derived address ahead of time, deploy the router against it, then
 * deploy the vault for real and confirm the addresses line up.
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`deployer: ${deployer.address}`);

  const nonce = await ethers.provider.getTransactionCount(deployer.address);
  const predictedVault = ethers.getCreateAddress({ from: deployer.address, nonce: nonce + 1 });

  const Router = await ethers.getContractFactory("PaidballFeeRouter");
  const router = await Router.deploy(predictedVault);
  await router.waitForDeployment();
  console.log(`PaidballFeeRouter → ${await router.getAddress()}`);

  const Vault = await ethers.getContractFactory("PaidballVault");
  const vault = await Vault.deploy(await router.getAddress());
  await vault.waitForDeployment();
  console.log(`PaidballVault     → ${await vault.getAddress()}`);

  if ((await vault.getAddress()).toLowerCase() !== predictedVault.toLowerCase()) {
    throw new Error("vault address prediction drifted — nonce assumption broke, redeploy");
  }

  console.log("\nregister a token with:");
  console.log(`  router.registerToken(<token>, <feeRecipient>)`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
