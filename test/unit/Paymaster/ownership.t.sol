// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Paymaster, OwnershipTransferNotAllowed } from "src/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__Ownership is BaseTest {
    address private immutable admin = makeAddr("admin");
    address private immutable notAdmin = makeAddr("notAdmin");
    address private immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;

    function setUp() external {
        paymaster = new Paymaster(entrypoint, admin);
    }

    function test_RevertOnOwnershipTransfer() external {
        // it revert on ownership transfer

        // try to call transferOwnership with the admin address -- expect revert
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(OwnershipTransferNotAllowed.selector));
        paymaster.transferOwnership(notAdmin);

        // try to call transferOwnership with an non admin address -- expect revert
        vm.prank(notAdmin);
        vm.expectRevert(abi.encodeWithSelector(OwnershipTransferNotAllowed.selector));
        paymaster.transferOwnership(notAdmin);
    }

    function test_RevertOnOwnershipRenouncement() external {
        // it revert on ownership renouncement

        // try to call renounceOwnership with the admin address -- expect revert
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(OwnershipTransferNotAllowed.selector));
        paymaster.renounceOwnership();
    }
}
