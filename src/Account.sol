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

    // ==============================
    // ========== EVENTS ============
    // ==============================

    /// @notice Emitted every time a signer is added to the account
    /// @dev The credIdHash is indexed to allow off-chain services to track account with same signer authorized
    event SignerAdded(bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY);

    // ==============================
    // ========== ERRORS ============
    // ==============================

    /// @notice This error is thrown if `firstSignerFuse` is set to false. That can happen if:
    ///         - `addFirstSigner` is called before calling the `initialize` function
    ///         - `firstSignerFuse` has already been called in the past
    error FirstSignerAlreadySet();

    // ==============================
    // ======= CONSTRUCTION =========
    // ==============================

    /// @notice Called by the factory at contrusction time when it deploys the account
    /// @dev    Do not store any state in this function as the contract will be proxified, only immutable variables
    /// @param _entryPoint The address of the 4337 entrypoint used by this implementation
    /// @param _webAuthnVerifier The address of the webauthn library used for verify the webauthn signature
    constructor(address _entryPoint, address _webAuthnVerifier) {
        entryPoint = IEntryPoint(_entryPoint);
        webAuthnVerifier = _webAuthnVerifier;
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

    /// @notice Add the first signer to the account. This function is only call once by the factory
    ///         during the deployment of the account. All the futures signers must be added using the
    ///         `addSigner` function.
    /// @dev    This function is expected to add a signer generated using the WebAuthn protocol on the
    ///         secp256r1 curve. Adding another type of signer as the first signer is not supported yet.
    ///
    ///         As the call of this function is expected to be wrapped in the same transaction than a
    ///         interaction with the account, we do not check webauthn's payload yet.
    ///         The payload is automatically check in the execution function meaning if the payload
    ///         is incorrect or do not correspond to the signer stored in this function, the whole tx
    ///         will revert (reverting de facto the signer stored in this function)
    /// @param  pubkeyX The X coordinate of the signer's public key.
    /// @param  pubkeyY The Y coordinate of the signer's public key.
    /// @param  credId The credential ID associated to the signer
    function addFirstSigner(uint256 pubkeyX, uint256 pubkeyY, bytes memory credId) external singleUseLock {
        // the length of the credId is unpredictable (cf webauthn length), that's why we hash it
        bytes32 credIdHash = keccak256(credId);

        // add account's first signer and emit the signer addition event
        SignerVaultWebAuthnP256R1.set(credIdHash, pubkeyX, pubkeyY);
        emit SignerAdded(credIdHash, pubkeyX, pubkeyY);
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
