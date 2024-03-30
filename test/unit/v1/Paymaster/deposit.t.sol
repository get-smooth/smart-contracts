// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

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
