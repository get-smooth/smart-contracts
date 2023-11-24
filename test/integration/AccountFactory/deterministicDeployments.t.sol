// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

/// @notice The role of this test is to ensure our both deterministic deployment
///         flows are working as expected, and our function the predict the
///         address of an account is also working as expected.
/// @dev    I don't know why but by switching to the PRBTest library the test
///         `test_WhenUsingBothFlowsWithTheSameParameters` fails.
contract AccountFactoryDeterministicDeployment is BaseTest {
    bytes32 private constant LOGIN_HASH = keccak256("qdqd");
    address private constant SIGNER = 0x7a8c35e1CcE64FD85baeD9a3e4f399cAADb52f20;

    AccountFactory private factory;

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), SIGNER);
    }

    function test_WhenUsingTheCreateAccountFlow() external {
        // it should deploy the account to the same address calculated by getAddress

        assertEq(factory.getAddress(LOGIN_HASH), factory.createAccount(LOGIN_HASH));
    }

    }
