// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";
import { Metadata } from "src/v1/Metadata.sol";

/// @title  SmartAccountDeploy
/// @notice Deploy the implementation of the smart-account
contract SmartAccountDeploy is BaseScript {
    function run() public broadcast returns (SmartAccount) {
        address entryPoint = vm.envAddress("ENTRYPOINT");
        address verifier = vm.envAddress("WEBAUTHN_VERIFIER");

        // 1. Check if the address of the entryPoint is correct
        require(entryPoint.code.length > 0, "The entrypoint is not deployed");

        // 2. Check if the address of the verifier is correct
        require(verifier.code.length > 0, "The verifier is not deployed");

        // 3. Deploy the smart account
        SmartAccount account = new SmartAccount(entryPoint, verifier);

        // 4. Check the version of the account factory is the expected one
        assertEqVersion(Metadata.VERSION, account.VERSION());
        return account;
    }
}
