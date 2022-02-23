// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase, Ownable {
  uint256 public tokenCounter;
  bytes32 internal keyHash;
  uint256 internal fee;

  // svg params
  uint256 public maxNumberOfPaths;
  uint256 public maxNumberOfPathCommands;
  uint256 public size;
  string[] public pathCommands;
  string[] public colors;
  uint256 public price;

  mapping(bytes32 => address) public requestIdToSender;
  mapping(bytes32 => uint256) public requestIdToTokenId;
  mapping(uint256 => uint256) public tokenIdToRandomNumber;

  // the sequence of event definition matters
  event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);
  event CreatedUnfinishedRandomSVG(
    uint256 indexed tokenId,
    uint256 randomNumber
  );
  event RequestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId);

  constructor(
    address _vrfCoordinator,
    address _linkToken,
    bytes32 _keyHash,
    uint256 _fee
  ) VRFConsumerBase(_vrfCoordinator, _linkToken) ERC721("RandomSVG", "rtNFT") {
    keyHash = _keyHash;
    fee = _fee;
    tokenCounter = 0;
    maxNumberOfPaths = 10;
    maxNumberOfPathCommands = 5;
    size = 500;
    pathCommands = ["M", "L"];
    colors = ["red", "blue", "green", "yellow", "black", "white"];
    price = 100000000000000000; // 0.1 ETH / MATIC / AVAX
  }

  function create() public payable returns (bytes32 requestId) {
    require(msg.value >= price, "You need more ETH!");
    requestId = requestRandomness(keyHash, fee);
    requestIdToSender[requestId] = msg.sender;
    uint256 tokenId = tokenCounter;
    requestIdToTokenId[requestId] = tokenId;
    tokenCounter = tokenCounter + 1;
    emit RequestedRandomSVG(requestId, tokenId);
    // get a random number
    // gen the svg code
    // base64 encode the svg code
    // get tokenuri
    // mint the nft
  }

  function withdraw() public payable onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
    internal
    override
  {
    address nftOwner = requestIdToSender[requestId];
    uint256 tokenId = requestIdToTokenId[requestId];
    _safeMint(nftOwner, tokenId);
    tokenIdToRandomNumber[tokenId] = randomNumber;
    emit CreatedUnfinishedRandomSVG(tokenId, randomNumber);
  }

  function finishMint(uint256 _tokenId) public {
    require(
      bytes(tokenURI(_tokenId)).length <= 0,
      "tokenURI is already all set!"
    );
    require(tokenCounter > _tokenId, "TokenId has not been minted yet!");
    require(
      tokenIdToRandomNumber[_tokenId] > 0,
      "Need to wait for Chainlink VRF"
    );
    uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
    string memory svg = generateSVG(randomNumber);
    string memory imageURI = svgToImageURI(svg);
    string memory tokenURI = formatTokenURI(imageURI);
    _setTokenURI(_tokenId, tokenURI);
    emit CreatedRandomSVG(_tokenId, svg);
  }

  function generateSVG(uint256 _randomness)
    public
    view
    returns (string memory finalSvg)
  {
    // We will only use the path element, with stroke and d elements
    uint256 numberOfPaths = (_randomness % maxNumberOfPaths) + 1;
    finalSvg = string(
      abi.encodePacked(
        "<svg xmlns='http://www.w3.org/2000/svg' height='",
        uint2str(size),
        "' width='",
        uint2str(size),
        "'>"
      )
    );
    for (uint256 i = 0; i < numberOfPaths; i++) {
      // we get a new random number for each path
      string memory pathSvg = generatePath(
        uint256(keccak256(abi.encode(_randomness, i)))
      );
      finalSvg = string(abi.encodePacked(finalSvg, pathSvg));
    }
    finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
  }

  function generatePath(uint256 _randomness)
    public
    view
    returns (string memory pathSvg)
  {
    uint256 numberOfPathCommands = (_randomness % maxNumberOfPathCommands) + 1;
    pathSvg = "<path d='";
    for (uint256 i = 0; i < numberOfPathCommands; i++) {
      string memory pathCommand = generatePathCommand(
        uint256(keccak256(abi.encode(_randomness, size + i)))
      );
      pathSvg = string(abi.encodePacked(pathSvg, pathCommand));
    }
    string memory color = colors[_randomness % colors.length];
    pathSvg = string(
      abi.encodePacked(pathSvg, "' fill='transparent' stroke='", color, "'/>")
    );
  }

  function generatePathCommand(uint256 _randomness)
    public
    view
    returns (string memory pathCommand)
  {
    pathCommand = pathCommands[_randomness % pathCommands.length];
    uint256 parameterOne = uint256(
      keccak256(abi.encode(_randomness, size * 2))
    ) % size;
    uint256 parameterTwo = uint256(
      keccak256(abi.encode(_randomness, size * 2 + 1))
    ) % size;
    pathCommand = string(
      abi.encodePacked(
        pathCommand,
        " ",
        uint2str(parameterOne),
        " ",
        uint2str(parameterTwo)
      )
    );
  }

  // From: https://stackoverflow.com/a/65707309/11969592
  function uint2str(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
  {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  // You could also just upload the raw SVG and have solildity convert it!
  function svgToImageURI(string memory svg)
    public
    pure
    returns (string memory)
  {
    // example:
    // <svg width='500' height='500' viewBox='0 0 285 350' fill='none' xmlns='http://www.w3.org/2000/svg'><path fill='black' d='M150,0,L75,200,L225,200,Z'></path></svg>
    // data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nNTAwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI4NSAzNTAnIGZpbGw9J25vbmUnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PHBhdGggZmlsbD0nYmxhY2snIGQ9J00xNTAsMCxMNzUsMjAwLEwyMjUsMjAwLFonPjwvcGF0aD48L3N2Zz4=
    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(svg)))
    );
    return string(abi.encodePacked(baseURL, svgBase64Encoded));
  }

  function formatTokenURI(string memory imageURI)
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
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }
}