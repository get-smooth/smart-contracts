// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import { Account as SmartAccount, UserOperation } from "src/Account.sol";
import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import "src/utils/Signature.sol" as Signature;

/*
 * SIGNER DATA
 */
bytes32 constant credIdHash = 0x1e2610e428c731346ea84133f0f697c7f9d850dea75972a0b487a011f5bfa13f;
uint256 constant PUBKEY_X = 0x9e50fb3fb1bea8f2617ab7e110b4f78ca954a5837db303b0cf44774ce29bc289;
uint256 constant PUBKEY_Y = 0x30a5ccf7d7fc3e3337e84462a0129cb931b426130178d5ad58d62ca2246961a3;

/*
 * ENVIRONMENT DATA
 */
uint256 constant nonce = 0x01;
address payable constant sender = payable(0x0F712Ba1E2AE34EdC4DecDD6957F2E658926ecE2);
uint256 constant chainId = 0x013881;
address constant entryPointAddress = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

/*
 * TX DATA
 */
bytes constant callData =
    hex"b61d27f6000000000000000000000000a6a3690753395517744f94046d7c25281a64aa5d0000000000000000"
    hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"0000000000000000000000600000000000000000000000000000000000000000000000000000000000000004"
    hex"b0d691fe00000000000000000000000000000000000000000000000000000000";

/*
 * WEBAUTHN DATA
 */
bytes constant signature =
    hex"0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"00000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000"
    hex"0000000000000120d61fda0cc7ed7305f96b1b5fb2f9bc7e9fa8f276aad03fc52e0fde13607b8d5c1db64a8f"
    hex"efa8d2ea2fe66a341b0f8812d27e44dfaa6a8483701c3d4bf878c4dc1e2610e428c731346ea84133f0f697c7"
    hex"f9d850dea75972a0b487a011f5bfa13f00000000000000000000000000000000000000000000000000000000"
    hex"0000002549960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631d00000000000000"
    hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    hex"0000000000000000000000867b2274797065223a22776562617574686e2e676574222c226368616c6c656e67"
    hex"65223a225a737356636a353141674e30424f6b4562543774616532716c304967785262503754316447637263"
    hex"567559222c226f726967696e223a22687474703a2f2f6c6f63616c686f73743a33303030222c2263726f7373"
    hex"4f726967696e223a66616c73657d0000000000000000000000000000000000000000000000000000";

bytes constant paymasterAndData =
    hex"d9e37961e256e4c758c130969710b6cedb4c1cc7de5e93d837836371d93ce781536fd52324d90b00272e4f7f"
    hex"732519456d6a37751f0db70a7caa2f6ab0a4c1315c5774ba2905969da0a77b08458b5fe9f46f84f11c";
bytes constant clientData =
    hex"7b2274797065223a22776562617574686e2e676574222c226368616c6c656e6765223a225a737356636a3531"
    hex"41674e30424f6b4562543774616532716c304967785262503754316447637263567559222c226f726967696e"
    hex"223a22687474703a2f2f6c6f63616c686f73743a33303030222c2263726f73734f726967696e223a66616c73" hex"657d";

contract Account__validateWebAuthnP256R1Signature is BaseTest {
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
        // 1. Set the first signer of the account
        SmartAccountMock(sender).addFirstSigner(PUBKEY_X, PUBKEY_Y, credIdHash);

        // 2. Create a UserOperation with the expected values
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

        // 3. Verify the signature
        uint256 result = SmartAccountMock(sender).validateSignature(userOp);
        assertTrue(result == Signature.State.SUCCESS);
    }

    function test_ReturnFalseIfTheWebauthnLibraryReturnFalse() external {
        // 1. Set the first signer of the account
        SmartAccountMock(sender).addFirstSigner(PUBKEY_X, PUBKEY_Y, credIdHash);

        // 2. Create a UserOperation with the expected values
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
    function getNonce(address, uint192) external pure returns (uint256) {
        // allow the addition of the first signer
        return 0;
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
