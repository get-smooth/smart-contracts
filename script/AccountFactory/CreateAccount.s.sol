// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Create an Account using an already deployed AccountFactory
/// @dev If you need to deploy an AccountFactory, use the Deploy script in this directory
contract CreateAccount is BaseScript {
    function run(address factoryAddress, bytes32 loginHash) public broadcast returns (address) {
        AccountFactory factory = AccountFactory(factoryAddress);
        return factory.createAccount(loginHash);
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script CreateAccount --rpc-url <RPC_URL> --ledger --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script CreateAccount --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script CreateAccount --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
