import { ethers } from "hardhat";
import { config } from "../config";
import { ERC721Token__factory } from "../typechain";

async function main() {
  const ERC721: ERC721Token__factory = await ethers.getContractFactory(
    "ERC721Token"
  );
  const erc721 = await ERC721.deploy(
    "ERC721_TOKEN",
    "ERC721T",
    config.MARKETPLACE_ADDRESS
  );

  await erc721.deployed();

  console.log("ERC721 deployed to:", erc721.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
