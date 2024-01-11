// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactoryMultiSteps } from "src/AccountFactoryMultiSteps.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Deploy an AccountFactoryMultiSteps
/// @dev You can pass environment variables to this script to tailor the deployment.
///      Do not deploy this script in production without changing the default values!
contract AccountFactoryMultiStepsDeploy is BaseScript {
    // This is currently the universal address of the 4337 entrypoint
    address internal constant ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    // This is the first account exposed by Anvil
    address internal constant NAME_SERVICE_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() public broadcast returns (AccountFactoryMultiSteps) {
        address entrypoint = vm.envOr("ENTRYPOINT", ENTRYPOINT);
        address webAuthnVerifier = vm.envOr("WEBAUTHN_VERIFIER", address(0));
        address nameServiceOwner = vm.envOr("NAME_SERVICE_OWNER", NAME_SERVICE_OWNER);

        return new AccountFactoryMultiSteps(entrypoint, webAuthnVerifier, nameServiceOwner);
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script AccountFactoryMultiStepsDeploy --rpc-url <RPC_URL> --ledger --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script AccountFactoryMultiStepsDeploy --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script AccountFactoryMultiStepsDeploy --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
