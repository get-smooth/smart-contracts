// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Deploy an AccountFactory
/// @notice <...envs> forge script AccountFactoryDeploy
/// @dev You can pass environment variables to this script to tailor the deployment.
///      Do not deploy this script in production without changing the default values!
contract AccountFactoryDeploy is BaseScript {
    // This is currently the universal address of the 4337 entrypoint
    address internal constant ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    // This is the first account exposed by Anvil
    address internal constant NAME_SERVICE_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() public broadcaster returns (AccountFactory) {
        address entrypoint = vm.envOr("ENTRYPOINT", ENTRYPOINT);
        address webAuthnVerifier = vm.envOr("WEBAUTHN_VERIFIER", address(0));
        address nameServiceOwner = vm.envOr("NAME_SERVICE_OWNER", NAME_SERVICE_OWNER);

        return new AccountFactory(entrypoint, webAuthnVerifier, nameServiceOwner);
    }
}
