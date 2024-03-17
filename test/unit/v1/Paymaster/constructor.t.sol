// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__Constructor is BaseTest {
    address private owner = makeAddr("owner");
    address private operator = makeAddr("operator");
    address private entrypoint = makeAddr("entrypoint");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function test_SetTheOwnerAndOperatorInTheStorage() external {
        // it set the owner address in the storage

        // record every state read/write
        vm.record();

        // deploy an instance of the paymaster
        Paymaster paymaster = new Paymaster(entrypoint, owner, operator);

        // stop recording state changes and get the state diff
        (, bytes32[] memory writes) = vm.accesses(address(paymaster));

        // make sure only one storage slot has been written
        assertEq(writes.length, 2);

        // make sure it is the slot 0
        assertEq(writes[0], bytes32(0));
        // make sure the slot 0 contains the owner address
        assertEq(uint256(vm.load(address(paymaster), bytes32(0))), uint256(uint160(owner)));
        // make sure it is the slot 1
        assertEq(writes[1], bytes32(uint256(1)));
        // make sure the slot 1 contains the owner address
        assertEq(uint256(vm.load(address(paymaster), bytes32(uint256(1)))), uint256(uint160(operator)));
    }

    function test_SetTheEntrypointAddressAsAnImmutableVariable() external {
        // it set the entrypoint address as an immutable variable

        Paymaster paymaster = new Paymaster(entrypoint, owner, operator);

        // record every state read/write
        vm.record();

        // fetch the owner of the paymaster
        address entryPointStored = address(paymaster.entryPoint());

        (bytes32[] memory reads,) = vm.accesses(address(paymaster));

        // check the entryPoint is correct and no storage has been accessed
        assertEq(entryPointStored, entrypoint);
        assertEq(reads.length, 0);
    }

    function test_RevertIfTheOwnerIsZero() external {
        // it reverts if the owner is zero

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

        // try to deploy an instance of the paymaster with the owner address set to zero
        new Paymaster(entrypoint, address(0), operator);
    }

    function test_RevertIfTheOperatorIsZero() external {
        // it does not revert if the operator is zero

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(Paymaster.InvalidOperator.selector));

        // try to deploy an instance of the paymaster with the owner address set to zero
        new Paymaster(entrypoint, owner, address(0));
    }

    function test_SetTheVersionAsConstant() external {
        // it set the version as constant

        Paymaster paymaster = new Paymaster(entrypoint, owner, operator);

        // record every state read/write
        vm.record();

        // fetch the owner of the paymaster
        string memory versionStored = paymaster.VERSION();

        (bytes32[] memory reads,) = vm.accesses(address(paymaster));

        // check the version is correct and no storage has been accessed
        assertEq(versionStored, "1.0.0");
        assertEq(reads.length, 0);
    }

    function test_EmitATransferEventWithTheOwnerAddress() external {
        // it emit a transfer event with the owner address

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true);

        // we tell the VM to expect this precise event
        emit OwnershipTransferred(address(0), owner);

        // deploy an instance of the paymaster to trigger the construction event
        new Paymaster(entrypoint, owner, operator);
    }
}
