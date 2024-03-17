// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster } from "src/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__Ownership is BaseTest {
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

        assertEq(paymaster.VERSION(), "1.0.0");
    }
}
