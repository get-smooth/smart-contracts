// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IPaymaster } from "@eth-infinitism/interfaces/IPaymaster.sol";
import { Vm } from "forge-std/Vm.sol";
import { Paymaster, OwnershipTransferNotAllowed } from "src/Paymaster.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Paymaster__PostOp is BaseTest {
    address immutable admin = makeAddr("admin");
    address immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;

    function setUp() external {
        paymaster = new Paymaster(entrypoint, admin);
    }

    function getRandomPostOpMode(uint256 randomUint) internal pure returns (IPaymaster.PostOpMode) {
        // bound the random number to a valid range for the enum
        randomUint = bound(randomUint, 0, 2);

        // cast the random number to the enum type and return it
        IPaymaster.PostOpMode postOpMode = IPaymaster.PostOpMode(randomUint);
        return postOpMode;
    }

    function test_RevertIfTheCallerNotEntrypoint(address caller, uint256 randomUint) external {
        // it revert if the caller not entrypoint

        // make sure the fuzzed caller is not the entrypoint and prank it
        vm.assume(caller != entrypoint);

        // get a random postOpMode enum value
        IPaymaster.PostOpMode postOpMode = getRandomPostOpMode(randomUint);

        // prank the caller and expect revert on the next call
        vm.prank(caller);
        vm.expectRevert("Sender not EntryPoint");

        paymaster.postOp(postOpMode, hex"", uint256(12));
    }

    function test_DoesNothing(bytes32 context1, bytes32 context2, bytes32 context3, uint256 actualGasCost) external {
        // it never reverts

        // get a random postOpMode enum value and a random context value
        IPaymaster.PostOpMode postOpMode = getRandomPostOpMode(actualGasCost);
        bytes memory context = abi.encodePacked(context1, context2, context3);

        // tell the VM to record all the state changes and all the emitted logs
        vm.record();
        vm.recordLogs();

        // set the entrypoint as msg.sender and call the postOp method
        vm.prank(entrypoint);
        paymaster.postOp(postOpMode, context, actualGasCost);

        // ensure the postOp method did not emit any logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);

        // ensure the postOp method did not read or write any storage slots
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(paymaster));
        assertEq(reads.length, 0);
        assertEq(writes.length, 0);
    }
}
