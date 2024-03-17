// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  FactoryDeploy
/// @notice Deploy the account factory
contract FactoryDeploy is BaseScript {
    function run() public broadcast returns (AccountFactory) {
        address admin = vm.envAddress("ADMIN");
        address webAuthnVerifier = vm.envAddress("WEBAUTHN_VERIFIER");
        address entrypoint = vm.envOr("ENTRYPOINT", DEFAULT_ENTRYPOINT);

        return new AccountFactory(entrypoint, webAuthnVerifier, admin);
    }
}
