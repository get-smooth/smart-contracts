// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IERC721Receiver } from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/utils/introspection/IERC165.sol";

/// @title ERC721Support
/// @notice Indicate the contract supports ERC721 token transfer
/// @custom:experimental This contract is unaudited yet
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

/// @title ERC1155Support
/// @notice Indicate the contract supports ERC1155 token transfer
abstract contract ERC1155Support is IERC1155Receiver {
    /// @notice Indicate that the contract supports ERC1155 token transfer
    /// @param {operator} The address which called `safeTransferFrom` function
    /// @param {from} The address which are tokens transferred from
    /// @param {id} The token identifier
    /// @param {value} The amount of tokens transferred
    /// @param {data} Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    function onERC1155Received(
        address, // operator
        address, // from
        uint256, // id
        uint256, // value
        bytes calldata // data
    )
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    /// @notice Indicate that the contract supports ERC1155 token batch transfer
    /// @param {operator} The address which called `safeBatchTransferFrom` function
    /// @param {from} The address which are tokens transferred from
    /// @param {ids} An array of token identifiers
    /// @param {values} An array of the amount of tokens transferred
    /// @param {data} Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
    function onERC1155BatchReceived(
        address, // operator
        address, // from
        uint256[] calldata, // ids
        uint256[] calldata, // values
        bytes calldata // data
    )
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @title ERC165Support
/// @notice Implement the `supportsInterface` function according to ERC-165
contract ERC165Support is IERC165 {
    // ERC-165 identifier for the `ERC1155TokenReceiver` support
    bytes4 private constant ERC165_ERC1155_TOKENRECEIVER = 0x4e2312e0;
    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
    bytes4 private constant ERC165_STANDARD = 0x01ffc9a7;

    /// @notice Indicates that the contract supports the ERC-165 and ERC1155 standards
    /// @dev The ERC721 standard doesn't have a specific interface ID
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @return `true` if the contract implements `interfaceID`
    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == ERC165_STANDARD || interfaceID == ERC165_ERC1155_TOKENRECEIVER;
    }
}

/// @title SmartAccountTokensSupport
/// @dev Inherit the SmartAccount contract with this contract tokens transfer
// solhint-disable-next-line no-empty-blocks
contract SmartAccountTokensSupport is ERC721Support, ERC165Support, ERC1155Support { }
