import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, network } from "hardhat";
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
  let owner: SignerWithAddress,
    acc1: SignerWithAddress,
    acc2: SignerWithAddress,
    acc3: SignerWithAddress;
  const FIRST_TOKEN_ID = 1;
  const FIRST_ORDER_PRICE = 10;
  const OWNERED_STATUS = 0;
  const MIN_PRICE_OF_FIRST_AUCTION = 100;

  beforeEach(async () => {
    [owner, acc1, acc2, acc3] = await ethers.getSigners();
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

  const createItem = async (ownerAddress: string, tokenId: number) => {
    await marketplace.createItem("https://ipfs.io/ipfs/Qm.....", ownerAddress);
    expect(await erc721Token.balanceOf(ownerAddress)).to.equal(1);
    expect(await erc721Token.ownerOf(tokenId)).to.equal(ownerAddress);
  };

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

      expect(await erc721Token.ownerOf(FIRST_TOKEN_ID)).to.equal(
        marketplace.address
      );
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
      ).to.be.revertedWith("Non sold item");

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

      expect(await erc721Token.ownerOf(FIRST_TOKEN_ID)).to.equal(owner.address);

      // If owner closed sell and then list token again
      await erc721Token.approve(marketplace.address, FIRST_TOKEN_ID);
      await marketplace.listItem(FIRST_TOKEN_ID, FIRST_ORDER_PRICE);
      await marketplace.cancel(FIRST_TOKEN_ID);
    });

    it("Should fail cancel sell if not owner try to cancel", async () => {
      await createItem(owner.address, 1);
      await expect(
        marketplace.connect(acc1).cancel(FIRST_TOKEN_ID)
      ).to.be.revertedWith("Not seller");
    });
  });

  const listItemOnAuction = async (
    ownerAddress: string,
    minPrice: number,
    tokenId: number
  ) => {
    await createItem(ownerAddress, tokenId);
    await erc721Token.approve(marketplace.address, tokenId);
    await marketplace.listItemOnAuction(tokenId, minPrice);
  };

  describe("List item to auction", () => {
    it("Should list item on auction", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
    });

    it("Should fail if call listItemOnAuction second time", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      await expect(
        marketplace.listItemOnAuction(
          FIRST_TOKEN_ID,
          MIN_PRICE_OF_FIRST_AUCTION
        )
      ).to.be.revertedWith("Auction is already started");
    });
  });

  describe("Make bid", () => {
    it("Should make bid", async () => {
      expect(await erc20Token.balanceOf(marketplace.address)).to.equal(0);
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);
      await marketplace
        .connect(acc1)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 1);

      // Check that erc20 tokens are sended to marketplace
      expect(await erc20Token.balanceOf(marketplace.address)).to.equal(
        MIN_PRICE_OF_FIRST_AUCTION + 1
      );

      await marketplace
        .connect(acc1)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 2);
      expect(await erc20Token.balanceOf(marketplace.address)).to.equal(
        MIN_PRICE_OF_FIRST_AUCTION + 2
      );

      marketplace
        .auctionOrderList(FIRST_TOKEN_ID)
        .then((auction) => {
          expect(auction.bidderCounter).to.equal(2);
          expect(auction.higherBidder).to.equal(acc1.address);
          expect(auction.higherBid).to.equal(MIN_PRICE_OF_FIRST_AUCTION + 2);
        })
        .catch(console.log);
    });

    it("Should fail if auction is not started", async () => {
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);
      await expect(
        marketplace
          .connect(acc1)
          .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 1)
      ).to.be.revertedWith("Auction is not started");
    });

    it("Should fail if auction is finished", async () => {
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);

      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      await network.provider.send("evm_increaseTime", [3 * 24 * 3600]);
      await network.provider.send("evm_mine");

      await expect(
        marketplace
          .connect(acc1)
          .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 1)
      ).to.be.revertedWith("Auction is over");
    });

    it("Should fail if sender make bid less then min price", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);

      await expect(
        marketplace
          .connect(acc1)
          .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION)
      ).to.be.revertedWith("Not enough bid");
    });
  });

  describe("Finish auction", () => {
    it("Should finish auction, send nft to winner and send erc20 to creator of auction", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.mint(acc2.address, 1000);
      await erc20Token.mint(acc3.address, 1000);

      await erc20Token.connect(acc1).approve(marketplace.address, 1000);
      await erc20Token.connect(acc2).approve(marketplace.address, 1000);
      await erc20Token.connect(acc3).approve(marketplace.address, 1000);

      await marketplace
        .connect(acc1)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 10);

      await marketplace
        .connect(acc2)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 20);

      await marketplace
        .connect(acc3)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 30);

      expect(await erc20Token.balanceOf(marketplace.address)).to.equal(
        MIN_PRICE_OF_FIRST_AUCTION + 30
      );

      await network.provider.send("evm_increaseTime", [3 * 24 * 3600 + 5]);
      await network.provider.send("evm_mine");

      await marketplace.finishAution(FIRST_TOKEN_ID);

      expect(await erc721Token.ownerOf(FIRST_TOKEN_ID)).to.equal(acc3.address);
      expect(await erc20Token.balanceOf(owner.address)).to.equal(
        MIN_PRICE_OF_FIRST_AUCTION + 30
      );
    });

    it("If amount of bid is not more than two", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      // Two bidders make bid
      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.mint(acc2.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);
      await erc20Token.connect(acc2).approve(marketplace.address, 1000);

      await marketplace
        .connect(acc1)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 10);

      await marketplace
        .connect(acc2)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 20);

      await network.provider.send("evm_increaseTime", [3 * 24 * 3600 + 5]);
      await network.provider.send("evm_mine");

      await marketplace.finishAution(FIRST_TOKEN_ID);
      expect(await erc721Token.balanceOf(owner.address)).to.equal(1);
      expect(await erc721Token.ownerOf(FIRST_TOKEN_ID)).to.equal(owner.address);
      expect(await erc20Token.balanceOf(acc2.address)).to.equal(1000);
    });

    it("Should fail if auction is not over", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      await expect(marketplace.finishAution(FIRST_TOKEN_ID)).to.be.revertedWith(
        "Auction is not over"
      );
    });
  });

  describe("Cancel auction", () => {
    it("Should cancel auciton", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      await erc20Token.mint(acc1.address, 1000);
      await erc20Token.mint(acc2.address, 1000);
      await erc20Token.connect(acc1).approve(marketplace.address, 1000);
      await erc20Token.connect(acc2).approve(marketplace.address, 1000);

      await marketplace
        .connect(acc1)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 10);

      await marketplace
        .connect(acc2)
        .makeBid(FIRST_TOKEN_ID, MIN_PRICE_OF_FIRST_AUCTION + 20);

      await marketplace.cancelAuction(FIRST_TOKEN_ID);
    });

    it("Should fail if auciton is already finished", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );

      await network.provider.send("evm_increaseTime", [3 * 24 * 3600 + 5]);
      await network.provider.send("evm_mine");

      await marketplace.finishAution(FIRST_TOKEN_ID);

      await expect(
        marketplace.cancelAuction(FIRST_TOKEN_ID)
      ).to.be.revertedWith("Auction is over");
    });

    it("Should cancel auciton if at least one bidder made bid", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
      await marketplace.cancelAuction(FIRST_TOKEN_ID);
    });

    it("Should fail if not creator try to cancel auciton", async () => {
      await listItemOnAuction(
        owner.address,
        MIN_PRICE_OF_FIRST_AUCTION,
        FIRST_TOKEN_ID
      );
      await expect(
        marketplace.connect(acc1).cancelAuction(FIRST_TOKEN_ID)
      ).to.be.revertedWith("Not auction owner");
    });
  });
});
