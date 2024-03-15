// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { TestERC721 } from "script/utils/ERC721/ERC721.sol";
import { BaseScript } from "script/Base.s.sol";

/// @title  ERC721Deploy
/// @notice Deploy a random ERC721 contract
contract ERC721Deploy is BaseScript {
    function run() external payable virtual broadcast returns (TestERC721) {
        return new TestERC721();
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script ERC721Deploy --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script ERC721Deploy --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script ERC721Deploy --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"

*/
