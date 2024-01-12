// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";
import { WebAuthn256r1 } from "@webauthn/WebAuthn256r1.sol";

/// @title  A signer vault for WebAuthn signers using the p256r1 curve.
/// @notice Use this library to store and retrieve WebAuthn signers.
/// @dev    This library is using a custom storage layout to avoid collisions with other contracts.
library SignerVaultWebAuthnP256R1 {
    /// @dev    Used by `tryGet` to revert if there is no signer
    error SignerNotFound(bytes clientId);

    /// @dev    The constant string identifier used to calculate the root slot.
    ///         The root slot is used as the starting point for derivating the storage slot for each signer.
    ///         It is extremely important this key never changes. It must stay the same for this type of signer.
    /// @notice This constant represents the root slot, a foundational element in calculating storage
    ///         locations for each signer.
    /// @dev    A signer is represented by a clientIdHash and the two coordinates of its pubkey.
    ///         - The clientIdHash is first encoded and then hashed with the root slot to determine the specific slot
    ///             for storing the clientIdHash. The two coordinates of the pubkey are stored in the subsequent slots.
    ///         - The root slot is computed as the keccak256 hash of a value derived from a constant string,
    ///             modified to ensure the last byte does not form part of the slot address.
    ///         Final value: 0x766490bc3db2290d3ce2c7c2b394a53399f99517ba4974536d11869c06dc8900
    bytes32 internal constant ROOT = StorageSlotRegistry.WEBAUTHN_P256R1_SIGNER;

    /// @notice Calculates the starting storage slot for a signer based on their clientIdHash.
    /// @dev    This function determines the storage location for a signer's data:
    ///         - The first slot, returned by this function, is allocated for the clientIdHash.
    ///         - The following slot stores the X coordinates of the public key.
    ///         - The slot after that is designated for the Y coordinates of the public key.
    /// @param  clientIdHash The clientIdHash used for deriving the storage slot.
    /// @return slot The calculated slot designated as the starting location for the signer's data.
    function getSignerStartingSlot(bytes32 clientIdHash) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(ROOT, clientIdHash));
    }

    /// @notice Stores signer's data in the vault at designated slots.
    /// @dev    This function efficiently stores the data of a signer in three distinct slots:
    ///         - The first slot is allocated for the clientIdHash.
    ///         - The second slot, directly after the first, holds the X coordinates of the public key.
    ///         - The third slot, following the second, contains the Y coordinates of the public key.
    /// @param  clientIdHash The hash of the client ID, uniquely identifying the signer.
    /// @param  pubKeyX The X coordinate of the signer's public key.
    /// @param  pubKeyY The Y coordinate of the signer's public key.
    function set(bytes32 clientIdHash, uint256 pubKeyX, uint256 pubKeyY) internal {
        bytes32 slot = getSignerStartingSlot(clientIdHash);

        // store the signer's data in the vault
        assembly ("memory-safe") {
            sstore(slot, clientIdHash)
            sstore(add(slot, 1), pubKeyX)
            sstore(add(slot, 2), pubKeyY)
        }
    }

    /// @notice Retrieves all the data associated with a stored signer.
    /// @dev    Returns an empty tuple (bytes32(0), uint256(0), uint256(0)) if no signer is found.
    ///         Use `tryGet` for scenarios where the absence of a signer should cause a revert.
    /// @param  clientId The client ID of the signer, which is hashed to retrieve the signer's data.
    ///         Notably, in WebAuthn contexts, this data is dynamically sized and unpredictable in length.
    /// @return  clientIdHash The hash of the client ID, uniquely identifying the signer.
    /// @return  pubkeyX The X coordinate of the signer's public key.
    /// @return  pubkeyY The Y coordinate of the signer's public key.
    function get(bytes memory clientId)
        internal
        view
        returns (bytes32 clientIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        return get(keccak256(clientId));
    }

    /// @notice Retrieves all the data associated with a stored signer.
    /// @dev    Returns an empty tuple (bytes32(0), uint256(0), uint256(0)) if no signer is found.
    ///         Use `tryGet` for scenarios where the absence of a signer should cause a revert.
    /// @param  _clientIdHash The hash of the client ID, uniquely identifying the signer
    /// @return clientIdHash The hash of the client ID stored at the expected slot
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function get(bytes32 _clientIdHash)
        internal
        view
        returns (bytes32 clientIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        bytes32 slot = getSignerStartingSlot(_clientIdHash);

        assembly ("memory-safe") {
            clientIdHash := sload(slot)
            pubkeyX := sload(add(slot, 1))
            pubkeyY := sload(add(slot, 2))
        }
    }

    /// @notice Retrieves all data associated with a stored signer and reverts if the signer does not exist.
    /// @dev    Reverts with SignerNotFound error if no signer is found.
    ///         Use `get` instead if you prefer non-reverting behavior in the absence of a signer.
    /// @param  clientId The client ID of the signer, which is hashed before retrieving the signer's data.
    ///         In WebAuthn contexts, this client ID is dynamically sized and unpredictable in length.
    /// @return clientIdHash The hash of the client ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function tryGet(bytes memory clientId)
        internal
        view
        returns (bytes32 clientIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (clientIdHash, pubkeyX, pubkeyY) = get(clientId);

        if (clientIdHash == bytes32(0)) {
            revert SignerNotFound(clientId);
        }
    }

    /// @notice Checks if a signer associated with a specific clientIdHash is stored in the vault.
    /// @param  clientIdHash The hashed version of the signer's client ID.
    /// @return True if the signer is stored in the vault, false otherwise.
    function has(bytes32 clientIdHash) internal view returns (bool) {
        bytes32 slot = getSignerStartingSlot(clientIdHash);
        uint256 pubkX;
        uint256 pubkY;

        assembly ("memory-safe") {
            pubkX := sload(add(slot, 1))
            pubkY := sload(add(slot, 2))
        }

        return pubkX == 0 && pubkY == 0 ? false : true;
    }

    /// @notice Verifies the presence of a signer in the vault based on the signer's client ID.
    /// @param  clientId The client ID of the signer.
    /// @return True if the signer is stored in the vault, false otherwise.
    function has(bytes memory clientId) internal view returns (bool) {
        bytes32 clientIdHash = keccak256(clientId);
        bytes32 slot = getSignerStartingSlot(clientIdHash);
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
    /// @param  clientIdHash The hash of the client ID associated with the signer.
    function remove(bytes32 clientIdHash) internal {
        bytes32 slot = getSignerStartingSlot(clientIdHash);

        // reset the storage slots associated with the signer
        assembly ("memory-safe") {
            sstore(slot, 0)
            sstore(add(slot, 1), 0)
            sstore(add(slot, 2), 0)
        }
    }

    /// @notice Retrieves the public key coordinates associated with a given clientIdHash from the vault.
    /// @dev    Returns a zeroed tuple if no signer is associated with the provided clientIdHash.
    ///         The function locates the pubkey coordinates by calculating the storage slot for the clientIdHash and
    ///         accessing the following slots where the pubkey coordinates are stored.
    /// @param  clientIdHash The hash of the client ID associated with the signer.
    /// @param  pubKeyX The X coordinate of the signer's public key.
    /// @param  pubKeyY The Y coordinate of the signer's public key.
    function pubkey(bytes32 clientIdHash) internal view returns (uint256 pubKeyX, uint256 pubKeyY) {
        bytes32 slot = getSignerStartingSlot(clientIdHash);

        assembly ("memory-safe") {
            pubKeyX := sload(add(slot, 1))
            pubKeyY := sload(add(slot, 2))
        }
    }

    /// @notice Verify ECDSA signature though WebAuthn on the secp256r1 curve
    /// @dev    This function is a wrapper around the WebAuthn256r1 library.
    ///         Note the required interactions with the precompiled contract can revert the transaction
    /// @param authenticatorDataFlagMask This is a bit mask that will be used to validate the flag in the
    ///                                  authenticator data. The flag is located at byte 32 of the authenticator
    ///                                  data and is used to indicate, among other things, wheter the user's
    ///                                  presence/verification ceremonies have been performed.
    ///                                  This argument is not expected to be exposed to the end user, it is the
    ///                                  responsibility of the caller to enforce the value of the flag for their flows.
    ///
    ///                                  Here are some flags you may want to use depending on your needs.
    ///                                  - 0x01: User presence (UP) is required. If the UP flag is not set, revert
    ///                                  - 0x04: User verification (UV) is required. If the UV flag is not set, revert
    ///                                  - 0x05: UV and UP are both accepted. If none of them is set, revert
    ///
    //                                  Read more about UP here: https://www.w3.org/TR/webauthn-2/#test-of-user-presence
    //                                  Read more about UV here: https://www.w3.org/TR/webauthn-2/#user-verification
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
    /// @param clientChallengeOffset The offset of the client challenge in the client data
    /// @param r uint256 The r value of the ECDSA signature.
    /// @param s uint256 The s value of the ECDSA signature.
    /// @param qx The x value of the public key used for the signature
    /// @param qy The y value of the public key used for the signature
    /// @return bool True if the signature is valid, false otherwise
    function verify(
        bytes1 authenticatorDataFlagMask,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata clientChallenge,
        uint256 clientChallengeOffset,
        uint256 r,
        uint256 s,
        uint256 qx,
        uint256 qy
    )
        internal
        returns (bool)
    {
        return WebAuthn256r1.verify(
            authenticatorDataFlagMask,
            authenticatorData,
            clientData,
            clientChallenge,
            clientChallengeOffset,
            r,
            s,
            qx,
            qy
        );
    }
}
