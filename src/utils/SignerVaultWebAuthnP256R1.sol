// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IWebAuthn256r1 } from "@webauthn/IWebAuthn256r1.sol";
import { StorageSlotRegistry } from "src/utils/StorageSlotRegistry.sol";

/// @title  A signer vault for WebAuthn signers using the p256r1 curve.
/// @notice Use this library to store and retrieve WebAuthn signers.
/// @dev    This library is using a custom storage layout to avoid collisions with other contracts.
library SignerVaultWebAuthnP256R1 {
    /// @dev    Used by `tryGet` to revert if there is no signer
    error SignerNotFound(bytes credId);
    /// @dev    Throws if we try to override a signer that already exists
    error SignerOverrideNotAllowed(bytes32 credIdHash);

    /// @dev    The constant string identifier used to calculate the root slot.
    ///         The root slot is used as the starting point for derivating the storage slot for each signer.
    ///         It is extremely important this key never changes. It must stay the same for this type of signer.
    /// @notice This constant represents the root slot, a foundational element in calculating storage
    ///         locations for each signer.
    /// @dev    A signer is represented by a credIdHash and the two coordinates of its pubkey.
    ///         - The credIdHash is first encoded and then hashed with the root slot to determine the specific slot
    ///             for storing the credIdHash. The two coordinates of the pubkey are stored in the subsequent slots.
    ///         - The root slot is computed as the keccak256 hash of a value derived from a constant string,
    ///             modified to ensure the last byte does not form part of the slot address.
    ///         Final value: 0x766490bc3db2290d3ce2c7c2b394a53399f99517ba4974536d11869c06dc8900
    bytes32 internal constant ROOT = StorageSlotRegistry.WEBAUTHN_P256R1_SIGNER;

    /// @notice Calculates the starting storage slot for a signer based on their credIdHash.
    /// @dev    This function determines the storage location for a signer's data:
    ///         - The first slot, returned by this function, is allocated for the credIdHash.
    ///         - The following slot stores the X coordinates of the public key.
    ///         - The slot after that is designated for the Y coordinates of the public key.
    /// @param  credIdHash The credIdHash used for deriving the storage slot.
    /// @return slot The calculated slot designated as the starting location for the signer's data.
    function getSignerStartingSlot(bytes32 credIdHash) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(ROOT, credIdHash));
    }

    /// @notice Stores signer's data in the vault at designated slots.
    /// @dev    This function efficiently stores the data of a signer in three distinct slots:
    ///         - The first slot is allocated for the credIdHash.
    ///         - The second slot, directly after the first, holds the X coordinates of the public key.
    ///         - The third slot, following the second, contains the Y coordinates of the public key.
    /// @param  credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @param  pubKeyX The X coordinate of the signer's public key.
    /// @param  pubKeyY The Y coordinate of the signer's public key.
    function set(bytes32 credIdHash, uint256 pubKeyX, uint256 pubKeyY) internal {
        bytes32 slot = getSignerStartingSlot(credIdHash);

        // 1. read the current value of the slot and revert if it's not empty
        bytes32 currentValue;
        assembly ("memory-safe") {
            currentValue := sload(slot)
        }
        if (currentValue != 0) revert SignerOverrideNotAllowed(credIdHash);

        // 2. store the signer in the vault
        assembly ("memory-safe") {
            sstore(slot, credIdHash)
            sstore(add(slot, 1), pubKeyX)
            sstore(add(slot, 2), pubKeyY)
        }
    }

    /// @notice Retrieves all the data associated with a stored signer.
    /// @dev    Returns an empty tuple (bytes32(0), uint256(0), uint256(0)) if no signer is found.
    ///         Use `tryGet` for scenarios where the absence of a signer should cause a revert.
    /// @param  credId The credential ID of the signer, which is hashed to retrieve the signer's data.
    ///         Notably, in WebAuthn contexts, this data is dynamically sized and unpredictable in length.
    /// @return  credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return  pubkeyX The X coordinate of the signer's public key.
    /// @return  pubkeyY The Y coordinate of the signer's public key.
    function get(bytes memory credId) internal view returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) {
        return get(keccak256(credId));
    }

    /// @notice Retrieves all the data associated with a stored signer.
    /// @dev    Returns an empty tuple (bytes32(0), uint256(0), uint256(0)) if no signer is found.
    ///         Use `tryGet` for scenarios where the absence of a signer should cause a revert.
    /// @param  _credIdHash The hash of the credential ID, uniquely identifying the signer
    /// @return credIdHash The hash of the credential ID stored at the expected slot
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function get(bytes32 _credIdHash) internal view returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) {
        bytes32 slot = getSignerStartingSlot(_credIdHash);

        assembly ("memory-safe") {
            credIdHash := sload(slot)
            pubkeyX := sload(add(slot, 1))
            pubkeyY := sload(add(slot, 2))
        }
    }

    /// @notice Retrieves all data associated with a stored signer and reverts if the signer does not exist.
    /// @dev    Reverts with SignerNotFound error if no signer is found.
    ///         Use `get` instead if you prefer non-reverting behavior in the absence of a signer.
    /// @param  credId The credential ID of the signer, which is hashed before retrieving the signer's data.
    ///         In WebAuthn contexts, this credential ID is dynamically sized and unpredictable in length.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function tryGet(bytes memory credId) internal view returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) {
        (credIdHash, pubkeyX, pubkeyY) = get(credId);

        if (credIdHash == bytes32(0)) {
            revert SignerNotFound(credId);
        }
    }

    /// @notice Checks if a signer associated with a specific credIdHash is stored in the vault.
    /// @param  credIdHash The hashed version of the signer's credential ID.
    /// @return True if the signer is stored in the vault, false otherwise.
    function has(bytes32 credIdHash) internal view returns (bool) {
        bytes32 slot = getSignerStartingSlot(credIdHash);
        uint256 pubkX;
        uint256 pubkY;

        assembly ("memory-safe") {
            pubkX := sload(add(slot, 1))
            pubkY := sload(add(slot, 2))
        }

        return pubkX == 0 && pubkY == 0 ? false : true;
    }

    /// @notice Verifies the presence of a signer in the vault based on the signer's credential ID.
    /// @param  credId The credential ID of the signer.
    /// @return True if the signer is stored in the vault, false otherwise.
    function has(bytes memory credId) internal view returns (bool) {
        bytes32 credIdHash = keccak256(credId);
        bytes32 slot = getSignerStartingSlot(credIdHash);
        uint256 pubkX;
        uint256 pubkY;

        assembly ("memory-safe") {
            pubkX := sload(add(slot, 1))
            pubkY := sload(add(slot, 2))
        }

        return pubkX == 0 && pubkY == 0 ? false : true;
    }

    /// @notice Removes a signer from the vault.
    /// @dev    This function resets the storage slots associated with the signer.
    /// @param  credIdHash The hash of the credential ID associated with the signer.
    function remove(bytes32 credIdHash) internal {
        bytes32 slot = getSignerStartingSlot(credIdHash);

        // reset the storage slots associated with the signer
        assembly ("memory-safe") {
            sstore(slot, 0)
            sstore(add(slot, 1), 0)
            sstore(add(slot, 2), 0)
        }
    }

    /// @notice Retrieves the public key coordinates associated with a given credIdHash from the vault.
    /// @dev    Returns a zeroed tuple if no signer is associated with the provided credIdHash.
    ///         The function locates the pubkey coordinates by calculating the storage slot for the credIdHash and
    ///         accessing the following slots where the pubkey coordinates are stored.
    /// @param  credIdHash The hash of the credential ID associated with the signer.
    /// @param  pubKeyX The X coordinate of the signer's public key.
    /// @param  pubKeyY The Y coordinate of the signer's public key.
    function pubkey(bytes32 credIdHash) internal view returns (uint256 pubKeyX, uint256 pubKeyY) {
        bytes32 slot = getSignerStartingSlot(credIdHash);

        assembly ("memory-safe") {
            pubKeyX := sload(add(slot, 1))
            pubKeyY := sload(add(slot, 2))
        }
    }

    /// @notice Verify ECDSA signature though WebAuthn on the secp256r1 curve
    /// @dev    This function is a wrapper around the WebAuthn256r1 library.
    /// @param authenticatorData The authenticator data structure encodes contextual bindings made by the authenticator.
    ///                          Described here: https://www.w3.org/TR/webauthn-2/#authenticator-data
    /// @param clientData      This is the client data that was signed. The client data represents the
    ///                        contextual bindings of both the WebAuthn Relying Party and the client.
    ///                        Described here: https://www.w3.org/TR/webauthn-2/#client-data
    /// @param clientChallenge This is the challenge that was sent to the client to sign. It is
    ///                        part of the client data. In a classic non-EVM flow, this challenge
    ///                        is generated by the server and sent to the client to avoid replay
    ///                        attack. In our context, as we already have the nonce for this purpose
    ///                        we use this field to pass the arbitrary execution order.
    ///                        This value is expected to not be encoded in Base64, the encoding is done
    ///                        during the verification.
    /// @param r uint256 The r value of the ECDSA signature.
    /// @param s uint256 The s value of the ECDSA signature.
    /// @param qx The x value of the public key used for the signature
    /// @param qy The y value of the public key used for the signature
    /// @return bool True if the signature is valid, false otherwise
    function verify(
        IWebAuthn256r1 verifier,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata clientChallenge,
        uint256 r,
        uint256 s,
        uint256 qx,
        uint256 qy
    )
        internal
        returns (bool)
    {
        return verifier.verify(authenticatorData, clientData, clientChallenge, r, s, qx, qy);
    }

    // TODO: Need more tests for this function
    /// @notice Extract the signer from the authenticatorData
    /// @dev    This function is free to be called (!!)
    /// @param authenticatorData The authenticatorData field of the WebAuthn response when creating a signer
    /// @return credId The credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function extractSignerFromAuthData(bytes calldata authenticatorData)
        internal
        pure
        returns (bytes memory credId, bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        // The authenticatorData is composed of:
        // - 32 bytes for the rpIdHash --NOT_USED--
        // - 1 bytes for the flags --NOT_USED--
        // - 4 bytes for the signCount --NOT_USED--
        // - N bytes for the attestedCredentialData
        // - M bytes for the extensions --NOT_USED_OPTIONAL--
        //
        // The `attestedCredentialData` is composed of:
        // - 16 bytes for the aaguid --NOT_USED--
        // - 2 bytes for the credentialIdLength (CL)
        // - CL bytes for the credentialId
        // - 77 bytes for the credentialPublicKey (for p256r1 curve only)
        //
        // The `credentialPublicKey` is encoded in the CTAP2 canonical CBOR encoding form.
        // For the p256r1 curve, the value is composed of:
        // - 10 bytes for the prefix 0xA5010203262001215820 that defines the type, the signature and the curve...
        // - 32 bytes for the x coordinate
        // - 3 bytes for the constant 0x225820
        // - 32 bytes for the y coordinate
        //
        // https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data
        // https://www.w3.org/TR/webauthn-2/#sctn-attested-credential-data

        // 1. extract the credId from the authData and hash it
        uint16 credIdLength = uint16(bytes2(authenticatorData[53:55]));
        credId = authenticatorData[55:(55 + credIdLength)];
        credIdHash = keccak256(credId);

        // 2. extract the public key from the authData
        uint256 pubKeyCOSEOffset = 55 + credIdLength;
        uint256 pubKeySeparator = 3;
        uint256 pubKeyXOffset = pubKeyCOSEOffset + 10;
        uint256 pubKeyYOffset = pubKeyXOffset + pubKeySeparator + 32;

        pubkeyX = uint256(bytes32(authenticatorData[pubKeyXOffset:(pubKeyXOffset + 32)]));
        pubkeyY = uint256(bytes32(authenticatorData[pubKeyYOffset:(pubKeyYOffset + 32)]));
    }
}
