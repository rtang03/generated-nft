// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// give the contract some svg code
// output nft uri with this svc code
// storing all nft metadata on chain

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract SVGNFT is ERC721URIStorage {
  uint256 public tokenCounter;
  event CreatedSVGNFT(uint256 indexed tokenId, string tokenURI);

  constructor() ERC721("SVG NFT", "svgNFT") {
    tokenCounter = 0;
  }

  function create(string memory _svg) public {
    _safeMint(msg.sender, tokenCounter);
    string memory imageURI = svgToImageURI(_svg);
    string memory tokenURI = formatTokenURI(imageURI);
    _setTokenURI(tokenCounter, tokenURI);
    emit CreatedSVGNFT(tokenCounter, tokenURI);
    tokenCounter = tokenCounter + 1;
  }

  function svgToImageURI(string memory _svg)
    public
    pure
    returns (string memory)
  {
    // example:
    // data:image/svg+xml;base64,[base64 encoded svg]
    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(_svg)))
    );
    return string(abi.encodePacked(baseURL, svgBase64Encoded));
  }

  function formatTokenURI(string memory _imageURI)
    public
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                "SVG NFT", // You can add whatever name here
                '", "description":"An NFT based on SVG!", "attributes":"", "image":"',
                _imageURI,
                '"}'
              )
            )
          )
        )
      );
  }
}
