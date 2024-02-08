// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Account__GetSigner is BaseTest {
    SmartAccount private account;

    function setUp() external {
        // deploy the account
        account = new SmartAccount(address(1), address(2));
    }

    function test_ReturnsTheStoredSignerWhenPassingCredId() external {
        // it returns the stored signer when passing credId

        bytes memory credId = "qdqdqdqdqddqd";
        uint256 pubkeyX = 123;
        uint256 pubkeyY = 456;

        // initialize the account and set the first signer
        account.initialize();
        account.addFirstSigner(pubkeyX, pubkeyY, keccak256(credId));

        // fetch the signer stored
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) = account.getSigner(credId);
        assertEq(_credIdHash, keccak256(credId));
        assertEq(_pubkeyX, pubkeyX);
        assertEq(_pubkeyY, pubkeyY);
    }

    function test_ReturnsTheStoredSignerWhenPassingCredIdHash() external {
        // it returns the stored signer when passing credIdHash

        bytes memory credId = "qdqdqdqdqddqd";
        bytes32 credIdHash = keccak256(credId);
        uint256 pubkeyX = 123;
        uint256 pubkeyY = 456;

        // initialize the account and set the first signer
        account.initialize();
        account.addFirstSigner(pubkeyX, pubkeyY, credIdHash);

        // fetch the signer stored
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) = account.getSigner(credIdHash);
        assertEq(_credIdHash, credIdHash);
        assertEq(_pubkeyX, pubkeyX);
        assertEq(_pubkeyY, pubkeyY);
    }

    function test_ReturnsTheDefaultValueWhenPassingAnUnknownArgument() external {
        // it returns the default value when passing an unknown argument

        bytes memory credId = "qdqdqdqdqddqd";
        bytes memory unknownCredId = "unknown";
        uint256 pubkeyX = 123;
        uint256 pubkeyY = 456;

        // initialize the account and set the first signer
        account.initialize();
        account.addFirstSigner(pubkeyX, pubkeyY, keccak256(credId));

        // fetch the signer stored using both methods
        (bytes32 _credIdHash, uint256 _pubkeyX, uint256 _pubkeyY) = account.getSigner(unknownCredId);
        assertEq(_credIdHash, bytes32(0));
        assertEq(_pubkeyX, uint256(0));
        assertEq(_pubkeyY, uint256(0));

        (_credIdHash, _pubkeyX, _pubkeyY) = account.getSigner(keccak256(unknownCredId));
        assertEq(_credIdHash, bytes32(0));
        assertEq(_pubkeyX, uint256(0));
        assertEq(_pubkeyY, uint256(0));
    }
}
