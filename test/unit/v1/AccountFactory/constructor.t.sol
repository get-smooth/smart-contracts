// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SmartAccount } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Metadata } from "src/v1/Metadata.sol";

contract AccountFactory__Constructor is BaseTest {
    address private account;

    function setUp() external {
        account = address(new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier")));
    }

    function test_RevertIfOwnerIs0() external {
        // 1. we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

        // 2. we try to deploy the account factory with an owner set to 0
        new AccountFactory(address(0), account);
    }

    function test_ExposeTheImplementationAddressAfterBeingDeployed() external {
        // it should expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(makeAddr("owner"), account);
        assertEq(factory.accountImplementation(), account);
    }

    function test_ExposeTheOwnerAfterBeingDeployed() external {
        // it should expose the admin after being deployed

        AccountFactory factory = new AccountFactory(makeAddr("owner"), account);
        assertEq(factory.owner(), makeAddr("owner"));
    }

    function test_ExposeTheExpectedVersion() external {
        // it should expose the admin after being deployed

        AccountFactory factory = new AccountFactory(makeAddr("owner"), account);
        assertEq(factory.VERSION(), Metadata.VERSION);
    }
}
