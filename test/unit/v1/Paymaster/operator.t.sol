// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract Paymaster__Operator is BaseTest {
    address private immutable owner = makeAddr("owner");
    address private immutable operator = makeAddr("operator");
    address private immutable newOperator = makeAddr("newOperator");
    address private immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;

    function setUp() external {
        paymaster = new Paymaster(entrypoint, owner, operator);
    }

    function test_AllowOperatorUpdateByOwner() external {
        // it allow operator update by owner

        // we impersonate the owner and update the operator to the notOwner
        vm.prank(owner);
        paymaster.transferOperator(newOperator);

        // make sure the operator has been updated
        assertEq(paymaster.operator(), newOperator);
    }

    function test_AllowOperatorUpdateByOperator() external {
        // it allow operator update by operator

        // we impersonate the owner and update the operator to the notOwner
        vm.prank(operator);
        paymaster.transferOperator(newOperator);

        // make sure the operator has been updated
        assertEq(paymaster.operator(), newOperator);
    }

    function test_AllowOperatorToBeFetch() external {
        // it allow operator to be fetch

        assertEq(paymaster.operator(), operator);
    }

    function test_AllowSettingOperatorToZero() external {
        // it allow setting operator to zero

        // we impersonate the operator and update the operator to the notOwner
        vm.prank(operator);
        paymaster.transferOperator(address(0));

        // make sure the operator has been updated
        assertEq(paymaster.operator(), address(0));
    }

    function test_RevertIfUpdateFromUnauthorizedAddress(address unauthorized) external {
        // it revert if update from unauthorized address

        vm.assume(unauthorized != owner && unauthorized != operator);

        // we impersonate the unauthorized and try to update the operator to the notOwner -- expect revert
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        paymaster.transferOperator(newOperator);

        // make sure the operator has not been updated
        assertEq(paymaster.operator(), operator);
    }
}
