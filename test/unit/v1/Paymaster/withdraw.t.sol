// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract Paymaster__Withdraw is BaseTest {
    address payable private owner = payable(makeAddr("owner"));
    address payable private operator = payable(makeAddr("operator"));
    address private entrypoint;

    Paymaster private paymaster;

    function setUp() external {
        entrypoint = address(new MockedEntryPointTest());
        paymaster = new Paymaster(entrypoint, owner, operator);
    }

    function test_AllowTheOwnerToWithdrawForAnybodyIncludingHim(address payable receiver) external {
        // it allow the owner to withdraw for anybody including him

        assumePayable(receiver);

        // 1. check the current balance of the receiver
        uint256 beforeBalance = address(receiver).balance;

        // 2. deposit 1 ether to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 3. we impersonate the owner and withdraw 1 ether in favor of the receiver
        vm.prank(owner);
        paymaster.withdrawTo(receiver, 1 ether);

        // 4. make sure the receiver received the 1 ether
        assertEq(address(receiver).balance, beforeBalance + 1 ether);
    }

    function test_AllowTheOwnerToWithdrawForAContract() external {
        // it allow the owner to withdraw for anybody including him

        // 1. We deploy a contract that will receive the funds
        address payable receiverContract = payable(address(new ContractReceiver()));

        // 2. check the current balance of the receiver
        uint256 beforeBalance = receiverContract.balance;

        // 3. deposit 1 ether to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 4. we impersonate the owner and withdraw 1 ether in favor of the receiver
        vm.prank(owner);
        paymaster.withdrawTo(receiverContract, 1 ether);

        // 5. make sure the receiver received the 1 ether
        assertEq(receiverContract.balance, beforeBalance + 1 ether);
    }

    function test_AllowTheOwnerToWithdrawForItself() external {
        // it allow the owner to withdraw for itself

        // 1. check the current balance of the owner
        uint256 beforeBalance = address(owner).balance;

        // 2. deposit 1 ether to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 3. we impersonate the owner and withdraw 1 ether in favor of the receiver
        vm.prank(owner);
        paymaster.withdrawTo(owner, 1 ether);

        // 4. make sure the owner received the 1 ether
        assertEq(address(owner).balance, beforeBalance + 1 ether);
    }

    function test_AllowTheOperatorToWithdrawForTheOwner() external {
        // it allow the operator to withdraw for the owner

        // 1. check the current balance of the owner
        uint256 beforeBalance = address(owner).balance;

        // 2. deposit 1 ether to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 3. we impersonate the owner and withdraw 1 ether in favor of the receiver
        vm.prank(operator);
        paymaster.withdrawTo(1 ether);

        // 4. make sure the owner received the 1 ether
        assertEq(address(owner).balance, beforeBalance + 1 ether);
    }

    function test_RevertsIfNonOwnerTryToWithdraw(address caller) external {
        // it reverts if non owner try to withdraw for someone else than owner

        // 1. make sure the fuzzed address is different from the owner
        vm.assume(caller != owner);

        // 2. we deposit some funds to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 3. we expect the function to revert if withdrawTo is called by someone else than the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        paymaster.withdrawTo(payable(owner), 1 ether);
    }

    function test_RevertsIfOperatorTryToChooseTheReceiver(address payable receiver) external {
        // it reverts if operator try to choose the receiver

        vm.assume(receiver.code.length == 0);

        // 1. we deposit some funds to the entrypoint for the paymaster
        paymaster.deposit{ value: 1 ether }();

        // 2. we expect the function to revert if withdrawTo is called by someone else than the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, operator));
        vm.prank(operator);
        paymaster.withdrawTo(receiver, 1 ether);
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

contract ContractReceiver {
    // solhint-disable-next-line no-empty-blocks
    receive() external payable { }
}
