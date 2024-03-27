// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { MockTarget } from "test/unit/v1/Account/execute.t.sol";

contract SmartAccount__ExecuteBatch is BaseTest {
    address internal entrypoint;
    SmartAccount internal account;
    MockTarget internal target1;
    MockTarget internal target2;

    function setUp() external {
        entrypoint = makeAddr("entrypoint");
        account = new SmartAccount(entrypoint, makeAddr("resolver"));
        target1 = new MockTarget();
        target2 = new MockTarget();
    }

    function test_ExecuteTheBatchIfParametersAreCorrect() external {
        // it execute the batch if parameters are correct

        bytes[] memory datas = new bytes[](3);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));
        datas[1] = abi.encodeCall(MockTarget.sum, (1, 8));
        datas[2] = abi.encodeCall(MockTarget.sum, (3, 3));

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        uint256 totalValue = values[0] + values[1] + values[2];

        address[] memory targets = new address[](3);
        targets[0] = address(target1);
        targets[1] = address(target2);
        targets[2] = address(target1);

        // send the corect value to the account
        payable(address(account)).transfer(totalValue);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(targets[0], values[0], datas[0], 1);
        vm.expectCall(targets[1], values[1], datas[1], 1);
        vm.expectCall(targets[2], values[2], datas[2], 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        // execute the batch and make sure the value has been transfered
        account.executeBatch(targets, values, datas);
        assertEq(address(account).balance, 0);
    }

    function test_ExecuteTheBatchEvenIfValuesIsEmpty() external {
        // it execute the batch even if values is empty

        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));

        // no value to send in this case
        uint256[] memory values = new uint256[](0);

        address[] memory targets = new address[](1);
        targets[0] = address(target1);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(targets[0], 0, datas[0], 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.executeBatch(targets, values, datas);
    }

    function test_ExecuteTheBatchEvenIfOnlyOneCall() external {
        // it execute the batch even if only one call

        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        address[] memory targets = new address[](1);
        targets[0] = address(target1);

        // send the value to the account
        payable(address(account)).transfer(values[0]);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(targets[0], values[0], datas[0], 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.executeBatch(targets, values, datas);
    }

    function test_DoesNothingIfArgumentsAreEmpty() external {
        // it does nothing if arguments are empty

        bytes[] memory datas = new bytes[](0);
        uint256[] memory values = new uint256[](0);
        address[] memory targets = new address[](0);

        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        account.executeBatch(targets, values, datas);
    }

    function test_RevertTheBatchIfOneOfTheCallReverts() external {
        // it revert the batch if one of the call reverts

        bytes[] memory datas = new bytes[](3);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));
        // the second call will revert, reverting the entiere batch
        datas[1] = abi.encodeCall(MockTarget.sumBroken, (1, 8));
        datas[2] = abi.encodeCall(MockTarget.sum, (3, 3));

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        uint256 totalValue = values[0] + values[1] + values[2];

        address[] memory targets = new address[](3);
        targets[0] = address(target1);
        targets[1] = address(target2);
        targets[2] = address(target1);

        // send the corect value to the account
        payable(address(account)).transfer(totalValue);

        // tell the VM to expect a specific call targetting the target contract once
        vm.expectCall(targets[0], values[0], datas[0], 1);
        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        try account.executeBatch(targets, values, datas) {
            // fail the test if the call doesn't revert
            assertTrue(false);
        } catch {
            // check the balance has not been updated -- the call reverted as expected
            assertEq(address(account).balance, totalValue);
        }
    }

    function test_RevertIfValuesAndDatasAreNotTheSameLength() external {
        // it revert if values and datas are not the same length

        bytes[] memory datas = new bytes[](3);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));
        datas[1] = abi.encodeCall(MockTarget.sum, (1, 8));
        datas[2] = abi.encodeCall(MockTarget.sum, (3, 3));

        // One value is missing here (2 values but 3 datas/targets)
        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;
        uint256 totalValue = values[0] + values[1];

        address[] memory targets = new address[](3);
        targets[0] = address(target1);
        targets[1] = address(target2);
        targets[2] = address(target1);

        // send the corect value to the account
        payable(address(account)).transfer(totalValue);

        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        vm.expectRevert(SmartAccount.IncorrectExecutionBatchParameters.selector);
        account.executeBatch(targets, values, datas);
        assertEq(address(account).balance, totalValue);
    }

    function test_RevertIfTargetsAndDatasAreNotTheSameLength() external {
        // it revert if targets and datas are not the same length

        // one data is missing here (2 datas but 3 targets/values)
        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));
        datas[1] = abi.encodeCall(MockTarget.sum, (1, 8));

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        uint256 totalValue = values[0] + values[1] + values[2];

        address[] memory targets = new address[](3);
        targets[0] = address(target1);
        targets[1] = address(target2);
        targets[2] = address(target1);

        // send the corect value to the account
        payable(address(account)).transfer(totalValue);

        // use the entrypoint as the future caller
        vm.prank(entrypoint);

        vm.expectRevert(SmartAccount.IncorrectExecutionBatchParameters.selector);
        account.executeBatch(targets, values, datas);
        assertEq(address(account).balance, totalValue);
    }

    function test_RevertIfNotCalledByTheEntrypoint() external {
        // it revert if not called by the entrypoint

        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeCall(MockTarget.sum, (2, 5));
        datas[1] = abi.encodeCall(MockTarget.sum, (1, 8));

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        uint256 totalValue = values[0] + values[1] + values[2];

        address[] memory targets = new address[](3);
        targets[0] = address(target1);
        targets[1] = address(target2);
        targets[2] = address(target1);

        // send the corect value to the account
        payable(address(account)).transfer(totalValue);

        vm.expectRevert("account: not from EntryPoint");
        account.executeBatch(targets, values, datas);
        assertEq(address(account).balance, totalValue);
    }
}
