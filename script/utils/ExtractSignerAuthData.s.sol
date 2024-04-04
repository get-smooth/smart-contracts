// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "script/Base.s.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";

/// @title  ExtractSignerAuthData
/// @notice Extract a signer from the auth data
contract ExtractSignerAuthData is BaseScript {
    function extractSignerAuthData(bytes calldata authData)
        external
        pure
        returns (bytes memory credId, bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY)
    {
        return SignerVaultWebAuthnP256R1.extractSignerFromAuthData(authData);
    }

    function run()
        external
        view
        returns (
            bytes memory credId,
            bytes32 credIdHash,
            uint256 pubkeyX,
            bytes32 pubkeyXHex,
            uint256 pubkeyY,
            bytes32 pubkeyYHex
        )
    {
        // 1. get the auth data
        bytes memory authData = vm.envBytes("AUTH_DATA");

        // 2. extract the signer from the auth data
        (credId, credIdHash, pubkeyX, pubkeyY) = ExtractSignerAuthData(address(this)).extractSignerAuthData(authData);

        // 3. convert the pubkey coordinates to hex
        pubkeyXHex = bytes32(pubkeyX);
        pubkeyYHex = bytes32(pubkeyY);
    }
}
