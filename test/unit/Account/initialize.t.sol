// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Vm } from "forge-std/Vm.sol";

contract Account__Initiliaze is BaseTest {
    SmartAccount account;

    function setUp() external {
        // deploy the account
        account = new SmartAccount(address(1), address(2));
    }

    function test_SetTheFuseToTrue() external {
        // it set the fuse to true

        assertEq(vm.load(address(account), StorageSlotRegistry.FIRST_SIGNER_FUSE), bytes32(0));

        // initialize the account
        account.initialize();

        assertEq(vm.load(address(account), StorageSlotRegistry.FIRST_SIGNER_FUSE), bytes32(uint256(1)));
    }

    function test_CanNotBeCalledTwice() external {
        // it can not be called twice

        // initialize the account
        account.initialize();

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));

        // try to initialize the account again -- this must revert
        account.initialize();
    }
}
