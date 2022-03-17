import { ethers } from "hardhat";
import { Marketplace, Marketplace__factory } from "../typechain";

async function main() {
  const Marketplace: Marketplace__factory = await ethers.getContractFactory(
    "Marketplace"
  );
  const marketplace: Marketplace = await Marketplace.deploy();

  await marketplace.deployed();

  console.log("Marketplace deployed to:", marketplace.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
