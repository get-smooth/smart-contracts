// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract AccountFactory__CreateAndInitAccount is BaseTest {
    AccountFactory private factory;
    SmartAccount private account;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreated(address account, bytes authenticatorData);

    function setUp() external setUpCreateFixture {
        // 1. deploy the implementation of the account
        address mockedEntrypoint = address(new MockEntryPoint());
        account = new SmartAccount(mockedEntrypoint, makeAddr("verifier"));

        // 2. deploy the factory
        factory = new AccountFactory(address(account), SMOOTH_SIGNER.addr);
    }

    function test_UseADeterministicDeploymentProcess() external {
        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(accountAddress.code), keccak256(""));

        // 3. deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);
        factory.createAndInitAccount(
            createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
        );

        // 4. make sure the account contract has been deployed
        assertNotEq(keccak256(accountAddress.code), keccak256(""));
    }

    function test_ReturnExistingAccountAddressGivenAHashAlreadyUsed() external {
        // it should return the existing account address

        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. make sure the second attempt of creation return the already deployed address
        // without reverting or something else
        assertEq(
            factory.createAndInitAccount(
                createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
            ),
            factory.createAndInitAccount(
                createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
            )
        );
    }

    function test_DeployANewAccountIfNoneExistsGivenANewHash() external {
        // it should deploy a new account if none exists

        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. deploy a valid proxy account using the constants predefined
        address proxy1 = factory.createAndInitAccount(
            createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
        );

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
                createFixtures.transaction.calldataHash,
                createFixtures.response.authData,
                invalidSignature
            )
        );

        // 3. we call the function with the invalid signature to trigger the error
        factory.createAndInitAccount(
            createFixtures.response.authData, invalidSignature, createFixtures.transaction.calldataHash
        );
    }

    function test_CallInitialize() external {
        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. craft the signature for the deployment
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. we tell the VM to expect *one* call to the initialize function without any parameter
        vm.expectCall(factory.accountImplementation(), abi.encodeWithSelector(SmartAccount.initialize.selector), 1);

        // 4. we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
        );
    }

    function test_SetTheFirstSigner() external {
        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. craft the deployment signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. we deploy the instance of the account
        SmartAccount newAccount = SmartAccount(
            payable(
                factory.createAndInitAccount(
                    createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
                )
            )
        );

        // 4. fetch the signer that is supposed to be stored
        (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) =
            newAccount.getSigner(keccak256(createFixtures.signer.credId));

        // 5. check the signer has been set correctly
        assertEq(keccak256(createFixtures.signer.credId), credIdHash);
        assertEq(createFixtures.signer.pubX, pubkeyX);
        assertEq(createFixtures.signer.pubY, pubkeyY);
    }

    function test_TriggerAnEventOnDeployment() external {
        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. we tell the VM to expect the exact event emitted below
        vm.expectEmit(true, true, true, true, address(factory));
        emit AccountCreated(accountAddress, createFixtures.response.authData);

        // 4. we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
        );
    }

    function test_SetTheFactoryAddressInTheProxyStorageOnInit() external {
        // it set the factory address in the proxy storage on init

        // 1. calculate where the account will be deployed
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. deploy the account contract using the same hash
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 3. we call the function that is supposed to trigger the call
        address accountDeployed = factory.createAndInitAccount(
            createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
        );

        // 4. we check the factory address has been set in the proxy storage
        assertEq(SmartAccount(payable(accountDeployed)).factory(), address(factory));
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
