// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IWebAuthn256r1 } from "@webauthn/IWebAuthn256r1.sol";
import "src/utils/Signature.sol" as Signature;
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";

bytes4 constant EIP1271_VALIDATION_SUCCESS = 0x1626ba7e;
bytes4 constant EIP1271_VALIDATION_FAILURE = 0xffffffff;

abstract contract SmartAccountEIP1271 {
    function webauthn256R1Verifier() internal view virtual returns (IWebAuthn256r1);

    /// @notice Validate a signature using the EIP-1271 standard
    /// @param hash Hash of the data to be signed
    /// @param signature The signature to be validated
    /// @return The EIP-1271 magic value if the signature is valid, otherwise the EIP-1271 failure value
    function isValidSignature(bytes32 hash, bytes calldata signature) external returns (bytes4) {
        // 1. only support webauthn p256r1 signature type -- Return early if the signature type is not supported
        if (signature[0] != Signature.Type.WEBAUTHN_P256R1) return EIP1271_VALIDATION_FAILURE;

        // 3. decode the signature
        (, bytes memory authData, bytes memory clientData, uint256 r, uint256 s, bytes32 credIdHash) =
            abi.decode(signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 4. check if the signer exists and retrieve the public key of the signer
        (bytes32 _credIdHash, uint256 pubX, uint256 pubY) = SignerVaultWebAuthnP256R1.get(credIdHash);
        if (_credIdHash != credIdHash) return EIP1271_VALIDATION_FAILURE;
        if (pubX == 0 && pubY == 0) return EIP1271_VALIDATION_FAILURE;

        // 5. verify the signature -- nevert revert, always return the expected EIP1271 value
        try webauthn256R1Verifier().verify(authData, clientData, abi.encodePacked(hash), r, s, pubX, pubY) returns (
            bool isSignatureValid
        ) {
            if (isSignatureValid == false) return EIP1271_VALIDATION_FAILURE;
        } catch {
            return EIP1271_VALIDATION_FAILURE;
        }

        return EIP1271_VALIDATION_SUCCESS;
    }
}
