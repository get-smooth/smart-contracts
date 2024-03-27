// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { VmSafe } from "forge-std/Vm.sol";

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

        // generate the wallet for the secret signer
        VmSafe.Wallet memory signer = vm.createWallet(72);

        // recreate the message to sign
        bytes memory message = abi.encode(Signature.Type.CREATION, address(32), block.chainid);

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and get the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // we call the function of this contract that wrap the recover function exposed by the library to move the
        // signature to calldata
        bool isValid = this.wrappedRecover(signer.addr, message, signature);

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
