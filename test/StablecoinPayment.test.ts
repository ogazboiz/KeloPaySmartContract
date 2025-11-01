import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseUnits, zeroAddress } from "viem";

import { network } from "hardhat";

describe("StablecoinPayment", function () {
  it("Should deploy and set the right owner", async function () {
    const { viem } = await network.connect();
    const [owner] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const contractOwner = await paymentContract.read.owner();
    assert.equal(contractOwner, owner.account.address);
  });

  it("Should initialize with zero merchants", async function () {
    const { viem } = await network.connect();
    const [owner] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const totalMerchants = await paymentContract.read.totalMerchants();
    assert.equal(totalMerchants, 0n);
  });

  it("Should allow owner to add token", async function () {
    const { viem } = await network.connect();
    const [owner] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await viem.assertions.emitWithArgs(
      paymentContract.write.addAllowedToken([mockToken.address]),
      paymentContract,
      "TokenAdded",
      [mockToken.address],
    );

    const isAllowed = await paymentContract.read.isTokenAllowed([mockToken.address]);
    assert.equal(isAllowed, true);
  });

  it("Should allow owner to remove token", async function () {
    const { viem } = await network.connect();
    const [owner] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    
    await viem.assertions.emitWithArgs(
      paymentContract.write.removeAllowedToken([mockToken.address]),
      paymentContract,
      "TokenRemoved",
      [mockToken.address],
    );

    const isAllowed = await paymentContract.read.isTokenAllowed([mockToken.address]);
    assert.equal(isAllowed, false);
  });

  it("Should allow user to register as merchant", async function () {
    const { viem } = await network.connect();
    const [owner, merchant] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await viem.assertions.emitWithArgs(
      paymentContract.write.registerMerchant([merchant.account.address], {
        account: merchant.account,
      }),
      paymentContract,
      "MerchantRegistered",
      [merchant.account.address, merchant.account.address],
    );

    const merchantData = await paymentContract.read.getMerchant([merchant.account.address]);
    assert.equal(merchantData[0], merchant.account.address); // payoutWallet
    assert.equal(merchantData[1], true); // isActive
    assert.equal(merchantData[3], 0n); // totalRevenue

    const totalMerchants = await paymentContract.read.totalMerchants();
    assert.equal(totalMerchants, 1n);
  });

  it("Should not allow duplicate merchant registration", async function () {
    const { viem } = await network.connect();
    const [owner, merchant] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    await assert.rejects(
      paymentContract.write.registerMerchant([merchant.account.address], {
        account: merchant.account,
      }),
      /InvalidMerchant/
    );
  });

  it("Should process payment successfully", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, user] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    const amount = parseUnits("50", 6);
    await mockToken.write.mint([user.account.address, parseUnits("1000", 6)]);
    await mockToken.write.approve([paymentContract.address, parseUnits("200", 6)], {
      account: user.account,
    });

    await viem.assertions.emitWithArgs(
      paymentContract.write.processPayment(
        [merchant.account.address, mockToken.address, amount, "Invoice #12345"],
        { account: user.account }
      ),
      paymentContract,
      "PaymentProcessed",
      [user.account.address, merchant.account.address, mockToken.address, amount, "Invoice #12345"],
    );

    const balance = await paymentContract.read.getMerchantBalance([
      merchant.account.address,
      mockToken.address,
    ]);
    assert.equal(balance, amount);
  });

  it("Should not allow payment below minimum amount", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, user] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    await mockToken.write.mint([user.account.address, parseUnits("1000", 6)]);
    await mockToken.write.approve([paymentContract.address, parseUnits("200", 6)], {
      account: user.account,
    });

    const lowAmount = parseUnits("0.1", 6); // Below minimum

    await assert.rejects(
      paymentContract.write.processPayment(
        [merchant.account.address, mockToken.address, lowAmount, ""],
        { account: user.account }
      ),
      /InvalidAmount/
    );
  });

  it("Should allow merchant to withdraw funds", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, user] = await viem.getWalletClients();
    const publicClient = await viem.getPublicClient();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    const amount = parseUnits("75", 6);
    await mockToken.write.mint([user.account.address, parseUnits("1000", 6)]);
    await mockToken.write.approve([paymentContract.address, parseUnits("200", 6)], {
      account: user.account,
    });

    await paymentContract.write.processPayment(
      [merchant.account.address, mockToken.address, amount, ""],
      { account: user.account }
    );

    const initialBalance = await mockToken.read.balanceOf([merchant.account.address]);

    await viem.assertions.emitWithArgs(
      paymentContract.write.withdraw([mockToken.address, amount], {
        account: merchant.account,
      }),
      paymentContract,
      "Withdrawal",
      [merchant.account.address, mockToken.address, amount],
    );

    const finalBalance = await mockToken.read.balanceOf([merchant.account.address]);
    assert.equal(finalBalance - initialBalance, amount);

    const contractBalance = await paymentContract.read.getMerchantBalance([
      merchant.account.address,
      mockToken.address,
    ]);
    assert.equal(contractBalance, 0n);
  });

  it("Should allow pausing and unpausing", async function () {
    const { viem } = await network.connect();
    const [owner, merchant] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await paymentContract.write.pause();
    const isPaused = await paymentContract.read.paused();
    assert.equal(isPaused, true);

    await assert.rejects(
      paymentContract.write.registerMerchant([merchant.account.address], {
        account: merchant.account,
      }),
      /EnforcedPause/
    );

    await paymentContract.write.unpause();
    const isUnpaused = await paymentContract.read.paused();
    assert.equal(isUnpaused, false);
  });

  it("Should store transaction history", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, user] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    const amount = parseUnits("50", 6);
    const metadata = "Test invoice";
    
    await mockToken.write.mint([user.account.address, parseUnits("1000", 6)]);
    await mockToken.write.approve([paymentContract.address, parseUnits("200", 6)], {
      account: user.account,
    });

    await paymentContract.write.processPayment(
      [merchant.account.address, mockToken.address, amount, metadata],
      { account: user.account }
    );

    const userTxs = await paymentContract.read.getUserTransactions([user.account.address]);
    assert.equal(userTxs.length, 1);
    assert.equal(userTxs[0][2], mockToken.address); // token
    assert.equal(userTxs[0][3], amount); // amount
    assert.equal(userTxs[0][4], metadata); // metadata

    const merchantTxs = await paymentContract.read.getMerchantTransactions([merchant.account.address]);
    assert.equal(merchantTxs.length, 1);

    const totalTxs = await paymentContract.read.getTotalTransactions();
    assert.equal(totalTxs, 1n);
  });

  it("Should allow owner to activate and suspend merchant", async function () {
    const { viem } = await network.connect();
    const [owner, merchant] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    await viem.assertions.emitWithArgs(
      paymentContract.write.suspendMerchant([merchant.account.address]),
      paymentContract,
      "MerchantSuspended",
      [merchant.account.address],
    );

    const merchantData = await paymentContract.read.getMerchant([merchant.account.address]);
    assert.equal(merchantData[1], false); // isActive

    await viem.assertions.emitWithArgs(
      paymentContract.write.activateMerchant([merchant.account.address]),
      paymentContract,
      "MerchantActivated",
      [merchant.account.address],
    );

    const merchantDataActive = await paymentContract.read.getMerchant([merchant.account.address]);
    assert.equal(merchantDataActive[1], true); // isActive
  });

  it("Should not allow suspended merchant to receive payments", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, user] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    const mockToken = await viem.deployContract("MockERC20", {
      args: ["Test USDT", "TUSDT", 6],
    });

    await paymentContract.write.addAllowedToken([mockToken.address]);
    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });
    await paymentContract.write.suspendMerchant([merchant.account.address]);

    await mockToken.write.mint([user.account.address, parseUnits("1000", 6)]);
    await mockToken.write.approve([paymentContract.address, parseUnits("200", 6)], {
      account: user.account,
    });

    await assert.rejects(
      paymentContract.write.processPayment(
        [merchant.account.address, mockToken.address, parseUnits("50", 6), ""],
        { account: user.account }
      ),
      /MerchantNotActive/
    );
  });

  it("Should return all merchants", async function () {
    const { viem } = await network.connect();
    const [owner, merchant1, merchant2] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await paymentContract.write.registerMerchant([merchant1.account.address], {
      account: merchant1.account,
    });
    await paymentContract.write.registerMerchant([merchant2.account.address], {
      account: merchant2.account,
    });

    const allMerchants = await paymentContract.read.getAllMerchants();
    assert.equal(allMerchants.length, 2);
    assert.equal(allMerchants[0], merchant1.account.address);
    assert.equal(allMerchants[1], merchant2.account.address);

    const totalMerchants = await paymentContract.read.totalMerchants();
    assert.equal(totalMerchants, 2n);
  });

  it("Should allow merchant to update payout wallet", async function () {
    const { viem } = await network.connect();
    const [owner, merchant, newWallet] = await viem.getWalletClients();

    const paymentContract = await viem.deployContract("StablecoinPayment", {
      args: [owner.account.address],
    });

    await paymentContract.write.registerMerchant([merchant.account.address], {
      account: merchant.account,
    });

    await viem.assertions.emitWithArgs(
      paymentContract.write.updatePayoutWallet([newWallet.account.address], {
        account: merchant.account,
      }),
      paymentContract,
      "MerchantWalletUpdated",
      [merchant.account.address, merchant.account.address, newWallet.account.address],
    );

    const merchantData = await paymentContract.read.getMerchant([merchant.account.address]);
    assert.equal(merchantData[0], newWallet.account.address);
  });
});
