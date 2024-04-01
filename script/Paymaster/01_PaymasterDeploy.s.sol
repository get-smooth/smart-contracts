// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";
import { Metadata } from "src/v1/Metadata.sol";

// TODO: Use CREATEX as deployer
/// @title  PaymasterDeploy
/// @notice Deploy a new paymaster contract
/// @dev    Only the owner address will be able to withdraw funds from the paymaster
///         The operator is the expected signer of the paymaster signature
contract PaymasterDeploy is BaseScript {
    function run() external payable returns (Paymaster) {
        address entryPointAddress = Metadata.entrypoint();

        // 1. Confirm the address of the entrypoint with the user
        string memory prompt = string(
            abi.encodePacked(
                "Are you okay to use this version of the entrypoint (type yes to approve): ",
                vm.toString(entryPointAddress)
            )
        );
        try vm.prompt(prompt) returns (string memory res) {
            // solhint-disable-next-line custom-errors
            // forgefmt: disable-next-item
            require(
                keccak256(abi.encodePacked(res)) == keccak256(abi.encodePacked("yes")),
                "Entrypoint not approved"
            );
        } catch (bytes memory) {
            // solhint-disable-next-line custom-errors
            revert("Entrypoint address not approved");
        }

        // 2. Check if the address of the entryPoint is deployed
        require(entryPointAddress.code.length > 0, "Entrypoint not deployed");

        // 3. Run the script using the entrypoint address
        return run(entryPointAddress);
    }

    function run(address entryPointAddress) internal virtual broadcast returns (Paymaster) {
        address owner = vm.envAddress("OWNER");
        address operator = vm.envAddress("OPERATOR");

        // 3. Check the owner address is valid
        require(owner != address(0), "Invalid owner address");

        // 3. Check the operator address is valid
        require(operator != address(0), "Invalid operator address");

        // 3. Deploy the paymaster
        Paymaster paymaster = new Paymaster(entryPointAddress, owner, operator);

        // 4. Check the version of the paymaster is the expected one
        require(Metadata.VERSION == paymaster.version(), "Version mismatch");

        return paymaster;
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    OPERATOR=<OPERATOR_ADDRESS> OWNER=<OWNER_ADDRESS> forge script PaymasterDeploy --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> OPERATOR=<OPERATOR_ADDRESS> OWNER=<OWNER_ADDRESS> forge script PaymasterDeploy \
    --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    OPERATOR=<OPERATOR_ADDRESS> OWNER=<OWNER_ADDRESS> forge script PaymasterDeploy \
    --rpc-url http://127.0.0.1:8545 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --mnemonics "test test test test test test test test test test test junk"
*/
