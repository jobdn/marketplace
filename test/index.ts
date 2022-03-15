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
  const FIRST_TOKEN_ID = 1;
  const FIRST_ORDER_PRICE = 10;
  const OWNERED_STATUS = 0;
  const MIN_PRICE_OF_FIRST_TOKEN = 100;

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

  async function createItem(ownerAddress: string, tokenId: number) {
    await marketplace.createItem("https://ipfs.io/ipfs/Qm.....", ownerAddress);
    expect(await erc721Token.balanceOf(ownerAddress)).to.equal(1);
    expect(await erc721Token.ownerOf(tokenId)).to.equal(ownerAddress);
  }

  describe("Create, list and buy item", () => {
    const IN_SELL_STATUS = 1;

    it("Should create item", async () => {
      await createItem(owner.address, 1);
    });

    it("Should list item", async () => {
      await createItem(owner.address, 1);
      // Owner need to approve the marketplace to transfer tokens from owner
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItem(FIRST_TOKEN_ID, FIRST_ORDER_PRICE);
      marketplace
        .sellOrderList(FIRST_TOKEN_ID)
        .then((order) => {
          expect(order.seller).to.equal(owner.address);
          expect(order.price).to.equal(FIRST_ORDER_PRICE);
          expect(order.status).to.equal(IN_SELL_STATUS);
        })
        .catch(console.error);
    });

    it("Should buy item", async () => {
      await createItem(owner.address, 1);
      // Owner need to approve the marketplace to transfer ERC721 tokens from owner
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItem(FIRST_TOKEN_ID, FIRST_ORDER_PRICE);
      await erc20Token.mint(acc1.address, 10000000000);
      // We need to approve marketplace to transfer ERC20 tokens
      await erc20Token.connect(acc1).approve(marketplace.address, 10000000000);
      await marketplace.connect(acc1).buyItem(FIRST_TOKEN_ID);
      await expect(
        marketplace.connect(acc1).buyItem(FIRST_TOKEN_ID)
      ).to.be.revertedWith("Cannot buy non sold item");

      marketplace
        .sellOrderList(FIRST_TOKEN_ID)
        .then((order) => {
          expect(order.seller).to.equal(acc1.address);
          expect(order.price).to.equal(FIRST_ORDER_PRICE);
          expect(order.status).to.equal(OWNERED_STATUS);
        })
        .catch(console.error);
    });
  });

  // TODO: check whether change branch in coverage if delete this test
  describe("Set address for tokens", () => {
    it("Should fail if not admin try to set address of tokens", async () => {
      await expect(
        marketplace
          .connect(acc1)
          .setTokensAddresses(erc721Token.address, erc20Token.address)
      ).to.be.revertedWith("You cannot set address of tokens");
    });
  });

  describe("Cancel sell", () => {
    it("Should cancel sell", async () => {
      await createItem(owner.address, 1);
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItem(FIRST_TOKEN_ID, FIRST_ORDER_PRICE);
      await marketplace.cancel(FIRST_TOKEN_ID);

      marketplace
        .sellOrderList(FIRST_TOKEN_ID)
        .then((order) => {
          expect(order.seller).to.equal(owner.address);
          expect(order.price).to.equal(FIRST_ORDER_PRICE);
          expect(order.status).to.equal(OWNERED_STATUS);
        })
        .catch(console.error);
    });

    it("Should fail cancel sell if not owner try to cancel", async () => {
      await createItem(owner.address, 1);
      await expect(
        marketplace.connect(acc1).cancel(FIRST_TOKEN_ID)
      ).to.be.revertedWith("Not seller");
    });
  });

  describe("Auction", () => {
    it("Should list item on auction", async () => {
      await createItem(owner.address, FIRST_TOKEN_ID);
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItemOnAuction(
        FIRST_TOKEN_ID,
        MIN_PRICE_OF_FIRST_TOKEN
      );
    });

    it("Should fail if call listItemOnAuction second time", async () => {
      await createItem(owner.address, FIRST_TOKEN_ID);
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItemOnAuction(
        FIRST_TOKEN_ID,
        MIN_PRICE_OF_FIRST_TOKEN
      );

      await expect(
        marketplace.listItemOnAuction(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_TOKEN)
      ).to.be.revertedWith("Auction with this token is alredy started");
    });
  });
});
