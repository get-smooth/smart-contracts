// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { Metadata } from "src/v1/Metadata.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract AccountFactory__Versionning is BaseTest {
    AccountFactory private factory;

    function setUp() external {
        factory = new AccountFactory(makeAddr("owner"), makeAddr("account"));
    }

    function test_AllowVersionFetching() external {
        // it allow version fetching

        assertEq(factory.VERSION(), Metadata.VERSION);
    }
}
