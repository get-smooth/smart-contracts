// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { AccountFactoryTestWrapper } from "test/unit/AccountFactory/AccountFactoryTestWrapper.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__RecoverNameServiceSignature is BaseTest {
    AccountFactoryTestWrapper internal factory;
    bytes internal signature;
    string internal login;
    address internal nameServiceOwner;

    function _createSignature(
        uint256 privateKey,
        string memory _login
    )
        internal
        returns (address addr, bytes memory sign)
    {
        // bound the fuzzed private key into a safe range for the k1 curve
        uint256 sk = boundPrivateKey(privateKey);

        // derive the address from the privateKey
        address signer = vm.addr(sk);

        // hash the provided login to get the message
        bytes32 message = keccak256(abi.encodePacked(_login));
        // reconstruct the EIP-191 hash from the provided message
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash using the fuzzed private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sk, hash);

        // reconstruct the signature from the value of r, s and v
        signature = abi.encodePacked(r, s, v);

        return (signer, signature);
    }

    function setUp() external {
        // store the login in the contract bytecode
        login = "qdqd.smoo.th";

        // make a EIP-191 signature
        (nameServiceOwner, signature) = _createSignature(12, login);

        // deploy the address of the signer in a new instance of the factory
        factory = new AccountFactoryTestWrapper(address(0), address(0), nameServiceOwner);
    }

    function test_WhenAValidButIncorrectSignatureIsProvided() external {
        // it returns false

        bytes memory wrongSignature = hex"0f58ae5d9d02744172592380e242c541bbeb9874e11b9ac3960658c1f592c28c717a"
            hex"6c973dcc9ef6c66f0ba73601d66085b12cc1435dfb1ef1723c3d6552dc091c";
        bytes32 message = keccak256(abi.encodePacked(login));
        assertFalse(factory.isNameServiceSignatureLegit(message, wrongSignature));
    }

    function test_WhenAnIncorrectMessageIsProvided(bytes32 randomMessage) external {
        // it returns false

        vm.assume(randomMessage != keccak256(abi.encodePacked(login)));

        assertFalse(factory.isNameServiceSignatureLegit(randomMessage, signature));
    }

    function test_WhenAIncorrectAddressOfTheNameServiceIsProvided(address randomNameServiceOwner) external {
        // it returns false

        vm.assume(randomNameServiceOwner != nameServiceOwner);

        AccountFactoryTestWrapper customFactory =
            new AccountFactoryTestWrapper(address(0), address(0), randomNameServiceOwner);
        bytes32 message = keccak256(abi.encodePacked(login));
        assertFalse(customFactory.isNameServiceSignatureLegit(message, signature));
    }

    function test_ShouldBeEasyToReconstructTheMessageFromTheRawLogin() external {
        // the message is the keccak256 hash of the raw login

        bytes32 message = keccak256(abi.encodePacked(login));
        assertTrue(factory.isNameServiceSignatureLegit(message, signature));
    }
}
