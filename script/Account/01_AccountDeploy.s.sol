// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";
import { Metadata } from "src/v1/Metadata.sol";

/// @title  SmartAccountDeploy
/// @notice Deploy the implementation of the smart-account
contract SmartAccountDeploy is BaseScript {
    function run() external returns (SmartAccount) {
        address entryPointAddress = Metadata.entrypoint();

        // 1. Confirm the address of the entrypoint with the user
        string memory prompt = string(
            abi.encodePacked(
                "Are you okay to use this entrypoint address (type yes to approve): ", vm.toString(entryPointAddress)
            )
        );
        try vm.prompt(prompt) returns (string memory res) {
            // solhint-disable-next-line custom-errors
            // forgefmt: disable-next-item
            require(
                keccak256(abi.encodePacked(res)) == keccak256(abi.encodePacked("yes")),
                "Entrypoint address not approved"
            );
        } catch (bytes memory) {
            // solhint-disable-next-line custom-errors
            revert("Entrypoint address not approved");
        }

        // 2. Check if the address of the entryPoint is deployed
        require(entryPointAddress.code.length > 0, "The entrypoint is not deployed");

        // 3. Run the script using the entrypoint address
        return run(entryPointAddress);
    }

    function run(address entryPointAddress) internal broadcast returns (SmartAccount) {
        address verifier = vm.envAddress("WEBAUTHN_VERIFIER");

        // 1. Check if the address of the verifier is correct
        require(verifier.code.length > 0, "The verifier is not deployed");

        // 2. Deploy the smart account
        SmartAccount account = new SmartAccount(entryPointAddress, verifier);

        // 3. Check the version of the account factory is the expected one
        assertEqVersion(Metadata.VERSION, account.VERSION());
        return account;
    }
}
