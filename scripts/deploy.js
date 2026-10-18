const hre = require("hardhat");
async function main() {
  const Hub = await hre.ethers.getContractFactory("OmniSubscriptionHub");
  const hub = await Hub.deploy();
  await hub.deployed();
  console.log("Subscription Hub deployed to:", hub.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
