// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccount__GetSigner is BaseTest {
    SmartAccount private account;
    address private factory;

    function setUp() external setUpCreateFixture {
        // deploy the entrypoint
        address entrypoint = address(new MockEntryPoint());

        // deploy the account using the "factory"
        factory = makeAddr("factory");
        vm.prank(factory);
        account = new SmartAccount(entrypoint, makeAddr("verifier"));
    }

    function test_ReturnsTheStoredSignerWhenPassingCredId() external {
        // it returns the stored signer when passing credId

        // 1. set the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);

        // 2. fetch the signer stored and compare it with the expected values
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) =
            account.getSigner(keccak256(createFixtures.signer.credId));
        assertEq(_credIdHash, keccak256(createFixtures.signer.credId));
        assertEq(_pubkeyX, createFixtures.signer.pubX);
        assertEq(_pubkeyY, createFixtures.signer.pubY);
    }

    function test_ReturnsTheStoredSignerWhenPassingCredIdHash() external {
        // it returns the stored signer when passing credIdHash

        // 1. set the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);

        // 2. calculate the credIdHash
        bytes32 credIdHash = keccak256(createFixtures.signer.credId);

        // 2. fetch the signer stored and compare it with the expected values
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) = account.getSigner(credIdHash);
        assertEq(_credIdHash, keccak256(createFixtures.signer.credId));
        assertEq(_pubkeyX, createFixtures.signer.pubX);
        assertEq(_pubkeyY, createFixtures.signer.pubY);
    }

    function test_ReturnsTheDefaultValueWhenPassingAnUnknownArgument() external {
        // it returns the default value when passing an unknown argument

        bytes memory unknownCredId = "unknown";

        // 1. set the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);

        // 2. pass an unknown credId
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) = account.getSigner(keccak256(unknownCredId));
        assertEq(_credIdHash, bytes32(0));
        assertEq(_pubkeyX, uint256(0));
        assertEq(_pubkeyY, uint256(0));

        // 3. pass an unknown credIdHash
        (_credIdHash, _pubkeyX, _pubkeyY) = account.getSigner(keccak256(unknownCredId));
        assertEq(_credIdHash, bytes32(0));
        assertEq(_pubkeyX, uint256(0));
        assertEq(_pubkeyY, uint256(0));
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
