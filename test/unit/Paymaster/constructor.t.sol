// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Ownable } from "@eth-infinitism/core/BasePaymaster.sol";
import { Paymaster } from "src/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__Constructor is BaseTest {
    address private admin = makeAddr("admin");
    address private entrypoint = makeAddr("entrypoint");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function test_SetTheAdminAddressInTheStorage() external {
        // it set the admin address in the storage

        // record every state read/write
        vm.record();

        // deploy an instance of the paymaster
        Paymaster paymaster = new Paymaster(entrypoint, admin);

        // stop recording state changes and get the state diff
        (, bytes32[] memory writes) = vm.accesses(address(paymaster));

        // make sure only one storage slot has been written
        assertEq(writes.length, 1);
        // make sure it is the slot 0
        assertEq(writes[0], bytes32(0));
        // make sure the slot 0 contains the admin address
        assertEq(uint256(vm.load(address(paymaster), bytes32(0))), uint256(uint160(admin)));
    }

    function test_SetTheEntrypointAddressAsAnImmutableVariable() external {
        // it set the entrypoint address as an immutable variable

        Paymaster paymaster = new Paymaster(entrypoint, admin);

        // record every state read/write
        vm.record();

        // fetch the owner of the paymaster
        address entryPointStored = address(paymaster.entryPoint());

        (bytes32[] memory reads,) = vm.accesses(address(paymaster));

        // check the entryPoint is correct and no storage has been accessed
        assertEq(entryPointStored, entrypoint);
        assertEq(reads.length, 0);
    }

    function test_SetTheAdminAddressAsAnImmutableVariable() external {
        // it set the admin address as an immutable variable

        Paymaster paymaster = new Paymaster(entrypoint, admin);

        // record every state read/write
        vm.record();

        // fetch the owner of the paymaster
        address owner = paymaster.owner();

        (bytes32[] memory reads,) = vm.accesses(address(paymaster));

        // check the owner is the admin and no storage has been accessed
        assertEq(owner, admin);
        assertEq(reads.length, 0);
    }

    function test_RevertsIfTheAdminIsZero() external {
        // it reverts if the admin is zero

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

        // try to deploy an instance of the paymaster with the admin address set to zero
        new Paymaster(entrypoint, address(0));
    }

    function test_EmitATransferEventWithTheAdminAddress() external {
        // it emit a transfer event with the admin address

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true);

        // we tell the VM to expect this precise event
        emit OwnershipTransferred(address(0), admin);

        // deploy an instance of the paymaster to trigger the construction event
        new Paymaster(entrypoint, admin);
    }
}
