// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";

contract AccountFactory__Initialize is BaseTest {
    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    AccountFactory internal accountImplementation;

    function setUp() external {
        accountImplementation = deployFactoryImplementation(makeAddr("accountImplementation"));
    }

    function test_RevertsIfCalledInTheImplementation() external {
        // it reverts if called in the implementation

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        accountImplementation.initialize(makeAddr("signer"));
    }

    function test_CanBeCalledUsingAProxyAndSetVersionTo1() external {
        // it can be called using a proxy and set version to 1

        // 1. deploy a proxy that targets the implementation and initializing it
        AccountFactory factory =
            deployFactoryInstance(address(accountImplementation), makeAddr("proxyOwner"), makeAddr("factorySigner"));

        // 2. make sure the version stored is 1
        bytes32 value = vm.load(address(factory), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(1)));
    }

    function test_StoreTheOwner() external {
        // it store the owner

        address owner = makeAddr("owner");

        // 1. deploy a proxy that targets the implementation and initializing it
        AccountFactory factory = deployFactoryInstance(address(accountImplementation), makeAddr("proxyOwner"), owner);

        assertEq(factory.owner(), owner);
    }

    function test_CanNotBeCalledTwice() external {
        // it can not be called twice

        // 1. deploy a proxy that targets the implementation and initializing it
        AccountFactory factory =
            deployFactoryInstance(address(accountImplementation), makeAddr("proxyOwner"), makeAddr("owner"));

        // 2. try to initialize it again -- it should revert
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(makeAddr("owner"));
    }
}
