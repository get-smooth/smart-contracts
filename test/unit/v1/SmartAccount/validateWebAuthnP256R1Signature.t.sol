// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import { SmartAccount, UserOperation } from "src/v1/SmartAccount.sol";
import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import "src/utils/Signature.sol" as Signature;

/*
 * SIGNER DATA
 */
bytes32 constant credIdHash = 0x4cd5aa6deff7dd05707516e2d7387f952d7b0339e05aef921dda69af523ccddd;
uint256 constant PUBKEY_X = 0x10eb9a2121b69f163dfde7061c821a27f47e5fbf98f1f0e2625385a55d33108d;
uint256 constant PUBKEY_Y = 0xbb517696abfc14aba626a7b6d28796f07dd0d1cb1d15bb2f5d8ca9a0d182ef87;

/*
 * ENVIRONMENT DATA
 */
uint256 constant nonce = 0x1;
address payable constant sender = payable(0xfB10aB832bD4Efba97002d9D7B58A029CC06b6A9);
uint256 constant chainId = 0x013881;
address constant entryPointAddress = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

/*
 * TX DATA
 */
bytes constant callData =
    hex"b61d27f600000000000000000000000029e69af6083f790d31804ed9adad40ccc32accc9000000000000000000"
    hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"0000000000000000006000000000000000000000000000000000000000000000000000000000000000041249c5"
    hex"8b00000000000000000000000000000000000000000000000000000000";
bytes constant initCode = hex"";
/*
 * WEBAUTHN DATA
 */
bytes constant signature =
    hex"010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000"
    hex"0000000001209a07c80a4524bf1f57323227366cf58c1570b2de01715339b2eae4c4079db8362f5c1236df3429"
    hex"aeff30ab90b667a40e5b8bf99cde59ce5c6b75691e957fee184cd5aa6deff7dd05707516e2d7387f952d7b0339"
    hex"e05aef921dda69af523ccddd000000000000000000000000000000000000000000000000000000000000002549"
    hex"960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631d00000000000000000000000000"
    hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"00000000867b2274797065223a22776562617574686e2e676574222c226368616c6c656e6765223a22484a3534"
    hex"6245436f4e652d745431487a4c4c52307964667943676a53636f42354d74432d31304a4e774977222c226f7269"
    hex"67696e223a22687474703a2f2f6c6f63616c686f73743a33303030222c2263726f73734f726967696e223a6661"
    hex"6c73657d0000000000000000000000000000000000000000000000000000";
bytes constant paymasterAndData =
    hex"904dff443aac03cefc537a85a98c1cd590dbbcb9d41670a13abb75fc1e8ce03534a2af932c758611cd58dd0f32"
    hex"e35069c2b42a2f42fffe2f583727d3f826fcfc169ae240befc9488e36f5d0f9d5b2c16aead3ba91c";

contract SmartAccount__validateWebAuthnP256R1Signature is BaseTest {
    function setUp() external {
        // 1. Mock the chain id
        vm.chainId(chainId);

        // 2. Deploy an entryPoint instance and copy it where expected
        EntryPointMock entryPoint = new EntryPointMock();
        vm.etch(entryPointAddress, address(entryPoint).code);

        // 3. Deploy the WebAuthn verifier library
        WebAuthn256r1Wrapper webAuthnVerifier = new WebAuthn256r1Wrapper();

        // 4. Deploy an SmartAccount instance and copy it where expected
        SmartAccountMock smartAccount = new SmartAccountMock(entryPointAddress, address(webAuthnVerifier));
        vm.etch(sender, address(smartAccount).code);
    }

    function test_ReturnTrueIfTheSignatureRecoveryIsCorrect() external {
        // 0. Set the first signer of the account
        SmartAccountMock(sender).addFirstSigner(PUBKEY_X, PUBKEY_Y, credIdHash);

        // 1. Manually set the Nonce to 0x01
        EntryPointMock(entryPointAddress).incrementNonce();

        // 2. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            // fields used in the signature
            sender: sender,
            nonce: nonce,
            initCode: initCode,
            callData: callData,
            paymasterAndData: paymasterAndData,
            signature: signature,
            callGasLimit: 0xb65b,
            verificationGasLimit: 0x5bca6,
            preVerificationGas: 0xe0f9,
            maxFeePerGas: 0x156ecb419,
            maxPriorityFeePerGas: 0x156ecb3fb
        });

        // 3. Verify the signature
        uint256 result = SmartAccountMock(sender).validateSignature(userOp);
        assertTrue(result == Signature.State.SUCCESS);
    }

    function test_ReturnFalseIfTheWebauthnLibraryReturnFalse() external {
        // 1. Set the first signer of the account
        SmartAccountMock(sender).addFirstSigner(PUBKEY_X, PUBKEY_Y, credIdHash);

        // 2. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: initCode,
            callData: callData,
            paymasterAndData: paymasterAndData,
            signature: signature,
            callGasLimit: 0xb65b,
            verificationGasLimit: 0x5bca6,
            preVerificationGas: 0xe0f9,
            maxFeePerGas: 0x156ecb419,
            maxPriorityFeePerGas: 0x156ecb3fb
        });

        // 3. mock the call to the webauthn verifier to return false
        address webauthnVerifier = SmartAccountMock(sender).webAuthnVerifier();
        vm.mockCall(webauthnVerifier, abi.encodeWithSelector(WebAuthn256r1Wrapper.verify.selector), abi.encode(false));

        // 4. Ensure the signature is not valid
        uint256 result = SmartAccountMock(sender).validateSignature(userOp);
        assertTrue(result == Signature.State.FAILURE);
    }

    function test_ReturnFalseIfTheSignerIsNotStored() external {
        // it return false if the signer is not stored

        // 1. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            // fields used in the signature
            sender: sender,
            nonce: nonce,
            paymasterAndData: paymasterAndData,
            signature: signature,
            callData: callData,
            // fields not integrated in the signature
            initCode: "",
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0
        });

        // 2. Ensure the signature is not valid because the signer is not stored in the account
        uint256 result = SmartAccountMock(sender).validateSignature(userOp);
        assertTrue(result == Signature.State.FAILURE);
    }

    function test_RevertIfTheSignatureIsNotDecodable() external {
        // it revert if the signature is not decodable

        // 1. Set the first signer of the account
        SmartAccountMock(sender).addFirstSigner(PUBKEY_X, PUBKEY_Y, credIdHash);

        // 2. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            // fields used in the signature
            sender: sender,
            nonce: nonce,
            paymasterAndData: paymasterAndData,
            // only use a not long enough part of the signature to trigger the revert
            signature: _truncBytes(signature, 0, 40),
            callData: callData,
            // fields not integrated in the signature
            initCode: "",
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0
        });

        // 3. Verify the validation revert
        vm.expectRevert();
        SmartAccountMock(sender).validateSignature(userOp);
    }
}

contract EntryPointMock {
    uint256 internal _nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // allow the addition of the first signer
        return 0;
    }

    function incrementNonce() external {
        _nonce++;
    }
}

contract SmartAccountMock is SmartAccount {
    constructor(address entryPoint, address webAuthnVerifier) SmartAccount(entryPoint, webAuthnVerifier) { }

    function validateSignature(UserOperation calldata userOp) external returns (uint256) {
        bytes32 userOpHash = keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                userOp.initCode,
                userOp.callData,
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                userOp.paymasterAndData
            )
        );
        return _validateSignature(userOp, userOpHash);
    }
}
