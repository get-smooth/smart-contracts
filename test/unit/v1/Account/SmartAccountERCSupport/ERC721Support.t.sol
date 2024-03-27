// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { MockERC721 } from "forge-std/StdUtils.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { ERC721Support } from "src/v1/Account/SmartAccountTokensSupport.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccountTokensSupport__ERC721 is BaseTest {
    address internal entrypoint;
    SmartAccount internal account;
    DumbERC721 internal erc721;

    uint256 internal tokenId = 2;

    function setUp() external {
        // 1. deploy a new instance of the account
        entrypoint = makeAddr("entrypoint");
        account = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 2. deploy an ERC721 token
        erc721 = new DumbERC721();
        erc721.initialize("DumbERC721", "DE721");
    }

    function test_CanMintERC721Tokens() external {
        // it can transfer ERC721 tokens

        // 1. make sure the token is not minted
        vm.expectRevert("NOT_MINTED");
        assertEq(erc721.ownerOf(tokenId), address(0));
        assertEq(erc721.balanceOf(address(account)), 0);

        // 2. ask the account to mint the token -- only the entrypoint can interact with execute()
        vm.prank(entrypoint);
        account.execute(address(erc721), 0, abi.encodeWithSelector(DumbERC721.mint.selector, address(account), tokenId));

        // 3.  make sure the token is minted
        assertEq(erc721.ownerOf(tokenId), address(account));
        assertEq(erc721.balanceOf(address(account)), 1);
    }

    function test_CanSafeMintERC721Tokens() external {
        // it can safe mint ERC721 tokens

        // 1. make sure the token is not minted
        vm.expectRevert("NOT_MINTED");
        assertEq(erc721.ownerOf(tokenId), address(0));
        assertEq(erc721.balanceOf(address(account)), 0);

        // 2. ask the account to mint the token **without** data -- only the entrypoint can interact with execute()
        vm.prank(entrypoint);
        vm.expectCall(
            address(account),
            abi.encodeCall(ERC721Support.onERC721Received, (address(account), address(0), tokenId, hex""))
        );
        account.execute(
            address(erc721), 0, abi.encodeWithSelector(DumbERC721.safeMint.selector, address(account), tokenId)
        );

        // 3.  make sure the token is minted
        assertEq(erc721.ownerOf(tokenId), address(account));
        assertEq(erc721.balanceOf(address(account)), 1);
    }

    function test_CanSafeMintERC721TokensWithData() external {
        // it can safe mint ERC721 tokens

        bytes memory data = hex"f14e";

        // 1. make sure the token is not minted
        vm.expectRevert("NOT_MINTED");
        assertEq(erc721.ownerOf(tokenId), address(0));
        assertEq(erc721.balanceOf(address(account)), 0);

        // 2. ask the account to mint the token **with** data -- only the entrypoint can interact with execute()
        vm.prank(entrypoint);
        vm.expectCall(
            address(account),
            abi.encodeCall(ERC721Support.onERC721Received, (address(account), address(0), tokenId, data))
        );
        account.execute(
            address(erc721), 0, abi.encodeWithSelector(DumbERC721.safeMintData.selector, address(account), tokenId, data)
        );

        // 3.  make sure the token is minted
        assertEq(erc721.ownerOf(tokenId), address(account));
        assertEq(erc721.balanceOf(address(account)), 1);
    }

    function test_CanTransferERC721Tokens() external {
        // it can transfer ERC721 tokens

        // 1. ask the account to mint a token -- only the entrypoint can interact with execute()
        vm.prank(entrypoint);
        account.execute(
            address(erc721), 0, abi.encodeWithSelector(DumbERC721.safeMint.selector, address(account), tokenId)
        );

        // 2.  transfer the token
        address to = makeAddr("to");
        vm.prank(entrypoint);
        account.execute(
            address(erc721), 0, abi.encodeWithSelector(MockERC721.transferFrom.selector, address(account), to, tokenId)
        );

        // 3.  make sure the token is transferred
        assertEq(erc721.ownerOf(tokenId), address(to));
        assertEq(erc721.balanceOf(address(to)), 1);
        assertEq(erc721.balanceOf(address(account)), 0);
    }

    function test_CanApproveERC721Token() external {
        // it can approve ERC721 token

        // 1. ask the account to mint a token -- only the entrypoint can interact with execute()
        vm.prank(entrypoint);
        account.execute(
            address(erc721), 0, abi.encodeWithSelector(DumbERC721.safeMint.selector, address(account), tokenId)
        );

        // 2. give approval on the token to another address
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(address(erc721), 0, abi.encodeWithSelector(MockERC721.approve.selector, to, tokenId));

        // 3. make sure the token is approved
        assertEq(erc721.getApproved(tokenId), to);
    }

    function test_CanApproveAllERC721Tokens() external {
        // it can approve all ERC721 tokens

        // 1. ask the account to mint multiple tokens -- only the entrypoint can interact with execute()
        for (uint256 i = 1; i < 4;) {
            vm.prank(entrypoint);
            account.execute(
                address(erc721), 0, abi.encodeWithSelector(DumbERC721.safeMint.selector, address(account), i)
            );

            unchecked {
                ++i;
            }
        }

        // 2. give approval on all the tokens to another address
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(address(erc721), 0, abi.encodeWithSelector(MockERC721.setApprovalForAll.selector, to, true));

        // 3. make sure `to` is the operator of the account for all the tokens
        assertTrue(erc721.isApprovedForAll(address(account), to));
    }

    function test_CanReceiveERC721Tokens() external {
        // it can receive ERC721 tokens

        address eoa = makeAddr("eoa");

        // 1. mint an ERC721 token with an EOA
        erc721.mint(eoa, tokenId);

        // 2.  ask the EAO to transfer his token to the account using `safeTransferFrom`
        vm.prank(eoa);
        vm.expectCall(
            address(account),
            abi.encodeCall(ERC721Support.onERC721Received, (address(eoa), address(eoa), tokenId, hex""))
        );
        erc721.safeTransferFrom(eoa, address(account), tokenId, hex"");

        // 3.  make sure the token is transferred
        assertEq(erc721.ownerOf(tokenId), address(account));
    }
}

contract DumbERC721 is MockERC721 {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function safeMintData(address to, uint256 tokenId, bytes memory data) external {
        _safeMint(to, tokenId, data);
    }
}
