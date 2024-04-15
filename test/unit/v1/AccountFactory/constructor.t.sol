// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Metadata } from "src/v1/Metadata.sol";

contract AccountFactory__Constructor is BaseTest {
    function test_RevertIfAccountImplementationIs0() external {
        // it revert if account implementation is 0

        // 1. we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(AccountFactory.InvalidAccountImplementation.selector));

        // 2. we try to deploy the account factory with an owner set to 0
        new AccountFactory(address(0), makeAddr("operator"));
    }

    function test_ExposeTheImplementationAddressAfterBeingDeployed() external {
        // it expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(makeAddr("account"), makeAddr("operator"));
        assertEq(factory.accountImplementation(), makeAddr("account"));
    }

    function test_ExposeTheExpectedVersion() external {
        // it expose the expected version

        AccountFactory factory = new AccountFactory(makeAddr("account"), makeAddr("operator"));
        assertEq(factory.version(), Metadata.VERSION);
    }

    function test_RevertIfOwnerIs0() external {
        // it revert if account implementation is 0

        // 1. we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(AccountFactory.InvalidSigner.selector));

        // 2. we try to deploy the account factory with an owner set to 0
        new AccountFactory(makeAddr("account"), address(0));
    }

    function test_StoreTheOwner() external {
        // it disable the initializer

        AccountFactory factory = new AccountFactory(makeAddr("account"), makeAddr("operator"));
        assertEq(factory.owner(), makeAddr("operator"));
    }
}
