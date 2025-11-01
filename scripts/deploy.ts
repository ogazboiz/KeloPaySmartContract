import { network } from "hardhat";

const { viem } = await network.connect();

const [deployer] = await viem.getWalletClients();
const publicClient = await viem.getPublicClient();

console.log("Deploying StablecoinPayment contract...");
console.log("Deployer address:", deployer.account.address);

const StablecoinPayment = await viem.deployContract("StablecoinPayment", {
  args: [deployer.account.address],
});

console.log("StablecoinPayment deployed to:", StablecoinPayment.address);
console.log("Deployment confirmed!");

