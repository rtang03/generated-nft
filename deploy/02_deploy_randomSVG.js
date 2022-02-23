const { networkConfig } = require("../helper-hardhat-config");

// hh deploy --tags rsvg
// hh deploy --network rinkeby --tags rsvg

module.exports = async (hre) => {
  const { deployments, getChainId, getNamedAccounts } = hre;
  const { deploy, get, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let linkTokenAddress;
  let vrfCoordinatorAddress;
  let additionalMessage;
  let tx;

  if (chainId === "31337") {
    const linkToken = await get("LinkToken");
    const VRFCoordinatorMock = await get("VRFCoordinatorMock");
    linkTokenAddress = linkToken.address;
    vrfCoordinatorAddress = VRFCoordinatorMock.address;
    additionalMessage = " --linkaddress " + linkTokenAddress;
  } else {
    linkTokenAddress = networkConfig[chainId].linkToken;
    vrfCoordinatorAddress = networkConfig[chainId].vrfCoordinator;
  }
  const keyHash = networkConfig[chainId].keyHash;
  const fee = networkConfig[chainId].fee;
  const args = [vrfCoordinatorAddress, linkTokenAddress, keyHash, fee];
  log("----------------------------------------------------");
  const RandomSVG = await deploy("RandomSVG", {
    from: deployer,
    args: args,
    log: true,
  });
  log("You have deployed your NFT contract!");
  const networkName = networkConfig[chainId].name;
  log(
    `Verify with \n npx hardhat verify --network ${networkName} ${
      RandomSVG.address
    } ${args.toString().replace(/,/g, " ")}`
  );
  // fund with Link
  const linkTokenContract = await hre.ethers.getContractFactory("LinkToken");
  const accounts = await hre.ethers.getSigners();
  const signer = accounts[0];
  const linkToken = new hre.ethers.Contract(
    linkTokenAddress,
    linkTokenContract.interface,
    signer
  );
  const fundTx = await linkToken.transfer(RandomSVG.address, fee);
  await fundTx.wait(1);

  // create an NFT, by calling random number
  const RandomSVGContract = await hre.ethers.getContractFactory("RandomSVG");
  const randomSVG = new hre.ethers.Contract(
    RandomSVG.address,
    RandomSVGContract.interface,
    signer
  );
  const creationTx = await randomSVG.create({
    gasLimit: 300000,
    value: "100000000000000000",
  });
  const receipt = await creationTx.wait(1);
  // NOTE: the event sequence of SVGNFT.sol matter
  const tokenId = receipt.events[3].topics[2];
  log(`You've made your NFT! This is number ${tokenId}`);
  log("Let's wait for the Chainlink VRF node to respond...");
  if (chainId !== "31337") {
    await new Promise((resolve) => setTimeout(resolve, 180000));
    log(`Now let's finsih the mint...`);
    tx = await randomSVG.finishMint(tokenId, { gasLimit: 2000000 });
    await tx.wait(1);
    log(`You can view the tokenURI here ${await randomSVG.tokenURI(0)}`);
  } else {
    const VRFCoordinatorMock = await deployments.get("VRFCoordinatorMock");
    const vrfCoordinator = await hre.ethers.getContractAt(
      "VRFCoordinatorMock",
      VRFCoordinatorMock.address,
      signer
    );
    const transactionResponse = await vrfCoordinator.callBackWithRandomness(
      receipt.logs[3].topics[1],
      77777,
      randomSVG.address
    );
    await transactionResponse.wait(1);
    log(`Now let's finsih the mint...`);
    tx = await randomSVG.finishMint(tokenId, { gasLimit: 2000000 });
    await tx.wait(1);
    log(`You can view the tokenURI here ${await randomSVG.tokenURI(0)}`);
  }
};

module.exports.tags = ["all", "rsvg"];
