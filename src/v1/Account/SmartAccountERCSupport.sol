// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IERC721Receiver } from "@openzeppelin/token/ERC721/IERC721Receiver.sol";

/// @title ERC721Support
/// @notice Indicate the contract supports ERC721 token transfer
contract ERC721Support is IERC721Receiver {
    /// @notice Indicate that the contract supports ERC721 token transfer
    /// @param {operator} The address which called `safeTransferFrom` function
    /// @param {from} The address which are tokens transferred from
    /// @param {tokenId} The token identifier
    /// @param {data} Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    function onERC721Received(
        address, // operator
        address, // from
        uint256, // tokenId
        bytes calldata // data
    )
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}

/// @title SmartAccountERCSupport
/// @dev Inherit the SmartAccount contract with this contract tokens transfer
// solhint-disable-next-line no-empty-blocks
contract SmartAccountERCSupport is ERC721Support { }

