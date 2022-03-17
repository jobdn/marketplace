import { ethers } from "hardhat";
import { ERC20, ERC20__factory } from "../typechain";

async function main() {
  const ERC20: ERC20__factory = await ethers.getContractFactory("ERC20");
  const erc20: ERC20 = await ERC20.deploy("ERC20_TOKEN", "ERC20T", 2);

  await erc20.deployed();

  console.log("ERC20 deployed to:", erc20.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
