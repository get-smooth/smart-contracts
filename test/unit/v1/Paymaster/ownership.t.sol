// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract Paymaster__Ownership is BaseTest {
    address private immutable owner = makeAddr("owner");
    address private immutable operator = makeAddr("operator");
    address private immutable notOwner = makeAddr("notOwner");
    address private immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;

    function setUp() external {
        paymaster = new Paymaster(entrypoint, owner, operator);
    }

    function test_ReturnTheOwner() external view {
        // it return the owner

        assertEq(paymaster.owner(), owner);
    }

    function test_AllowOwnerToTransferOwnership() external {
        // it allow owner to transfer ownership

        // we impersonate the owner and transfer the ownership to the notOwner
        vm.prank(owner);
        paymaster.transferOwnership(notOwner);

        // make sure the owner has been updated
        assertEq(paymaster.owner(), notOwner);
    }

    function test_RevertIfNotOwnerTryToTransferOwnership() external {
        // it revert if not owner try to transfer ownership

        // we impersonate the notOwner and try to transfer the ownership to the owner -- expect revert
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(notOwner)));
        paymaster.transferOwnership(notOwner);

        // make sure the owner has not been updated
        assertEq(paymaster.owner(), owner);
    }

    function test_AllowOwnerToRenounceOwnership() external {
        // it allow owner to renounce ownership

        // we impersonate the owner and renounce the ownership
        vm.prank(owner);
        paymaster.renounceOwnership();

        // make sure the owner has been updated to address(0)
        assertEq(paymaster.owner(), address(0));
    }

    function test_RevertIfNotOwnerTryToRenounceOwnership() external {
        // it revert if not owner try to renounce ownership

        // we impersonate the notOwner and try to transfer the ownership to the owner -- expect revert
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        paymaster.renounceOwnership();

        // make sure the owner has not been updated
        assertEq(paymaster.owner(), owner);
    }
}
