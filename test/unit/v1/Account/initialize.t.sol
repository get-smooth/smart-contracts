// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccount__Initiliaze is BaseTest {
    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    SmartAccount private accountImplementation;
    SmartAccount private account;

    function setUp() external {
        // 1. deploy an implementation of the account
        accountImplementation = new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier"));

        // 2. deploy a proxy that targets the implementation without initializing it
        bytes memory data = hex"";
        account = SmartAccount(
            payable(new ERC1967Proxy{ salt: keccak256("this_is_a_salt") }(address(accountImplementation), data))
        );
    }

    function test_RevertsIfCalledDirectly() external {
        // it reverts if called directly

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        accountImplementation.initialize();
    }

    function test_CanBeCalledUsingAProxyAndSetVersionTo1() external {
        // it can be called using a proxy and set version to 1

        // 1. make sure no version is stored in the expected storage slot of the proxy
        bytes32 value = vm.load(address(account), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(0)));

        // 2. call the initialize function
        account.initialize();

        // 3. ensure the version 1 has been stored in the expected storage slot
        value = vm.load(address(account), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(1)));
    }

    function test_StoreTheInitiator() external {
        // it stores the deployer address

        // 1. check the factory is not set
        assertEq(account.getFactory(), address(0));

        // 2. call the initialize function
        account.initialize();

        // 3. check the factory is set to this contract
        assertEq(account.getFactory(), address(this));
    }

    function test_CanNotBeCalledTwice() external {
        // it can be called using a proxy and set version to 1

        // 1. call the initialize function
        account.initialize();

        // 2. call the initialize function a second time
        // check we can not call the initialize function again
        // (constant proxy version hardcoded in the account implementation)
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize();
    }
}
