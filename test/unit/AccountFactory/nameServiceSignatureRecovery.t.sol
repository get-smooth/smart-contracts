// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactoryTestWrapper } from "test/unit/AccountFactory/AccountFactoryTestWrapper.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__RecoverNameServiceSignature is BaseTest {
    AccountFactoryTestWrapper internal factory;

    function setUp() external {
        factory = new AccountFactoryTestWrapper(address(0), address(0), validCreate.signer);
    }

    function test_ReturnTrueIfTheSignatureIsValid() external {
        // it return true if the signature is valid

        assertTrue(
            factory.isNameServiceSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.loginHash,
                validCreate.credId,
                validCreate.signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSigner(address alternativeSigner) external {
        // it return false if not the correct signer

        vm.assume(alternativeSigner != validCreate.signer);

        AccountFactoryTestWrapper factory2 = new AccountFactoryTestWrapper(address(0), address(0), alternativeSigner);

        assertFalse(
            factory2.isNameServiceSignatureLegit(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.loginHash,
                validCreate.credId,
                validCreate.signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectPubKey(uint256 incorrectPubX, uint256 incorrectPubY) external {
        // it return false if not the correct pubKey

        vm.assume(incorrectPubX != validCreate.pubKeyX);
        vm.assume(incorrectPubY != validCreate.pubKeyY);

        assertFalse(
            factory.isNameServiceSignatureLegit(
                incorrectPubX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
            )
        );

        assertFalse(
            factory.isNameServiceSignatureLegit(
                validCreate.pubKeyX, incorrectPubY, validCreate.loginHash, validCreate.credId, validCreate.signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectLoginHash(bytes32 incorrectLoginHash) external {
        // it return false if not the correct loginHash

        vm.assume(incorrectLoginHash != validCreate.loginHash);

        assertFalse(
            factory.isNameServiceSignatureLegit(
                validCreate.pubKeyX, validCreate.pubKeyY, incorrectLoginHash, validCreate.credId, validCreate.signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectCredID(bytes memory incorrectCredId) external {
        // it return false if not the correct credID

        vm.assume(keccak256(incorrectCredId) != keccak256(validCreate.credId));

        assertFalse(
            factory.isNameServiceSignatureLegit(
                validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, incorrectCredId, validCreate.signature
            )
        );
    }

    function test_ReturnFalseIfNotTheCorrectSignature(bytes32 randomHash) external {
        // it return false if not the correct signature

        // generate a random private key
        uint256 signerPrivateKey = vm.createWallet(123).privateKey;

        // generate a random signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, randomHash);
        bytes memory incorrectSignature = abi.encodePacked(r, s, v);

        assertFalse(
            factory.isNameServiceSignatureLegit(
                validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, incorrectSignature
            )
        );
    }
}
