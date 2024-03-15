// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 public tokenId = 0;

    constructor() ERC721("TestERC721", "T721") { }

    function mint() external {
        unchecked {
            ++tokenId;
        }

        _mint(msg.sender, tokenId);
    }

    function safeMint() external {
        unchecked {
            ++tokenId;
        }

        _safeMint(msg.sender, tokenId);
    }
}
