// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccount__EntryPoint is BaseTest {
    function test_ExposeTheEntryPoint(address entryPoint) external {
        // it expose the entry point

        SmartAccount account = new SmartAccount(entryPoint, makeAddr("verifier"));
        assertEq(address(account.entryPoint()), entryPoint);
    }
}
