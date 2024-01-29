// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { AccountFactoryMultiSteps } from "src/AccountFactoryMultiSteps.sol";
import { BaseTest } from "test/BaseTest.sol";

/// @notice The role of this test is to ensure our both deterministic deployment
///         flows are working as expected, and our function the predict the
///         address of an account is also working as expected.
/// @dev    I don't know why but by switching to the PRBTest library the test
///         `test_WhenUsingBothFlowsWithTheSameParameters` fails.
contract AccountFactoryDeterministicDeployment is BaseTest {
    bytes32 private constant LOGIN_HASH = keccak256("qdqd");
    address private constant SIGNER = 0x7a8c35e1CcE64FD85baeD9a3e4f399cAADb52f20;
    // this signature has been forged using the private key of the signer and the login hash above (message)
    bytes private constant PRE_FORGED_SIGNATURE = hex"247bbb60d4e8fd56e177234fb566331249f367465120c95ce65f"
        hex"a784b0b917cd6e19a4b6ebfb5d93a217ea76c37ff6d98d5f3aa18015e7220543a95d215a50381c";

    AccountFactory private factory;
    AccountFactoryMultiSteps private factoryMultiSteps;

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), SIGNER);
        factoryMultiSteps = new AccountFactoryMultiSteps(address(0), address(0), SIGNER);
    }

    function test_WhenUsingTheCreateAccountFlow() external {
        // it deploy the account to the same address calculated by getAddress

        assertEq(factoryMultiSteps.getAddress(LOGIN_HASH), factoryMultiSteps.createAccount(LOGIN_HASH));
    }

    function test_WhenUsingTheCreateAccountAndInitFlow() external {
        // it deploy the account to the same address calculated by getAddress

        assertEq(
            factory.getAddress(LOGIN_HASH),
            factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", PRE_FORGED_SIGNATURE)
        );
    }

    function test_WhenUsingBothFlowsWithTheSameParameters() external {
        // snapshot the state of the EVM before deploying the account
        uint256 snapshot = vm.snapshot();

        // deploy the account using `createAndInitAccount`
        address createAccountAndInitAddress =
            factoryMultiSteps.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", PRE_FORGED_SIGNATURE);

        // revert to the state of the EVM before deploying the first account -- resetting the deployed account
        vm.revertTo(snapshot);

        // deploy the account using `createAccount`
        address createAccountAddress = factoryMultiSteps.createAccount(LOGIN_HASH);

        // ensure both flows deployed the account to the same address
        assertEq(createAccountAddress, createAccountAndInitAddress);
    }
}
