// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { VmSafe } from "forge-std/Vm.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Paymaster, UserOperation, Signature } from "src/Paymaster.sol";

struct Arguments {
    address sender;
    uint256 nonce;
    uint256 chainId;
    address paymaster;
    bytes callData;
    bytes paymasterAndData;
}

contract Paymaster__ValidatePaymasterUserOp is BaseTest {
    address private immutable entrypoint = makeAddr("entrypoint");

    Paymaster private paymaster;
    VmSafe.Wallet private admin;

    Arguments private validArguments;

    function setUp() external {
        // generate the wallet for the admin
        admin = vm.createWallet(123);

        // deploy the paymaster contract
        paymaster = new Paymaster(entrypoint, admin.addr);

        // create the signature for the paymaster
        bytes memory paymasterSignature = _signMessage({
            sender: makeAddr("sender"),
            nonce: 1,
            chainId: block.chainid,
            callData: abi.encodeWithSelector(Paymaster.owner.selector),
            paymasterAddress: address(paymaster)
        });

        // save the valid arguments for the test
        validArguments = Arguments({
            sender: makeAddr("sender"),
            nonce: 1,
            chainId: block.chainid,
            paymaster: address(paymaster),
            callData: abi.encodeWithSelector(Paymaster.owner.selector),
            paymasterAndData: abi.encodePacked(address(paymaster), paymasterSignature)
        });
    }

    function _signMessage() internal view returns (bytes memory signature) {
        return _signMessage({
            sender: validArguments.sender,
            nonce: validArguments.nonce,
            chainId: validArguments.chainId,
            callData: validArguments.callData,
            paymasterAddress: address(paymaster)
        });
    }

    function _signMessage(
        address sender,
        uint256 nonce,
        uint256 chainId,
        bytes memory callData,
        address paymasterAddress
    )
        internal
        view
        returns (bytes memory signature)
    {
        // create the message to sign
        bytes memory message = abi.encode(sender, nonce, chainId, paymasterAddress, callData);

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and return the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(admin.privateKey, hash);
        signature = abi.encodePacked(r, s, v);
    }

    function _createUserOperation(
        address sender,
        uint256 nonce,
        bytes memory paymasterAndData,
        bytes memory callData
    )
        internal
        pure
        returns (UserOperation memory userOp)
    {
        return UserOperation({
            initCode: hex"",
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            signature: hex"",
            paymasterAndData: paymasterAndData,
            sender: sender,
            nonce: nonce,
            callData: callData
        });
    }

    function _createUserOperation() internal view returns (UserOperation memory userOp) {
        return _createUserOperation({
            sender: validArguments.sender,
            nonce: validArguments.nonce,
            paymasterAndData: validArguments.paymasterAndData,
            callData: validArguments.callData
        });
    }

    function test_NeverReturnContext() external {
        // it never return context

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        // call the validate function
        vm.prank(entrypoint);
        (bytes memory context,) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(context.length, 0);
    }

    function test_RevertIfNotCalledByEntrypoint() external {
        // it revert if not called by entrypoint

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        // call the validate function from the wrong address
        vm.expectRevert("Sender not EntryPoint");
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function test_ReturnSuccessIfSignatureValidated() external {
        // it return 0 if signature validated

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.SUCCESS);
    }

    function test_ReturnFailureIfIncorrectSender() external {
        // it return 1 if incorrect sender

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        userOp.sender = makeAddr("wrongSender");

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_ReturnFailureIfIncorrectNonce() external {
        // it return 1 if incorrect nonce

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();
        userOp.nonce = 12;

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_ReturnFailureIfIncorrectChainId() external {
        // it return 1 if incorrect chainId

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        // set the chainId to an incorrect value
        userOp.paymasterAndData = abi.encodePacked(
            paymaster,
            _signMessage({
                sender: validArguments.sender,
                nonce: validArguments.nonce,
                chainId: block.chainid + 1,
                callData: validArguments.callData,
                paymasterAddress: validArguments.paymaster
            })
        );

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_ReturnFailureIfIncorrectAddress() external {
        // it return 1 if incorrect address

        // create a valid userOp
        UserOperation memory userOp = _createUserOperation();

        // set the chainId to an incorrect value
        userOp.paymasterAndData = abi.encodePacked(
            paymaster,
            _signMessage({
                sender: validArguments.sender,
                nonce: validArguments.nonce,
                chainId: validArguments.chainId,
                callData: validArguments.callData,
                paymasterAddress: makeAddr("wrongPaymaster")
            })
        );

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_ReturnFailureIfIncorrectCallData() external {
        // it return 1 if incorrect callData

        UserOperation memory userOp = _createUserOperation();

        userOp.callData = hex"1234";

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    // NOTE: The paymasterAndData is the concatenation of the paymaster address and the signature
    //       This test is to make sure the function return false if the data only contains the paymaster address
    function test_ReturnFailureIfPaymasterAndDataIs20Bytes() external {
        // it return 1 if paymasterAndData too short

        UserOperation memory userOp = _createUserOperation();

        // set the paymasterAndData to the paymaster address only
        userOp.paymasterAndData = hex"0000000000000000000000000000000000000003";

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_ReturnFailureIfAllParametersAreNull() external {
        // it return 1 all parameters are null

        UserOperation memory userOp = UserOperation({
            initCode: hex"",
            callGasLimit: 0,
            verificationGasLimit: 0,
            preVerificationGas: 0,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            signature: hex"",
            // NOTE: there is no way this function is reached with a null paymasterAndData
            // at least the address of the paymaster is always present
            paymasterAndData: abi.encodePacked(address(paymaster)),
            sender: address(0),
            nonce: 0,
            callData: hex""
        });

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);

        // make sure the context is empty
        assertEq(validationData, Signature.State.FAILURE);
    }

    function test_DoesNotReadTheStorage() external {
        // it does not read the storage

        // record every state read/write
        vm.record();

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(_createUserOperation(), bytes32(0), 0);

        // stop recording state changes and get the state diff
        (bytes32[] memory reads,) = vm.accesses(address(paymaster));

        // check the validationData is correct and no storage has been accessed
        assertEq(validationData, Signature.State.SUCCESS);
        assertEq(reads.length, 0);
    }

    function test_DoesNotWriteTheStorage() external {
        // it does not write the storage

        // record every state read/write
        vm.record();

        // call the validate function
        vm.prank(entrypoint);
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(_createUserOperation(), bytes32(0), 0);

        // stop recording state changes and get the state diff
        (, bytes32[] memory writes) = vm.accesses(address(paymaster));

        // check the validationData is correct and no storage has been accessed
        assertEq(validationData, Signature.State.SUCCESS);
        assertEq(writes.length, 0);
    }
}
