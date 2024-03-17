// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { StorageSlotRegistry } from "src/utils/StorageSlotRegistry.sol";

/// @title  A signer vault for traditional signers using the p256k1 curve.
/// @notice Use this library to store and retrieve traditiona/native signers.
/// @dev    This library is using a custom storage layout to avoid collisions with other contracts.
library SignerVaultVanillaP256K1 {
    /// @notice This constant represents the root slot, a foundational element in calculating storage
    ///         locations for each signer.
    /// @dev    A signer is represented by one storage slot holding the signer's address
    ///         Final value: 0x4af245f3834b267909e0839a9d1bd5a4d800d78cbc580638b0487080d20b0900
    bytes32 internal constant ROOT = StorageSlotRegistry.VANILLA_P256K1_SIGNER;

    /// @notice Calculates the starting storage slot for a signer based on the signer's address.
    /// @dev    This function determines the storage location where the address of the signer will be stored.
    /// @param  signer The address of the signer.
    /// @return slot The calculated slot designated as the starting location for the signer's data.
    function getSignerStartingSlot(address signer) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(ROOT, signer));
    }

    /// @notice Stores the address of the signer in the vault at the designated slot.
    /// @param  signer The address of the signer.
    function set(address signer) internal {
        bytes32 slot = getSignerStartingSlot(signer);

        // store the signer's address in the vault
        assembly ("memory-safe") {
            sstore(slot, signer)
        }
    }

    /// @notice Checks if the provided address is stored as a signer.
    /// @param  signer The address of the signer.
    /// @return True if the signer is stored in the vault, false otherwise.
    function has(address signer) internal view returns (bool) {
        bytes32 slot = getSignerStartingSlot(signer);
        address storedSigner;

        assembly ("memory-safe") {
            storedSigner := sload(slot)
        }

        return signer == storedSigner;
    }

    /// @notice Removes a signer from the vault.
    /// @dev    This function resets the storage slot associated with the signer.
    /// @param  signer The address of the signer.
    function remove(address signer) internal {
        bytes32 slot = getSignerStartingSlot(signer);

        // reset the storage slots associated with the signer
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
    }
}
