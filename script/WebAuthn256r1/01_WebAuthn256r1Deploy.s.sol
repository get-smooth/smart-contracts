// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { WebAuthn256r1Wrapper } from "./WebAuthn256r1Wrapper.sol";
import { BaseScript } from "../Base.s.sol";

// TODO: Use CREATEX as deployer
/// @title  WebAuthn256r1Deploy
/// @notice Deploy the verifier contract for WebAuthn256r1
contract WebAuthn256r1Deploy is BaseScript {
    function run() external payable virtual broadcast returns (address) {
        return address(new WebAuthn256r1Wrapper());
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script WebAuthn256r1Deploy --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script WebAuthn256r1Deploy --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script WebAuthn256r1Deploy --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
