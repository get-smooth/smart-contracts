// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

// TODO: Use CREATEX as deployer
/// @title  PaymasterDeploy
/// @notice Deploy a new paymaster contract
/// @dev    Only the admin address will be able to withdraw funds from the paymaster
contract PaymasterDeploy is BaseScript {
    function run() external payable virtual broadcast returns (Paymaster) {
        address entrypoint = vm.envOr("ENTRYPOINT", DEFAULT_ENTRYPOINT);
        address admin = vm.envAddress("ADMIN");

        return new Paymaster(entrypoint, admin);
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    ADMIN=<ADMIN_ADDRESS> forge script PaymasterDeploy --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> ADMIN=<ADMIN_ADDRESS>  forge script PaymasterDeploy --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    ADMIN=<ADMIN_ADDRESS> forge script PaymasterDeploy --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
