// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { Metadata } from "src/v1/Metadata.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract Paymaster__Versionning is BaseTest {
    address private immutable owner = makeAddr("owner");
    address private immutable operator = makeAddr("operator");
    address private immutable notOwner = makeAddr("notOwner");
    address private immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;

    function setUp() external {
        paymaster = new Paymaster(entrypoint, owner, operator);
    }

    function test_AllowVersionFetching() external {
        // it allow version fetching

        assertEq(paymaster.VERSION(), Metadata.VERSION);
    }
}
