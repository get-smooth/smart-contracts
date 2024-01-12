// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";

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
        (bytes32 $credIdHash, uint256 $pubkeyX, uint256 $pubkeyY) = account.getSigner(credId);
        assertEq($credIdHash, keccak256(credId));
        assertEq($pubkeyX, pubkeyX);
        assertEq($pubkeyY, pubkeyY);
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
        (bytes32 $credIdHash, uint256 $pubkeyX, uint256 $pubkeyY) = account.getSigner(credIdHash);
        assertEq($credIdHash, credIdHash);
        assertEq($pubkeyX, pubkeyX);
        assertEq($pubkeyY, pubkeyY);
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
        (bytes32 $credIdHash, uint256 $pubkeyX, uint256 $pubkeyY) = account.getSigner(unknownCredId);
        assertEq($credIdHash, bytes32(0));
        assertEq($pubkeyX, uint256(0));
        assertEq($pubkeyY, uint256(0));

        ($credIdHash, $pubkeyX, $pubkeyY) = account.getSigner(keccak256(unknownCredId));
        assertEq($credIdHash, bytes32(0));
        assertEq($pubkeyX, uint256(0));
        assertEq($pubkeyY, uint256(0));
    }
}
