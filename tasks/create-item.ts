import { config } from "../config";
import { task } from "hardhat/config";
import { Marketplace } from "../typechain";

task("createItem", "Create item in marketplace")
  .addParam("data", "Metadata for token")
  .addParam("owner", "Owner address")
  .setAction(async (taskArgs, hre) => {
    const { data, owner } = taskArgs;
    const marketplace: Marketplace = await hre.ethers.getContractAt(
      "Marketplace",
      config.MARKETPLACE_ADDRESS
    );

    await marketplace.createItem(data, owner);
  });
