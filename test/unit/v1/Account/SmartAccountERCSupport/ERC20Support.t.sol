// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { MockERC20 } from "forge-std/StdUtils.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccountTokensSupport__ERC20 is BaseTest {
    address internal entrypoint;
    SmartAccount internal account;
    DumbERC20 internal erc20;

    address internal immutable initialOwner = makeAddr("initial_owner");

    function setUp() external {
        // 1. deploy a new instance of the account
        entrypoint = makeAddr("entrypoint");
        account = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 2. deploy an ERC20 token and mint some tokens to the initial owner
        erc20 = new DumbERC20();
        erc20.initialize("DumbERC20", "DE20", 18);
        erc20.mint(initialOwner, 1000);
    }

    function test_CanReceiveERC20Tokens() external {
        // it can receive ERC20 tokens

        // 1. transfer some tokens to the account
        vm.prank(initialOwner);
        erc20.transfer(address(account), 20);

        // 2. make sure the tokens are transferred
        assertEq(erc20.balanceOf(address(account)), 20);
    }

    function test_CanApproveERC20Tokens() external {
        // it can transferFrom ERC20 tokens

        // 1. transfer some tokens to the account
        vm.prank(initialOwner);
        erc20.transfer(address(account), 20);

        // 2. give approval for some tokens to another address
        address to = makeAddr("another_address");
        uint256 amount = 10;
        vm.prank(entrypoint);
        account.execute(address(erc20), 0, abi.encodeWithSelector(MockERC20.approve.selector, to, amount));

        // 3. make sure the tokens are approved
        assertEq(erc20.allowance(address(account), to), amount);
    }

    function test_CanTransferERC20Tokens() external {
        // it can transfer ERC20 tokens

        // 1. transfer some tokens to the account
        vm.prank(initialOwner);
        erc20.transfer(address(account), 20);

        // 2. transfer some tokens from the account to another address
        address to = makeAddr("another_address");
        vm.prank(entrypoint);
        account.execute(address(erc20), 0, abi.encodeWithSelector(MockERC20.transfer.selector, to, 10));

        // 3. make sure the tokens are transferred
        assertEq(erc20.balanceOf(address(account)), 10);
        assertEq(erc20.balanceOf(to), 10);
    }

    function test_CanTransferFromERC20Tokens() external {
        // it can transferFrom ERC20 tokens

        // 1. approval some tokens for the account
        vm.prank(initialOwner);
        erc20.approve(address(account), 20);
        uint256 initalOwnerBalance = erc20.balanceOf(initialOwner);

        // 2. transfer some tokens from the account to another address
        address to = makeAddr("another_address");
        uint256 amount = 10;
        vm.prank(entrypoint);
        account.execute(
            address(erc20), 0, abi.encodeWithSelector(MockERC20.transferFrom.selector, initialOwner, to, amount)
        );

        // 3. make sure the tokens are transferred
        assertEq(erc20.balanceOf(to), amount);
        assertEq(erc20.balanceOf(initialOwner), initalOwnerBalance - amount);
    }
}

contract DumbERC20 is MockERC20 {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
