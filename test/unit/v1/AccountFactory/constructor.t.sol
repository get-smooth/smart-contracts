// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Metadata } from "src/v1/Metadata.sol";

// @DEV: constant used by the `Initializable` library
bytes32 constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

contract AccountFactory__Constructor is BaseTest {
    function test_RevertIfAccountImplementationIs0() external {
        // it revert if account implementation is 0

        // 1. we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(AccountFactory.InvalidAccountImplementation.selector));

        // 2. we try to deploy the account factory with an owner set to 0
        new AccountFactory(address(0));
    }

    function test_ExposeTheImplementationAddressAfterBeingDeployed() external {
        // it expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(makeAddr("account"));
        assertEq(factory.accountImplementation(), makeAddr("account"));
    }

    function test_ExposeTheExpectedVersion() external {
        // it expose the expected version

        AccountFactory factory = new AccountFactory(makeAddr("account"));
        assertEq(factory.version(), Metadata.VERSION);
    }

    function test_DisableTheInitializer() external {
        // it disable the initializer

        // deploy the account
        AccountFactory factory = new AccountFactory(makeAddr("account"));

        // make sure the version is set to the max value possible
        bytes32 value = vm.load(address(factory), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(type(uint64).max)));

        // make sure the initializer is not callable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(makeAddr("new owner"));
    }
}
