import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
  ERC20,
  ERC20__factory,
  ERC721Token,
  ERC721Token__factory,
  Marketplace,
  Marketplace__factory,
} from "../typechain";

describe("Marketplace", function () {
  let erc721Token: ERC721Token;
  let erc20Token: ERC20;
  let marketplace: Marketplace;
  let owner: SignerWithAddress, acc1: SignerWithAddress;

  beforeEach(async () => {
    [owner, acc1] = await ethers.getSigners();
    const marketplaceFactory: Marketplace__factory =
      await ethers.getContractFactory("Marketplace");
    marketplace = await marketplaceFactory.deploy();
    await marketplace.deployed();

    const erc721Factory: ERC721Token__factory = await ethers.getContractFactory(
      "ERC721Token"
    );
    erc721Token = await erc721Factory.deploy("TOKEN", "T", marketplace.address);
    await erc721Token.deployed();

    const erc20Factory: ERC20__factory = await ethers.getContractFactory(
      "ERC20"
    );
    erc20Token = await erc20Factory.deploy("TOKEN_ERC20", "ERC20_T", 2);
    await erc721Token.deployed();

    // Set token address
    await marketplace.setTokensAddresses(
      erc721Token.address,
      erc20Token.address
    );
    expect(await marketplace.ERC721_TOKEN()).to.equal(erc721Token.address);
    expect(await marketplace.ERC20_TOKEN()).to.equal(erc20Token.address);
  });

  describe("Create, list and buy item", () => {
    const TOKEN_ID = 1;
    const ORDER_PRICE = 10;
    const IN_SELL_STATUS = 1;
    const OWNERED = 0;
    it("Should create item", async () => {
      marketplace.createItem("https://ipfs.io/ipfs/Qm.....", owner.address);
      expect(await erc721Token.balanceOf(owner.address)).to.equal(1);
      expect(await erc721Token.ownerOf(TOKEN_ID)).to.equal(owner.address);
    });

    it("Should list item", async () => {
      marketplace.createItem("https://ipfs.io/ipfs/Qm.....", owner.address);
      expect(await erc721Token.balanceOf(owner.address)).to.equal(1);
      expect(await erc721Token.ownerOf(TOKEN_ID)).to.equal(owner.address);
      // Owner need to approve the marketplace to transfer tokens from owner
      await erc721Token.approve(marketplace.address, TOKEN_ID);
      await marketplace.listItem(TOKEN_ID, ORDER_PRICE);
      marketplace
        .sellOrderList(TOKEN_ID)
        .then((order) => {
          expect(order.seller).to.equal(owner.address);
          expect(order.price).to.equal(ORDER_PRICE);
          expect(order.status).to.equal(IN_SELL_STATUS);
        })
        .catch(console.error);
    });

    it("Should buy item", async () => {
      marketplace.createItem("https://ipfs.io/ipfs/Qm.....", owner.address);
      expect(await erc721Token.balanceOf(owner.address)).to.equal(1);
      expect(await erc721Token.ownerOf(TOKEN_ID)).to.equal(owner.address);
      // Owner need to approve the marketplace to transfer ERC721 tokens from owner
      await erc721Token.approve(marketplace.address, TOKEN_ID);
      await marketplace.listItem(TOKEN_ID, ORDER_PRICE);
      await erc20Token.mint(acc1.address, 10000000000);
      // We need to approve marketplace to transfer ERC20 tokens
      await erc20Token.connect(acc1).approve(marketplace.address, 10000000000);
      await marketplace.connect(acc1).buyItem(TOKEN_ID);
      await expect(
        marketplace.connect(acc1).buyItem(TOKEN_ID)
      ).to.be.revertedWith("Cannot buy non sold token");

      marketplace
        .sellOrderList(TOKEN_ID)
        .then((order) => {
          expect(order.seller).to.equal(acc1.address);
          expect(order.price).to.equal(ORDER_PRICE);
          expect(order.status).to.equal(OWNERED);
        })
        .catch(console.error);
    });
  });
});
