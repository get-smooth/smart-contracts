// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract Signature_Test is BaseTest {
    function test_Return0ForASuccessfulSignatureVerification() external {
        // it return 0 for a successful signature verification as specificied in the EIP-4337
        assertEq(Signature.State.SUCCESS, 0);
    }

    function test_Return1ForAFailedSignatureVerification() external {
        // it return 1 for a failed signature verification as specificied in the EIP-4337
        assertEq(Signature.State.FAILURE, 1);
    }

    function test_Return0ForACreationSignature() external {
        // it return 0 for a creation signature. This must never change!
        assertEq(Signature.Type.CREATION, bytes1(0x00));
    }

    function test_Return1ForAWebauthnP256r1Signature() external {
        // it return 1 for a webauthn p256r1 signature. This must never change!
        assertEq(Signature.Type.WEBAUTHN_P256R1, bytes1(0x01));
    }

    function test_ReturnTrueIfTheSignatureIsCorrectlyRecovered() external {
        // it return true if the signature is correctly recovered

        // we use the valid creation parameters from the BaseTest contract to recreate the message to sign
        bytes memory message = abi.encode(
            Signature.Type.CREATION,
            validCreate.loginHash,
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.credIdHash
        );
        // we get the valid signer and the valid signature from the BaseTest contract
        address expectedSigner = validCreate.signer;
        bytes memory signature = validCreate.signature;

        // we call the function of this contract that wrap the recover function exposed by the library to move the
        // signature to calldata
        bool isValid = this.wrappedRecover(expectedSigner, message, signature);

        // we assert that the call was successful and that the signature is correctly recovered
        assertEq(isValid, true);
    }

    function test_ReturnFalseIfTheSignatureIsIncorrectlyRecovered(
        address expectedSigner,
        bytes memory message,
        bytes calldata signature
    )
        external
    {
        // it return false if the signature is incorrectly recovered
        assertEq(Signature.recover(expectedSigner, message, signature), false);
    }

    //****** UTILS ******//
    function wrappedRecover(
        address expectedAddress,
        bytes memory message,
        bytes calldata signature
    )
        external
        pure
        returns (bool)
    {
        return Signature.recover(expectedAddress, message, signature);
    }
}
