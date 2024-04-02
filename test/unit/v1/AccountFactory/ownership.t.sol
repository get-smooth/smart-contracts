// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract AccountFactory__Ownership is BaseTest {
    address private immutable owner = makeAddr("owner");
    address private immutable notOwner = makeAddr("notOwner");

    AccountFactory private factory;

    function setUp() external {
        // 1. deploy the factory
        address factoryImplementation = address(deployFactoryImplementation(makeAddr("account")));
        factory = deployFactoryInstance(factoryImplementation, makeAddr("proxy_owner"), owner);
    }

    function test_ReturnTheOwner() external view {
        // it return the owner

        assertEq(factory.owner(), owner);
    }

    function test_AllowOwnerToTransferOwnership() external {
        // it allow owner to transfer ownership

        // we impersonate the owner and transfer the ownership to the notOwner
        vm.prank(owner);
        factory.transferOwnership(notOwner);

        // make sure the owner has been updated
        assertEq(factory.owner(), notOwner);
    }

    function test_RevertIfNotOwnerTryToTransferOwnership() external {
        // it revert if not owner try to transfer ownership

        // we impersonate the notOwner and try to transfer the ownership to the owner -- expect revert
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(notOwner)));
        factory.transferOwnership(notOwner);

        // make sure the owner has not been updated
        assertEq(factory.owner(), owner);
    }

    function test_AllowOwnerToRenounceOwnership() external {
        // it allow owner to renounce ownership

        // we impersonate the owner and renounce the ownership
        vm.prank(owner);
        factory.renounceOwnership();

        // make sure the owner has been updated to address(0)
        assertEq(factory.owner(), address(0));
    }

    function test_RevertIfNotOwnerTryToRenounceOwnership() external {
        // it revert if not owner try to renounce ownership

        // we impersonate the notOwner and try to transfer the ownership to the owner -- expect revert
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        factory.renounceOwnership();

        // make sure the owner has not been updated
        assertEq(factory.owner(), owner);
    }
}
