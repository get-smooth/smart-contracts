// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/SmartAccount.sol";
import { BaseTest } from "test/BaseTest.sol";

contract SmartAccount__Execute is BaseTest {
    address internal entrypoint;
    SmartAccount internal account;
    MockTarget internal target;

    function setUp() external {
        entrypoint = makeAddr("entrypoint");
        account = new SmartAccount(entrypoint, makeAddr("resolver"));
        target = new MockTarget();
    }

    function test_CallTheTargetWithTheGivenData() external {
        // it call the target with the given data

        bytes memory data = abi.encodeCall(MockTarget.sum, (2, 5));

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(address(target), 0, data, 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.execute(address(target), 0, data);
    }

    function test_CallTheTargetWithTheGivenDataAndValue() external {
        // it call the target with the given data and value

        bytes memory data = abi.encodeCall(MockTarget.sum, (3, 8));
        uint256 value = 1 ether;

        // send the value to the account
        payable(address(account)).transfer(1 ether);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(address(target), value, data, 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.execute(address(target), value, data);
    }

    function test_CallTheTargetEvenWithoutData() external {
        // it call the target even without data

        uint256 value = 1 ether;

        // send the value to the account
        payable(address(account)).transfer(1 ether);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(address(target), value, "", 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.execute(address(target), value, "");
    }

    function test_CallAnEOAToTransferTheValue() external {
        // it call an EOA to transfer the value

        uint256 value = 1 ether;

        // send the value to the account
        payable(address(account)).transfer(1 ether);

        // tell the VM to expect a specific call targetting an EOAonce
        vm.expectCall(address(999_999), value, "", 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.execute(address(999_999), value, "");
    }

    function test_RevertIfTheValueIsNotEnough() external {
        // it revert if the value is not enough

        bytes memory data = abi.encodeCall(MockTarget.sum, (3, 8));
        uint256 value = 2 ether;

        // send the value to the account
        payable(address(account)).transfer(1 ether);

        // use the entrypoint as the future caller
        vm.prank(entrypoint);
        vm.expectRevert();
        account.execute(address(target), value, data);
    }

    function test_RevertIfTheCallIsNotValid() external {
        // it revert if the call is not valid

        // invalid call
        bytes memory invalidData = abi.encodeWithSignature("foo(string,uint256)", "call foo", 123);

        // use the entrypoint as the future caller
        vm.prank(entrypoint);
        vm.expectRevert();
        account.execute(address(target), 0, invalidData);
    }

    function test_RevertIfTheFunctionReverts() external {
        // it revert if the function reverts

        bytes memory data = abi.encodeCall(MockTarget.sumBroken, (2, 5));

        // use the entrypoint as the future caller
        vm.prank(entrypoint);
        vm.expectRevert("MockTarget: sumBroken");
        account.execute(address(target), 0, data);
    }

    function test_RevertIfNotCalledByTheEntrypoint() external {
        // it revert if not called by the entrypoint

        bytes memory data = abi.encodeCall(MockTarget.sum, (2, 5));

        // tell the VM to expect a revert because the function is not called by the entrypoint
        vm.expectRevert("account: not from EntryPoint");
        account.execute(address(target), 0, data);
    }
}

contract MockTarget {
    function sum(uint256 a, uint256 b) external payable returns (uint256) {
        return a + b;
    }

    function sumBroken(uint256, uint256) external payable returns (uint256) {
        revert("MockTarget: sumBroken");
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable { }
}
