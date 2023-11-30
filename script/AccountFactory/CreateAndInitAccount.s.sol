// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Create an Account using an already deployed AccountFactory and init it
/// @dev If you need to deploy an AccountFactory, use the Deploy script in this directory
contract CreateAndInitAccount is BaseScript {
    function run(
        address factoryAddress,
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes calldata credId,
        bytes calldata nameServiceSignature // ℹ️ must be made by the nameServiceOwner of the AccountFactory
    )
        public
        broadcast
        returns (address)
    {
        AccountFactory factory = AccountFactory(factoryAddress);
        return factory.createAndInitAccount(pubKeyX, pubKeyY, loginHash, credId, nameServiceSignature);
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script CreateAndInitAccount --rpc-url <RPC_URL> --ledger --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script CreateAndInitAccount --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script CreateAndInitAccount --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
