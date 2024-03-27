// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { EIP1271_VALIDATION_SUCCESS, EIP1271_VALIDATION_FAILURE } from "src/v1/Account/SmartAccountEIP1271.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

struct ValidData {
    uint256 pubX;
    uint256 pubY;
    bytes signature;
    string message;
    bytes creationAuthData;
}

contract SmartAccountERC1271__EIP191 is BaseTest {
    SmartAccount internal account;
    address internal factory;

    ValidData internal data;

    function setUp() external {
        // 1. deploy the webauthn verifier
        WebAuthn256r1Wrapper webauthn = new WebAuthn256r1Wrapper();

        // 2. deploy the mocked version of the entrypoint
        MockEntryPoint entrypoint = new MockEntryPoint();

        // 3. deploy a new instance of the account
        factory = makeAddr("factory");
        vm.prank(factory);
        account = new SmartAccount(address(entrypoint), address(webauthn));

        // 4. set the signer data for the test
        // This signer has been generated for the needs of this test file. It is a valid signer.
        // The authData here is the authData generated during the creation of the signer.
        data.pubX = 0x830211546a7f4f9a9dae0d54286ef871712be6161bc6863f7a0400e5ecebfc42;
        data.pubY = 0x7cb4efd4499fe522b365a4307c66c3e8505c0f49b19bb77c0e8d356f3dd54622;
        data.creationAuthData =
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97635d00000000fbfc3007154e4ecc8c"
            hex"0b6e020557d7bd00145b392219a66159fd3949dc2695a44d1459b3fdeda5010203262001215820830211546a7f4f"
            hex"9a9dae0d54286ef871712be6161bc6863f7a0400e5ecebfc422258207cb4efd4499fe522b365a4307c66c3e8505c"
            hex"0f49b19bb77c0e8d356f3dd54622";

        // 5. set the signature data for the test
        // This signature has been generated for the needs of this test file. It is a valid signature for the signer
        // above. The message here is the message signed during the 191 flow.
        data.signature =
            hex"01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000"
            hex"000001201e12912c84d1bfd3e5515ed5c3716c250aaf03952a9d04bdab24f0f4e23bd99d9203d9416540967f4384"
            hex"541dcbbee06f0c36ece595d0cf74bf3ad0c2a2d3201b3b0af6be6e5d92d9d63bc96bef49ad4a117fdfc65ffe36dc"
            hex"0693319e3bba7673000000000000000000000000000000000000000000000000000000000000002549960de5880e"
            hex"8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631d00000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000867b22"
            hex"74797065223a22776562617574686e2e676574222c226368616c6c656e6765223a22767548445a6e6f53574a504d"
            hex"522d31694b3444774b636a36616b323672716d656954363537757667654e4d222c226f726967696e223a22687474"
            hex"703a2f2f6c6f63616c686f73743a33303030222c2263726f73734f726967696e223a66616c73657d000000000000"
            hex"0000000000000000000000000000000000000000";
        data.message = "hello you";
    }

    function test_CanValidateEIP191Signature() external {
        // it can validate EIP191 signature

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 3. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.creationAuthData);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, EIP1271_VALIDATION_SUCCESS);
    }

    function _modifiySignaturePrefix(bytes calldata signature, uint8 prefix) external pure returns (bytes memory) {
        return abi.encodePacked(prefix, signature[1:]);
    }

    function test_ReturnFailureIfNotCorrectType() external {
        // it return failure if not correct type

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 3. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.creationAuthData);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. modify the prefix of the signature
        bytes memory incorrectSignature =
            abi.encodePacked(bytes1(0x02), truncBytes(data.signature, 1, data.signature.length));

        // 4. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, incorrectSignature);
        assertEq(selector, EIP1271_VALIDATION_FAILURE);
    }

    function test_ReturnFailureIfSignerUnknown() external {
        // it return failure if signer unknown

        // 1. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 2. verify the signature using the signature and the hash
        // -- it should fail because we didn't set the signer
        bytes4 selector = account.isValidSignature(hash, data.signature);
        assertEq(selector, EIP1271_VALIDATION_FAILURE);
    }

    function test_RevertIfSignatureNotDecodable() external {
        // it revert if signature not decodable

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 3. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.creationAuthData);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. cut the signature to make it invalid
        bytes memory invalidSignature = truncBytes(data.signature, 0, data.signature.length - 32);

        // 4. verify the signature using the signature and the hash
        // -- it should revert as the signature is not decodable
        vm.expectRevert();
        account.isValidSignature(hash, invalidSignature);
    }

    function test_ReturnFailureIfHashIncorrect() external {
        // it return failure if hash incorrect

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 3. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.creationAuthData);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. alter the hash to make it incorrect
        bytes32 incorrectHash = keccak256(abi.encodePacked(hash));

        // 5. verify the signature using the signature and the hash
        // -- it should fail as the hash is incorrect
        bytes4 selector = account.isValidSignature(incorrectHash, data.signature);
        assertEq(selector, EIP1271_VALIDATION_FAILURE);
    }

    function test_ReturnFailureIfSignatureIncorrect() external {
        // it return failure if signature incorrect

        // 1. extract the credIDHash from the signature
        (,,,,, bytes32 credIdHash) = abi.decode(data.signature, (bytes1, bytes, bytes, uint256, uint256, bytes32));

        // 2. calculate the eip191 that has been signed and its hash
        bytes32 eip191Message = MessageHashUtils.toEthSignedMessageHash(bytes(data.message));
        bytes32 hash = keccak256(abi.encodePacked(eip191Message));

        // 3. set first signer and verify it has been set
        vm.prank(factory);
        account.addFirstSigner(data.creationAuthData);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. get dummy bytecode to use as signature
        bytes memory dummySignature = address(this).code;

        // 5. verify the signature using the signature and the hash
        bytes4 selector = account.isValidSignature(hash, dummySignature);
        assertEq(selector, EIP1271_VALIDATION_FAILURE);
    }
}

contract MockEntryPoint {
    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
