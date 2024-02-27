// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { WebAuthn256r1Wrapper } from "./WebAuthn256r1Wrapper.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  WebAuthn256r1Verify
/// @notice Verify the WebAuthn256r1 signature
contract WebAuthn256r1Verify is BaseScript {
    function run() public payable broadcast returns (bool) {
        // get the address of the verifier contract
        address verifierAddress = vm.envAddress("VERIFIER");

        // get the parameters for the verification
        bytes1 authenticatorDataFlagMask = bytes1(vm.envBytes32("AUTH_DATA_FLAG_MASK"));
        bytes memory authenticatorData = vm.envBytes("AUTH_DATA");
        bytes memory clientData = vm.envBytes("CLIENT_DATA");
        bytes memory clientChallenge = vm.envBytes("CLIENT_CHALLENGE");
        uint256 clientChallengeOffset = vm.envUint("CLIENT_CHALLENGE_OFFSET");
        uint256 r = vm.envUint("R");
        uint256 s = vm.envUint("S");
        uint256 qx = vm.envUint("QX");
        uint256 qy = vm.envUint("QY");

        return WebAuthn256r1Wrapper(verifierAddress).verify(
            authenticatorDataFlagMask,
            authenticatorData,
            clientData,
            clientChallenge,
            clientChallengeOffset,
            r,
            s,
            qx,
            qy
        );
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    [envs...] forge script WebAuthn256r1Verify --rpc-url <RPC_URL> --ledger  \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> [envs...]  forge script WebAuthn256r1Verify  \
    --rpc-url <RPC_URL>[--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    [envs...]  forge script WebAuthn256r1Verify --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"
*/
