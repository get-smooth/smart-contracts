// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Vm } from "forge-std/Vm.sol";

contract Account__EntryPoint is BaseTest {
    function test_ExposeTheEntryPoint(address entryPoint) external {
        // it expose the entry point

        SmartAccount account = new SmartAccount(entryPoint, makeAddr("verifier"));
        assertEq(address(account.entryPoint()), entryPoint);
    }
}
