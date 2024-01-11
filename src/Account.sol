// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";

contract Account {
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
}
