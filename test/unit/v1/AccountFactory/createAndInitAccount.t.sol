// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract AccountFactory__CreateAndInitAccount is BaseTest {
    AccountFactory private factory;
    address private mockedEntrypoint;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreated(address account, bytes authenticatorData);

    function setUp() external setUpCreateFixture {
        // deploy the mocked mockedEntrypoint
        mockedEntrypoint = address(new MockEntryPoint());

        // deploy the factory
        factory = new AccountFactory(mockedEntrypoint, makeAddr("verifier"), SMOOTH_SIGNER.addr);
    }

    function test_UseADeterministicDeploymentProcess() external {
        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(accountAddress.code), keccak256(""));

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);
        factory.createAndInitAccount(createFixtures.response.authData, signature);

        // make sure the account contract has been deployed
        assertNotEq(keccak256(accountAddress.code), keccak256(""));
    }

    function test_ReturnExistingAccountAddressGivenAHashAlreadyUsed() external {
        // it should return the existing account address

        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // make sure the second attempt of creation return the already deployed address
        // without reverting or something else
        assertEq(
            factory.createAndInitAccount(createFixtures.response.authData, signature),
            factory.createAndInitAccount(createFixtures.response.authData, signature)
        );
    }

    function test_DeployANewAccountIfNoneExistsGivenANewHash() external {
        // it should deploy a new account if none exists

        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // deploy a valid proxy account using the constants predefined
        address proxy1 = factory.createAndInitAccount(createFixtures.response.authData, signature);

        assertNotEq(keccak256(proxy1.code), keccak256(""));
    }

    function test_RevertWithAnIncorrectValidSignature(bytes32 hash) external {
        // 1. construct a stupid signature
        bytes memory invalidSignature = abi.encodePacked(hash, vm.unixTime());

        // 2. we tell the VM to expect a revert with a precise error
        address accountAddress = factory.getAddress(createFixtures.response.authData);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountFactory.InvalidSignature.selector,
                accountAddress,
                createFixtures.response.authData,
                invalidSignature
            )
        );

        // we call the function with the invalid signature to trigger the error
        factory.createAndInitAccount(createFixtures.response.authData, invalidSignature);
    }

    function test_CallInitialize() external {
        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // we tell the VM to expect *one* call to the initialize function without any parameter
        vm.expectCall(factory.accountImplementation(), abi.encodeWithSelector(SmartAccount.initialize.selector), 1);

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(createFixtures.response.authData, signature);
    }

    function test_CallTheProxyAddFirstSignerFunction() external {
        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // we tell the VM to expect *one* call to the addFirstSigner function with the authData as parameter
        vm.expectCall(
            factory.getAddress(createFixtures.response.authData),
            abi.encodeCall(SmartAccount.addFirstSigner, (createFixtures.response.authData)),
            1
        );

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(createFixtures.response.authData, signature);
    }

    function test_TriggerAnEventOnDeployment() external {
        // predict where the account linked to a specific hash will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // // deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(factory));
        // we trigger the exact event we expect to be emitted in the next call
        emit AccountCreated(accountAddress, createFixtures.response.authData);

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(createFixtures.response.authData, signature);
    }
}

// Testing purpose only -- mimics the nonce manager of the entrypoint contract
contract MockEntryPoint {
    mapping(address account => mapping(uint256 index => uint256 nonce)) public nonces;

    function getNonce(address account, uint192 index) external view returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return nonces[account][index];
    }
}
