// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @title Storage Slot Registry
/// @notice This registry list all the custom storage slots used by the Smooth contracts.
/// @dev None of the values in this contract should ever change. All of the values must be unique. Never remove a value.
library StorageSlotRegistry {
    /// @notice This constant represents the root slot used to calculate the storage locations for webauthn signers on
    ///         the p256r1 curve.
    /// @dev    It is extremely important this value never changes. It must stay the same for this type of signer.
    ///         A Webauthn signer is represented by a clientIdHash and the two coordinates of its pubkey.
    ///         - The clientIdHash is first encoded and then hashed with the root slot to determine the specific slot
    ///             for storing the clientIdHash. The two coordinates of the pubkey are stored in the subsequent slots.
    ///         - The root slot is computed as the keccak256 hash of a value derived from a constant string,
    ///             modified to ensure the last byte does not form part of the slot address.
    ///         Final value: 0x766490bc3db2290d3ce2c7c2b394a53399f99517ba4974536d11869c06dc8900
    bytes32 internal constant WEBAUTHN_P256R1_SIGNER =
        keccak256(abi.encode(uint256(keccak256(abi.encode("smooth.webauthn.p256r1"))) - 1)) & ~bytes32(uint256(0xff));

    /// @notice This constant represents the root slot used to calculate the storage locations for vanilla signers on
    ///         the p256k1 curve.
    /// @dev    It is extremely important this value never changes. It must stay the same for this type of signer.
    ///         A vanilla signer is represented by one storage slot holding the signer's address
    ///         Final value: 0x4af245f3834b267909e0839a9d1bd5a4d800d78cbc580638b0487080d20b0900
    bytes32 internal constant VANILLA_P256K1_SIGNER =
        keccak256(abi.encode(uint256(keccak256(abi.encode("smooth.vanilla.p256k1"))) - 1)) & ~bytes32(uint256(0xff));

    /// @notice This is the storage slot used to store the login hash of an account.
    /// @dev    It is extremely important this value never changes.
    ///         Final value: 0x1d00c83ead4f6b6248f73d12dcfa1e48e66aad920ce1240c275af2141d4bc600
    bytes32 internal constant LOGIN_HASH =
        keccak256(abi.encode(uint256(keccak256(abi.encode("smooth.account.login"))) - 1)) & ~bytes32(uint256(0xff));

    /// @notice This is the storage slot used to store the login hash of an account.
    /// @dev    It is extremely important this value never changes.
    ///         Final value: 0x593275b89ef7c0ca3a26846843c246cc0f5f68f4b1e63ab06aab2d7c48420700
    bytes32 internal constant FIRST_SIGNER_FUSE = keccak256(
        abi.encode(uint256(keccak256(abi.encode("smooth.account.first-signer-fuse"))) - 1)
    ) & ~bytes32(uint256(0xff));
}
