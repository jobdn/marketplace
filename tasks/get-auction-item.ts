import { config } from "../config";
import { task } from "hardhat/config";
import { Marketplace } from "../typechain";

task("getAuctionById", "Get info about auction")
  .addParam("id", "Token id")
  .setAction(async (taskArgs, hre) => {
    const { id } = taskArgs;
    const marketplace: Marketplace = await hre.ethers.getContractAt(
      "Marketplace",
      config.MARKETPLACE_ADDRESS
    );

    const auction = await marketplace.orders(+id);
    console.log("Auciton: ", auction);
  });
