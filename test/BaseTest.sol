// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";

struct ValidCreationParams {
    uint256 pubKeyX;
    uint256 pubKeyY;
    string login;
    bytes32 loginHash;
    bytes credId;
    bytes signature;
    address signer;
}

contract BaseTest is Test {
    ValidCreationParams internal validCreate = ValidCreationParams({
        pubKeyX: 0x7f0d4def2ddf61e1b8a8d8f73898122dd4c19ecff4b91a532ba3600422c7cf00,
        pubKeyY: 0xc5cee7d64bcb98fa32ac34272562aad6dc268aba398221da46f6403ece710bee,
        login: "qdqd",
        loginHash: 0x13b7eff534dc834aab51c955ee64e7a3e72ca32dcd4aff4570b01d2e31c25815,
        credId: hex"eeb06fbbb0ac9baa8cacce736cab808614550b29",
        signature: hex"3f83e1480f144c8b4c7a8bed3db4e798b652dd29c4500b2a21e3c436f77ae73c528456412fc326e79f1c5908882e27"
            hex"c894c897b432b19bd4b2fe3c610ee1f8c71b",
        signer: 0xF3894322D26564e773Ad74b2a46BF4dE975ea0ec
    });

    uint256 internal constant P256R1_MAX =
        115_792_089_210_356_248_762_697_446_949_407_573_530_086_143_415_290_314_195_533_631_308_867_097_853_951;

    modifier assumeNoPrecompile(address fuzzedAddress) {
        assumeNotPrecompile(fuzzedAddress);

        _;
    }

    function boundP256R1(uint256 x) internal pure returns (uint256) {
        return x % P256R1_MAX;
    }
}
