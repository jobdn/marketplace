import { expect } from "chai";
import { ethers } from "hardhat";
import {
  ERC721Token,
  ERC721Token__factory,
  Marketplace,
  Marketplace__factory,
} from "../typechain";

describe("Marketplace", function () {
  let erc721Token: ERC721Token;
  let marketplace: Marketplace;
  beforeEach(async () => {
    const marketplaceFactory: Marketplace__factory =
      await ethers.getContractFactory("Marketplace");
    marketplace = await marketplaceFactory.deploy();
    await marketplace.deployed();

    const erc721Factory: ERC721Token__factory = await ethers.getContractFactory(
      "ERC721Token"
    );
    erc721Token = await erc721Factory.deploy("TOKEN", "T", marketplace.address);
    await erc721Token.deployed();
  });
});
