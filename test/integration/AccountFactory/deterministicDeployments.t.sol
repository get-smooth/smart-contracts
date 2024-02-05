// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { AccountFactoryMultiSteps } from "src/AccountFactoryMultiSteps.sol";
import { BaseTest } from "test/BaseTest.sol";

/// @notice The role of this test is to ensure our both deterministic deployment
///         flows are working as expected, and our function the predict the
///         address of an account is also working as expected.
contract AccountFactoryDeterministicDeployment is BaseTest {
    AccountFactory private factory;
    AccountFactoryMultiSteps private factoryMultiSteps;

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), validCreate.signer);
        factoryMultiSteps = new AccountFactoryMultiSteps(address(0), address(0), validCreate.signer);
    }

    function test_WhenUsingTheCreateAccountFlow() external {
        // it deploy the account to the same address calculated by getAddress

        assertEq(
            factoryMultiSteps.getAddress(validCreate.loginHash), factoryMultiSteps.createAccount(validCreate.loginHash)
        );
    }

    function test_WhenUsingTheCreateAccountAndInitFlow() external {
        // it deploy the account to the same address calculated by getAddress

        assertEq(
            factory.getAddress(validCreate.loginHash),
            factory.createAndInitAccount(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.loginHash,
                validCreate.credId,
                validCreate.signature
            )
        );
    }

    function test_WhenUsingBothFlowsWithTheSameParameters() external {
        // snapshot the state of the EVM before deploying the account
        uint256 snapshot = vm.snapshot();

        // deploy the account using `createAndInitAccount`
        address createAccountAndInitAddress = factoryMultiSteps.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
        );

        // revert to the state of the EVM before deploying the first account -- resetting the deployed account
        vm.revertTo(snapshot);

        // deploy the account using `createAccount`
        address createAccountAddress = factoryMultiSteps.createAccount(validCreate.loginHash);

        // ensure both flows deployed the account to the same address
        assertEq(createAccountAddress, createAccountAndInitAddress);
    }
}
