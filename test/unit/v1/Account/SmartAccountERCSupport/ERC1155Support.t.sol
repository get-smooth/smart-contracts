// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccountTokensSupport__ERC1155 is BaseTest {
    address internal entrypoint;
    SmartAccount internal account;
    DumbERC1155 internal erc1155;

    address internal immutable initialOwner = makeAddr("initial_owner");

    function setUp() external {
        // 1. deploy a new instance of the account
        entrypoint = makeAddr("entrypoint");
        account = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 2. deploy an ER1155 token and mint some tokens to the initial owner
        erc1155 = new DumbERC1155();
        erc1155.mint(initialOwner, 1, 200, hex"");
        erc1155.mint(initialOwner, 2, 100, hex"2233");
    }

    function test_CanReceiveERC1155Tokens() external {
        // it can receive ERC1155 tokens

        // 1. transfer tokens from the first collection to the account
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 1, 10, hex"");

        // 2. transfer tokens from the second collection to the account
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 2, 20, hex"");

        // 3. mint some tokens directly to the account
        vm.prank(initialOwner);
        erc1155.mint(address(account), 3, 30, hex"");

        // 4. make sure the tokens are transferred
        assertEq(erc1155.balanceOf(address(account), 1), 10);
        assertEq(erc1155.balanceOf(address(account), 2), 20);
        assertEq(erc1155.balanceOf(address(account), 3), 30);
    }

    function test_CanApproveAllERC1155Tokens() external {
        // it can approve all ERC1155 tokens

        // 1. transfer some tokens from the first collection to the account
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 1, 10, hex"");

        // 2. approve all the tokens from the first collection to another address
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(address(erc1155), 0, abi.encodeWithSelector(erc1155.setApprovalForAll.selector, to, true));

        // 3. make sure the tokens are approved
        assert(erc1155.isApprovedForAll(address(account), to));
    }

    function test_CanTransferfromERC20Tokens() external {
        // it can transferfrom ERC20 tokens

        uint256 amount = 10;

        // 1. transfer some tokens from the first collection to the account
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 1, amount, hex"");

        // 2. transfer the tokens from the first collection to another address
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(
            address(erc1155),
            0,
            abi.encodeWithSelector(erc1155.safeTransferFrom.selector, address(account), to, 1, amount, hex"ddee")
        );

        // 3. make sure the tokens are transferred
        assertEq(erc1155.balanceOf(address(account), 1), 0);
        assertEq(erc1155.balanceOf(to, 1), amount);
    }

    // @DEV: dynamic-length array must be in the storage to avoid a 0x41 EVM error when dealing with mock1155
    uint256[] internal ids = [uint256(1), uint256(2)];
    uint256[] internal values = [10, 20];

    function test_CanBatchTransferFromERC20Tokens() external {
        // it can batch transferFrom ERC20 tokens

        // 1. transfer some tokens from the first and second collection to the account
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 1, values[0], hex"");
        vm.prank(initialOwner);
        erc1155.safeTransferFrom(initialOwner, address(account), 2, values[1], hex"");

        // 2. batch transfer the tokens
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(
            address(erc1155),
            0,
            abi.encodeWithSelector(erc1155.safeBatchTransferFrom.selector, address(account), to, ids, values, hex"")
        );

        // 3. make sure the tokens are transferred
        assertEq(erc1155.balanceOf(address(account), ids[0]), 0);
        assertEq(erc1155.balanceOf(address(account), ids[1]), 0);
        assertEq(erc1155.balanceOf(to, ids[0]), values[0]);
        assertEq(erc1155.balanceOf(to, ids[1]), values[1]);
    }
}

contract DumbERC1155 is ERC1155 {
    constructor() ERC1155("https://token-cdn-domain/{id}.json") { }

    function mint(address to, uint256 id, uint256 value, bytes memory data) external {
        _mint(to, id, value, data);
    }
}
