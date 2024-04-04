// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccount__GetSigner is BaseTest {
    AccountFactory private factory;

    function setUp() external setUpCreateFixture {
        // 1. deploy a mock of the entrypoint
        address entrypoint = address(new MockEntryPoint());

        // 2. deploy the implementation of the account
        SmartAccount accountImplementation = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 3. deploy the factory
        factory = new AccountFactory(address(accountImplementation), SMOOTH_SIGNER.addr);
    }

    function _deployAndInitValidAccount() internal returns (SmartAccount) {
        // 1. calculate the future address of the account
        address accountFutureAddress = factory.getAddress(createFixtures.response.authData);

        // 2. craft the valid signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountFutureAddress);

        // 3. deploy the proxy that targets the implementation and set the first signer
        return SmartAccount(payable(factory.createAndInitAccount(createFixtures.response.authData, signature)));
    }

    function test_ReturnsTheStoredSignerWhenPassingCredId() external {
        // it returns the stored signer when passing credId

        // 1. deploy account instance and set the first signer
        SmartAccount account = _deployAndInitValidAccount();

        // 2. fetch the signer stored and compare it with the expected values
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) =
            account.getSigner(keccak256(createFixtures.signer.credId));
        assertEq(_credIdHash, keccak256(createFixtures.signer.credId));
        assertEq(_pubkeyX, createFixtures.signer.pubX);
        assertEq(_pubkeyY, createFixtures.signer.pubY);
    }

    function test_ReturnsTheStoredSignerWhenPassingCredIdHash() external {
        // it returns the stored signer when passing credIdHash

        // 1. deploy account instance and set the first signer
        SmartAccount account = _deployAndInitValidAccount();

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

        // 1. deploy account instance and set the first signer
        SmartAccount account = _deployAndInitValidAccount();

        // 2. pass an unknown credId hash
        (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) = account.getSigner(keccak256("unknown"));
        assertEq(credIdHash, bytes32(0));
        assertEq(pubkeyX, uint256(0));
        assertEq(pubkeyY, uint256(0));
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
