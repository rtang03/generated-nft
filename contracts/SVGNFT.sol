// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// give the contract some svg code
// output nft uri with this svc code
// storing all nft metadata on chain

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SVGNFT is ERC721 {
  constructor() ERC721("MyNFT", "MNFT") {
    console.log("");
  }
}
