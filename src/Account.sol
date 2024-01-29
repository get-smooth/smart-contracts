// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";
import { SignerVaultWebAuthnP256R1 } from "src/SignerVaultWebAuthnP256R1.sol";

contract Account is Initializable {
    // ==============================
    // ========= CONSTANTS ==========
    // ==============================
    IEntryPoint public immutable entryPoint;
    address public immutable webAuthnVerifier;
    address internal immutable factory;

    // ==============================
    // ========== EVENTS ============
    // ==============================

    /// @notice Emitted every time a signer is added to the account
    /// @dev The credIdHash is indexed to allow off-chain services to track account with same signer authorized
    event SignerAdded(bytes32 indexed credIdHash, uint256 pubkeyX, uint256 pubkeyY);

    // ==============================
    // ========== ERRORS ============
    // ==============================

    /// @notice This error is thrown if `firstSignerFuse` is set to false. That can happen if:
    ///         - `addFirstSigner` is called before calling the `initialize` function
    ///         - `firstSignerFuse` has already been called in the past
    error FirstSignerAlreadySet();
    error NotTheFactory();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @notice Called by the factory at construction time when it deploys the account
    /// @dev    Do not store any state in this function as the contract will be proxified, only immutable variables
    /// @param _entryPoint The address of the 4337 entrypoint used by this implementation
    /// @param _webAuthnVerifier The address of the webauthn library used for verify the webauthn signature
    constructor(address _entryPoint, address _webAuthnVerifier) {
        entryPoint = IEntryPoint(_entryPoint);
        webAuthnVerifier = _webAuthnVerifier;

        // address of the factory that deployed this contract.
        // only the factory will have the ability to set the first signer later on
        factory = msg.sender;
    }

    /// @notice Called once during the creation of the instance. Set the fuse that gates the assignment of the first
    ///         signer to true. The first signer can then be stored by calling the `addFirstSigner` function.
    ///         The `initializer` modifier prevents the function to be called twice during its lifetime
    function initialize() external initializer {
        bytes32 slot = StorageSlotRegistry.FIRST_SIGNER_FUSE;

        // toggle the fuse to allow the storing of the first signer by calling `addFirstSigner`
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
    }

    // ==============================
    // ======== FUNCTIONS ===========
    // ==============================

    /// @notice This modifier check if the fuse has already been burnt and revert the transaction if it is the case
    ///         if the fuse has not been burnt yet, it burns it and allow the function to be called
    /// @dev    The fuse is stored at the slot given by the constant `StorageSlotRegistry.FIRST_SIGNER_FUSE`
    modifier singleUseLock() {
        bytes32 slotFirstSignerFuse = StorageSlotRegistry.FIRST_SIGNER_FUSE;
        bool currentFuseValue;

        // check the value of the fuse variable
        assembly ("memory-safe") {
            currentFuseValue := sload(slotFirstSignerFuse)
        }

        // if the fuse has already been burnt (set to false), revert the transaction
        if (currentFuseValue == false) revert FirstSignerAlreadySet();

        // burn the fuse to prevent this function to be called again in the future
        assembly ("memory-safe") {
            sstore(slotFirstSignerFuse, 0)
        }

        // continue the execution of the function
        _;
    }

    /// @notice This modifier ensure the caller is the factory that deployed this contract
    modifier onlyFactory() {
        if (msg.sender != factory) revert NotTheFactory();
        _;
    }

    /// @notice Add the first signer to the account. This function is only call once by the factory
    ///         during the deployment of the account. All the future signers must be added using the
    ///         `addSigner` function.
    /// @dev    This function is expected to add a signer generated using the WebAuthn protocol on the
    ///         secp256r1 curve. Adding another type of signer as the first signer is not supported yet.
    ///         As the call of this function is expected to be wrapped in the same transaction than a
    ///         interaction with the account, we do not check webauthn's payload yet.
    ///         The payload is automatically check in the execution function meaning if the payload
    ///         is incorrect or do not correspond to the signer stored in this function, the whole tx
    ///         will revert (reverting de facto the signer stored in this function).
    ///         The `singleUseLock` modifier prevents this function to be called twice during its lifetime
    ///         The `onlyFactory` modifier ensures only the factory can call this function
    /// @param  pubkeyX The X coordinate of the signer's public key.
    /// @param  pubkeyY The Y coordinate of the signer's public key.
    /// @param  credIdHash The hash of the credential ID associated to the signer
    function addFirstSigner(uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) external onlyFactory singleUseLock {
        // add account's first signer and emit the signer addition event
        SignerVaultWebAuthnP256R1.set(credIdHash, pubkeyX, pubkeyY);
        emit SignerAdded(credIdHash, pubkeyX, pubkeyY);
    }

    /// @notice Return a signer stored in the account using its credIdHash. When storing a signer, the credId
    ///         is hashed using keccak256 because its length is unpredictable. This function allows to
    ///         retrieve a signer using its credIdHash.
    /// @param  _credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function getSigner(bytes32 _credIdHash)
        external
        view
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (credIdHash, pubkeyX, pubkeyY) = SignerVaultWebAuthnP256R1.get(_credIdHash);
    }

    /// @notice Return a signer stored in the account using the raw version of the credId
    ///         (without hashing it).
    /// @dev    This function hashes the credId internally adding an extra cost to the call
    /// @param  credId The credential ID, uniquely identifying the signer.
    /// @return credIdHash The hash of the credential ID, uniquely identifying the signer.
    /// @return pubkeyX The X coordinate of the signer's public key.
    /// @return pubkeyY The Y coordinate of the signer's public key.
    function getSigner(bytes memory credId)
        external
        view
        returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        (credIdHash, pubkeyX, pubkeyY) = SignerVaultWebAuthnP256R1.get(credId);
    }
}

// ==============================
// ========== STATE =============
// ==============================

// SLOT: `StorageSlotRegistry.FIRST_SIGNER_FUSE`
//  This variable is used to prevent the first signer to be added twice. Here's the expected lifecycle
//   - The slot points to the default value (0x00 = false) by default
//   - The value is set to true only once by the `initialize` function
//   - Then the value is set back to false while the `addFirstSigner` function is called
//
//   It is expected the `addFirstSigner` function is called in the same tx than the `initialize` function.
//   The `initialize` function can only be called once, meaning there is no way to set back the value to true
