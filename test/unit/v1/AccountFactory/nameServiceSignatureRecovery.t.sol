// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactoryTestWrapper } from "test/unit/v1/AccountFactory/AccountFactoryTestWrapper.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__RecoverNameServiceSignature is BaseTest {
    AccountFactoryTestWrapper internal factory;

    function setUp() external {
        factory = new AccountFactoryTestWrapper(address(0), address(0), validCreate.signer);
    }

    function test_ReturnTrueIfTheSignatureIsValid() external {
        // it return true if the signature is valid
        bytes memory signature = _craftCreationSignature(address(factory));
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        assertTrue(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSigner(address alternativeSigner) external {
        // it return false if not the correct signer

        // deploy a new factory with a different admin
        vm.assume(alternativeSigner != validCreate.signer && alternativeSigner != address(0));
        AccountFactoryTestWrapper factory2 = new AccountFactoryTestWrapper(address(0), address(0), alternativeSigner);

        // calculate the signature and the future address of the account
        bytes memory signature = _craftCreationSignature(address(factory2));
        address accountAddresss = factory2.getAddress(validCreate.usernameHash);

        assertFalse(
            factory2.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectPubKey(uint256 incorrectPubX, uint256 incorrectPubY) external {
        // it return false if not the correct pubKey

        vm.assume(incorrectPubX != validCreate.pubKeyX);
        vm.assume(incorrectPubY != validCreate.pubKeyY);

        // calculate the signature and the future address of the account
        bytes memory signature = _craftCreationSignature(address(factory));
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        assertFalse(
            factory.isSignatureLegit(
                incorrectPubX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature
            )
        );

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                incorrectPubY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectLoginHash(bytes32 incorrectLoginHash) external {
        // it return false if not the correct loginHash

        vm.assume(incorrectLoginHash != validCreate.usernameHash);

        // calculate the signature and the future address of the account
        bytes memory signature = _craftCreationSignature(address(factory));
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                incorrectLoginHash,
                validCreate.credIdHash,
                accountAddresss,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectCredID(bytes32 incorrectCredIdHash) external {
        // it return false if not the correct credID

        vm.assume(incorrectCredIdHash != validCreate.credIdHash);

        // calculate the signature and the future address of the account
        bytes memory signature = _craftCreationSignature(address(factory));
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                incorrectCredIdHash,
                accountAddresss,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectAccountAddress(address incorrectAddress) external {
        // it return false if not the correct AccountAddress

        // calculate the signature and the future address of the account
        bytes memory signature = _craftCreationSignature(address(factory));
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        vm.assume(accountAddresss != incorrectAddress);

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                incorrectAddress,
                signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSignature(bytes32 randomHash) external {
        // it return false if not the correct signature

        // calculate the signature and the future address of the account
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        // generate a random private key
        uint256 signerPrivateKey = vm.createWallet(123).privateKey;

        // generate a random signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, randomHash);
        bytes memory incorrectSignature = abi.encodePacked(r, s, v);

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                incorrectSignature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSignatureLength(bytes32 r, bytes32 s) external {
        // it return false if not the correct signature length

        // NOTE: A valid signature is 65 bytes long
        bytes memory signature64Bytes = abi.encodePacked(r, s);
        bytes memory signature66Bytes = abi.encodePacked(r, s, hex"aabb");

        // calculate the signature and the future address of the account
        address accountAddresss = factory.getAddress(validCreate.usernameHash);

        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature64Bytes
            )
        );
        assertFalse(
            factory.isSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                accountAddresss,
                signature66Bytes
            )
        );
    }
}
