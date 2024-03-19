// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest.sol";

contract SmartAccount__Initiliaze is BaseTest {
    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    SmartAccount private account;

    function setUp() external {
        // deploy the account
        account = new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier"));
    }

    function test_RevertsIfCalledDirectly() external {
        // it reverts if called directly

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize();
    }

    function test_CanBeCalledUsingAProxyAndSetVersionTo1() external {
        // it can be called using a proxy and set version to 1

        // make sure nothing is stored in the storage of this contract
        bytes32 value = vm.load(address(this), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(0)));

        // for the sake of the test, we will use this account as a proxy to call the initialize function
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(account).delegatecall(abi.encodeWithSignature("initialize()"));
        assertTrue(success);

        // check the version 1 as been stored in the expected storage slot
        value = vm.load(address(this), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(1)));
    }

    function test_CanNotBeCalledTwice() external {
        // it can be called using a proxy and set version to 1

        // for the sake of the test, we will use this account as a proxy to call the initialize function
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(account).delegatecall(abi.encodeWithSignature("initialize()"));
        assertTrue(success);

        // check we can not call the initialize function again (constant proxy version hardcoded in the account
        // implementation)
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        // solhint-disable-next-line avoid-low-level-calls
        (success,) = address(account).delegatecall(abi.encodeWithSignature("initialize()"));
    }
}
