// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract AccountFactory__RecoverNameServiceSignature is BaseTest {
    AccountFactoryHarness internal factory;

    function setUp() external setUpCreateFixture {
        // 1. deploy the factory implementation and one instance of the factory
        factory = new AccountFactoryHarness(makeAddr("account"), SMOOTH_SIGNER.addr);
    }

    function test_ReturnTrueIfTheSignatureIsValid() external view {
        // it return true if the signature is valid

        // 1. calculate the future address of the account
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. generate the valid signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        assertTrue(
            factory.exposed_isSignatureLegit(
                accountAddress, createFixtures.transaction.calldataHash, createFixtures.response.authData, signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSigner() external {
        // it return false if not the correct signer

        // 1. deploy a new factory with a different operator
        AccountFactoryHarness factory2 = new AccountFactoryHarness(makeAddr("account"), makeAddr("incorrect-operator"));

        // 2. calculate the future address of the account
        address accountAddress = factory2.getAddress(createFixtures.response.authData);

        // 3. generate the valid signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        // 4. make sure the signature is not valid
        assertFalse(
            factory2.exposed_isSignatureLegit(
                accountAddress, createFixtures.transaction.calldataHash, createFixtures.response.authData, signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectAuthData(bytes calldata fakeAuthData) external view {
        // it return false if not the correct pubKey

        // 1. calculate the future address of the account
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        // 2. generate the valid signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        assertFalse(
            factory.exposed_isSignatureLegit(
                accountAddress, createFixtures.transaction.calldataHash, fakeAuthData, signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectAccountAddress(address incorrectAddr) external view {
        // it return false if not the correct AccountAddress

        // 1. make sure the fuzzed address is not correct
        address accountAddress = factory.getAddress(createFixtures.response.authData);
        vm.assume(accountAddress != incorrectAddr);

        // 2. generate the valid signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountAddress);

        assertFalse(
            factory.exposed_isSignatureLegit(
                incorrectAddr, createFixtures.transaction.calldataHash, createFixtures.response.authData, signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSignature(bytes32 hash) external view {
        // it return false if not the correct signature

        // 1. calculate the future address of the account
        address accountAddress = factory.getAddress(createFixtures.response.authData);

        assertFalse(
            factory.exposed_isSignatureLegit(
                accountAddress,
                createFixtures.transaction.calldataHash,
                createFixtures.response.authData,
                abi.encodePacked(hash, hash)
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSignatureLength(bytes32 r, bytes32 s) external view {
        // it return false if not the correct signature length

        // NOTE: A valid ecdsa signature is 65 bytes long. We add a 1 byte type to it meaning
        //       the signature is 66 bytes long. We test for 64 and 66 bytes long signatures
        bytes memory signature64Bytes = abi.encodePacked(r, s);
        bytes memory signature67Bytes = abi.encodePacked(r, s, hex"aabbcc");

        // calculate the signature and the future address of the account
        address accountAddr = factory.getAddress(createFixtures.response.authData);

        assertFalse(
            factory.exposed_isSignatureLegit(
                accountAddr, createFixtures.transaction.calldataHash, createFixtures.response.authData, signature64Bytes
            )
        );
        assertFalse(
            factory.exposed_isSignatureLegit(
                accountAddr, createFixtures.transaction.calldataHash, createFixtures.response.authData, signature67Bytes
            )
        );
    }
}

/// @title Wrapper of the AccountFactory contract that exposes internal methods
/// @notice This contract is only intended to be used for testing purposes
/// @dev Keep in mind this wrapper adds extra cost to the gas consumption, only use it for
/// testing internal methods
contract AccountFactoryHarness is AccountFactory {
    constructor(address accountImplementation, address operator) AccountFactory(accountImplementation, operator) { }

    function exposed_isSignatureLegit(
        address accountAddress,
        bytes32 callDataHash,
        bytes calldata authenticatorData,
        bytes calldata signature
    )
        external
        view
        returns (bool)
    {
        return _isSignatureLegit(accountAddress, callDataHash, authenticatorData, signature);
    }
}
