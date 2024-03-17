// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { Paymaster } from "src/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__Deposit is BaseTest {
    address private owner = makeAddr("owner");
    address private operator = makeAddr("operator");
    address private entrypoint;

    Paymaster private paymaster;

    function setUp() external {
        entrypoint = address(new MockedEntryPointTest());
        paymaster = new Paymaster(entrypoint, owner, operator);
    }

    function test_ReturnCurrentPaymasterDeposit() external {
        // it return current paymaster deposit
        uint256 beforeBalance = paymaster.getDeposit();

        // we deposit 1 ether to the entrypoint for the paymaster
        uint256 amount = 1 ether;
        paymaster.deposit{ value: amount }();

        uint256 afterBalance = paymaster.getDeposit();

        assertEq(beforeBalance, 0);
        assertEq(afterBalance, amount);
    }

    function test_AllowAnybodyToDeposit(address sender) external {
        // it deposit from anybody

        // give 2 ether to the sender
        deal(sender, 2 ether);

        // we impersonate the sender and deposit 1 ether in favor of the paymaster
        vm.prank(sender);
        uint256 amount = 1 ether;
        paymaster.deposit{ value: amount }();

        assertEq(paymaster.getDeposit(), amount);
    }

    function test_WithdrawToAnybodyIfCallerIsOwner() external {
        // it withdraw to anybody if caller is owner

        address payable receiver = payable(makeAddr("receiver"));
        uint256 beforeBalance = address(receiver).balance;

        paymaster.deposit{ value: 1 ether }();

        // we impersonate the owner and withdraw 1 ether in favor of the receiver
        vm.prank(owner);
        paymaster.withdrawTo(receiver, 1 ether);

        // make sure the receiver received the 1 ether
        assertEq(address(receiver).balance, beforeBalance + 1 ether);
    }

    function test_RevertsIfWithdrawerIsNotOwner() external {
        // it reverts if withdrawer is not owner

        paymaster.deposit{ value: 1 ether }();

        // we expect the function to revert if withdrawTo is called by someone else than the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        paymaster.withdrawTo(payable(owner), 1 ether);
    }
}

/// @title MockedEntryPointTest
/// @dev Minimalist implementation of the entrypoint that mocks the deposit and withdraw system
contract MockedEntryPointTest {
    mapping(address paymaster => uint256 balance) internal paymasterBalances;

    function depositTo(address paymaster) external payable {
        paymasterBalances[paymaster] += msg.value;
    }

    function balanceOf(address paymaster) external view returns (uint256) {
        return paymasterBalances[paymaster];
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) public {
        if (paymasterBalances[msg.sender] < amount) {
            revert("Not Mocked");
        }

        paymasterBalances[msg.sender] -= amount;
        (bool success,) = withdrawAddress.call{ value: amount }("");
        require(success, "Transfer failed");
    }
}
