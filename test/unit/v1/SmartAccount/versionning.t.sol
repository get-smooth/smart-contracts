// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/SmartAccount.sol";
import { Metadata } from "src/v1/Metadata.sol";
import { BaseTest } from "test/BaseTest.sol";

contract SmartAccount__Versionning is BaseTest {
    SmartAccount internal account;

    function setUp() external {
        account = new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier"));
    }

    function test_AllowVersionFetching() external {
        // it allow version fetching

        assertEq(account.VERSION(), Metadata.VERSION);
    }
}
