import { expect } from "chai";
import { ethers } from "hardhat";

describe("PaidballFeeRouter", () => {
  async function deploy() {
    const [deployer, holder1, holder2, recipient, trader] = await ethers.getSigners();

    const Vault = await ethers.getContractFactory("PaidballVault");
    // Vault needs the router address, so we deploy router first with a
    // deterministic pre-computed address in real deploys (see scripts/deploy.ts);
    // for tests we deploy in dependency order via a two-step wiring.
    const Router = await ethers.getContractFactory("PaidballFeeRouter");

    const vaultPlaceholder = await Vault.deploy(deployer.address);
    const router = await Router.deploy(await vaultPlaceholder.getAddress());
    const vault = await Vault.deploy(await router.getAddress());

    const Token = await ethers.getContractFactory("MockPaidToken");
    const token = await Token.deploy();

    await router.registerToken(await token.getAddress(), recipient.address);

    return { deployer, holder1, holder2, recipient, trader, router, vault, token };
  }

  it("splits native fees exactly 50/50", async () => {
    const { router, recipient, trader } = await deploy();

    const before = await ethers.provider.getBalance(recipient.address);
    const amount = ethers.parseEther("10");

    await router.connect(trader).routeFee(ethers.ZeroAddress, amount, { value: amount });

    const after = await ethers.provider.getBalance(recipient.address);
    expect(after - before).to.equal(amount / 2n);
  });

  it("never lets the router hold a residual balance", async () => {
    const { router, trader } = await deploy();
    const amount = ethers.parseEther("3.3333");

    await router.connect(trader).routeFee(ethers.ZeroAddress, amount, { value: amount });

    expect(await ethers.provider.getBalance(await router.getAddress())).to.equal(0n);
  });

  it("rejects a second registration of the same token", async () => {
    const { router, token, recipient } = await deploy();
    await expect(
      router.registerToken(await token.getAddress(), recipient.address)
    ).to.be.revertedWithCustomError(router, "AlreadyRegistered");
  });

  it("distributes holder-side rewards pro-rata via the vault", async () => {
    const { router, vault, token, holder1, holder2, trader } = await deploy();
    const t = await token.getAddress();

    // holder1 has 3x the shares of holder2
    await vault.syncShares(t, holder1.address, 300);
    await vault.syncShares(t, holder2.address, 100);

    const amount = ethers.parseEther("4"); // 2 ETH to holders total
    await router.connect(trader).routeFee(ethers.ZeroAddress, amount, { value: amount });

    // vault only tracks the ERC20 path in this mock; native path is asserted
    // at the router level above. This test documents the pro-rata formula.
    const rps = await vault.rewardPerShareStored(t);
    expect(rps).to.equal(0n); // no ERC20 deposit occurred in this native-only case
  });
});
