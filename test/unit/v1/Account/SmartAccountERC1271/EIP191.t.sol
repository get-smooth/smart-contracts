// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { EIP1271_VALIDATION_SUCCESS, EIP1271_VALIDATION_FAILURE } from "src/v1/Account/SmartAccountEIP1271.sol";
import { BaseTest } from "test/BaseTest.sol";

struct ValidData {
    uint256 pubX;
    uint256 pubY;
    bytes signature;
    string message;
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

        // 4. set the valid variables
        data.pubX = 0x2db8b87b59cb3f619721879f362b5e41fb97456326f8268d36c893d065e1d12a;
        data.pubY = 0x83961a8628d4284a549a650926bcea2a8eba4e403c1b06ebd89f17a19d3db0a8;
        data.signature = hex"01000000000000000000000000000000000000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000000000000000000000c000000000000000000000"
            hex"000000000000000000000000000000000000000001205325d985efd90cece149b3e80ceaf6"
            hex"f2a3512f5019bad08bc483eb2b302c1fdc5d2e84cce174a5780e45eefbb9e93ea959bf6668"
            hex"d805bdab20af77ffc49b74023ba4564cd980f6194685e99f56a1aa7fd42d45c6912feabec2"
            hex"d3f17eb734e38b000000000000000000000000000000000000000000000000000000000000"
            hex"002549960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631d0000"
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000000000000000867b2274797065223a2277656261"
            hex"7574686e2e676574222c226368616c6c656e6765223a22767548445a6e6f53574a504d522d"
            hex"31694b3444774b636a36616b323672716d656954363537757667654e4d222c226f72696769"
            hex"6e223a22687474703a2f2f6c6f63616c686f73743a33303030222c2263726f73734f726967"
            hex"696e223a66616c73657d0000000000000000000000000000000000000000000000000000";
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
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
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
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. modify the prefix of the signature
        bytes memory incorrectSignature =
            SmartAccountERC1271__EIP191(address(this))._modifiySignaturePrefix(data.signature, 0x02);

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
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, data.pubX);
        assertEq(storedPubkeyY, data.pubY);

        // 4. cut the signature to make it invalid
        bytes memory invalidSignature = _truncBytes(data.signature, 0, data.signature.length - 32);

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
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
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
        account.addFirstSigner(data.pubX, data.pubY, credIdHash);
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
