// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { SmartAccount } from "src/v1/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract SmartAccount__GetSigner is BaseTest {
    SmartAccount private account;
    MockAccountFactory private mockedFactory;

    function setUp() external {
        // deploy the mockedFactory
        mockedFactory = new MockAccountFactory(makeAddr("entrypoint"), makeAddr("verifier"), makeAddr("admin"));

        // deploy proxy that points to the implementation account contract
        account = SmartAccount(
            payable(
                new ERC1967Proxy{ salt: bytes32("random_salt") }(
                    mockedFactory.accountImplementation(), abi.encodeWithSelector(SmartAccount.initialize.selector)
                )
            )
        );
    }

    function test_ReturnsTheStoredSignerWhenPassingCredId() external {
        // it returns the stored signer when passing credId

        bytes memory credId = "qdqdqdqdqddqd";
        uint256 pubkeyX = 123;
        uint256 pubkeyY = 456;

        // ask the mockedFactory to set the first signer of the account
        mockedFactory.addFirstSigner(account, pubkeyX, pubkeyY, keccak256(credId));

        // fetch the signer stored and compare it with the expected values
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

        // ask the mockedFactory to set the first signer of the account
        mockedFactory.addFirstSigner(account, pubkeyX, pubkeyY, keccak256(credId));

        // fetch the signer stored and compare it with the expected values
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

        // ask the mockedFactory to set the first signer of the account
        mockedFactory.addFirstSigner(account, pubkeyX, pubkeyY, keccak256(credId));

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

contract MockAccountFactory is AccountFactory, BaseTest {
    constructor(address entrypoint, address verifier, address admin) AccountFactory(entrypoint, verifier, admin) { }

    function addFirstSigner(SmartAccount account, uint256 pubkeyX, uint256 pubkeyY, bytes32 credIdHash) external {
        // mock the entrypoint to return a nonce equals to 0. Condition to set a first signer
        vm.mockCall(makeAddr("entrypoint"), abi.encodeWithSelector(MockEntryPoint.getNonce.selector), abi.encode(0));

        // ask the mockedFactory to set the first signer of the account
        account.addFirstSigner(pubkeyX, pubkeyY, credIdHash);
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
