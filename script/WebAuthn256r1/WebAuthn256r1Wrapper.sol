// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { WebAuthn256r1 } from "@webauthn/WebAuthn256r1.sol";
import { IWebAuthn256r1 } from "@webauthn/IWebAuthn256r1.sol";

/// @title A wrapper for the WebAuthn256r1 library
contract WebAuthn256r1Wrapper is IWebAuthn256r1 {
    /// @notice Verify ECDSA signature though WebAuthn on the secp256r1 curve
    function verify(
        bytes1 authenticatorDataFlagMask,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata challenge,
        uint256 r,
        uint256 s,
        uint256 qx,
        uint256 qy
    )
        external
        returns (bool)
    {
        return WebAuthn256r1.verify(authenticatorDataFlagMask, authenticatorData, clientData, challenge, r, s, qx, qy);
    }
}
