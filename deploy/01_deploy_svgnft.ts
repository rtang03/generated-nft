import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import fs from "fs";
import { ethers } from "hardhat";
import { networkConfig } from "../helper-hardhat-config";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  log("--------------");
  const SVGNFT = await deploy("SVGNFT", { from: deployer, log: true });
  log(`You have deployed an NFT contract to ${SVGNFT.address}`);
  const filepath = "./img/small_enough.svg";
  const svg = fs.readFileSync(filepath, { encoding: "utf8" });
  const svgNFTContract = await ethers.getContractFactory("SVGNFT");
  const accounts = await hre.ethers.getSigners();
  const signer = accounts[0];
  const svgNFT = new ethers.Contract(
    SVGNFT.address,
    svgNFTContract.interface,
    signer
  );
  const networkName = networkConfig[chainId].name;
  log(
    `Verify with : \n npx hardhat verify --network ${networkName} ${svgNFT.address}`
  );
  // todo: verify don't work. Fix later

  const transactionResponse = await svgNFT.create(svg);
  const receipt = await transactionResponse.wait(1);
  log(`You've made an NFT!`);
  log(`You can view the tokenURI here ${await svgNFT.tokenURI(0)}`);
};

export default func;
