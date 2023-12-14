// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";

/// @title  A signer vault for WebAuthn signers using the p256r1 curve.
/// @notice Use this library to store and retrieve WebAuthn signers.
/// @dev    This library is using a custom storage layout to avoid collisions with other contracts.
library SignerVaultWebAuthnP256R1 {
    /// @dev Structure representing a signer using the p256r1 curve in the context of WebAuthn.
    ///      - clientIdHash: The hash of the signer's client ID. This hash is used to determine
    ///        the unique storage slot used to start storing the signer's data.
    ///      - pubkeyX: The X coordinate of the signer's public key.
    ///      - pubkeyY: The Y coordinate of the signer's public key.
    ///      The process for deriving the storage slot involves hashing the clientIdHash with
    ///      the root slot. The resulting slot is where the clientIdHash itself is stored.
    ///      The subsequent slots are used to store the X and Y coordinates of the public key.
    struct WebAuthnP256R1Signer {
        bytes32 clientIdHash;
        uint256 pubkeyX;
        uint256 pubkeyY;
    }

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
    /// @dev    Use `tryGet` for scenarios where the absence of a signer should cause a revert.
    /// @param  clientId The client ID of the signer, which is hashed to retrieve the signer's data.
    ///         Notably, in WebAuthn contexts, this data is dynamically sized and unpredictable in length.
    /// @return WP256r1signer A struct containing all the signer's data.
    ///         Returns an empty WP256r1signer (bytes32(0), uint256(0), uint256(0)) if no signer is found.
    function get(bytes memory clientId) internal view returns (WebAuthnP256R1Signer memory WP256r1signer) {
        bytes32 slot = getSignerStartingSlot(keccak256(clientId));
        bytes32 clientIdHash;
        uint256 pubkeyX;
        uint256 pubkeyY;

        assembly ("memory-safe") {
            clientIdHash := sload(slot)
            pubkeyX := sload(add(slot, 1))
            pubkeyY := sload(add(slot, 2))
        }

        WP256r1signer = WebAuthnP256R1Signer({ clientIdHash: clientIdHash, pubkeyX: pubkeyX, pubkeyY: pubkeyY });
    }

    /// @notice Retrieves all data associated with a stored signer and reverts if the signer does not exist.
    /// @dev    Use `get` instead if you prefer non-reverting behavior in the absence of a signer.
    /// @param  clientId The client ID of the signer, which is hashed before retrieving the signer's data.
    ///         In WebAuthn contexts, this client ID is dynamically sized and unpredictable in length.
    /// @return WP256r1signer A struct containing all the signer's data. Reverts with SignerNotFound error if no signer
    ///         is found.
    function tryGet(bytes memory clientId) internal view returns (WebAuthnP256R1Signer memory WP256r1signer) {
        WP256r1signer = get(clientId);

        if (WP256r1signer.clientIdHash == bytes32(0)) {
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
}
