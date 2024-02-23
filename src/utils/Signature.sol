// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ECDSA } from "@openzeppelin/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";

/// @title SignatureType
/// @notice Namespace for the different type of the signature
/// @dev Never ever delete/update an existing type. Never,
library Type {
    bytes1 internal constant CREATION = 0x00;
    bytes1 internal constant WEBAUTHN_P256R1 = 0x01;
}

/// @title SignatureState
/// @notice Namespace for the different state of the signature. Note it respects the EIP-4337 convention
/// @dev Never ever delete/update an existing type. Never,
library State {
    uint256 internal constant SUCCESS = 0;
    uint256 internal constant FAILURE = 1;
}

/// @notice Return if the signature is valid for the message and the expected address
/// @dev Use this function if your signature lives in calldata
/// @param expectedAddress The address of the expected signer
/// @param message The message that has been signed
/// @param signature The signature to recover
/// @return true if the signature is valid for the message and the expected address
function recover(address expectedAddress, bytes memory message, bytes calldata signature) pure returns (bool) {
    // hash the message to prepare it for the recovery
    bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

    // recover the address of the signer and check if it matches the expected address
    (address recoveredAddress, ECDSA.RecoverError error,) = ECDSA.tryRecover(hash, signature);
    return recoveredAddress == expectedAddress && error == ECDSA.RecoverError.NoError;
}
