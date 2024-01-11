// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";

contract Account is Initializable {
    // ==============================
    // ========= CONSTANTS ==========
    // ==============================
    IEntryPoint public immutable entryPoint;
    address public immutable webAuthnVerifier;

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
