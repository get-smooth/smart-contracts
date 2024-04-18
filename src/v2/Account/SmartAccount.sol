// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount as SmartAccountV1 } from "src/v1/Account/SmartAccount.sol";
import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";

/// @custom:experimental This is just a draft of the new version of the SmartAccount contract.
///                      The most important part here is the behavior of the `upgrade` function.
contract SmartAccount is SmartAccountV1 {
    constructor(address entryPoint, address webAuthnVerifier) SmartAccountV1(entryPoint, webAuthnVerifier) { }

    function upgrade() external virtual reinitializer(2) {
        // burn the nonce 0 -- this will prevent the creation flow from being called again
        IEntryPoint(entryPointAddress).incrementNonce(0);
    }
}
