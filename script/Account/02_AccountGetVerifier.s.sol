// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetVerifier
/// @notice Fetch the webauthn p256r1 verifier of the account
contract AccountGetVerifier is BaseScript {
    function run() public broadcast returns (address webauthnVerifier) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the verifier used by the account
        webauthnVerifier = account.webAuthnVerifier();
    }
}
