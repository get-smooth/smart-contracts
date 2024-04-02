// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { SmartAccount, UserOperation } from "src/v1/Account/SmartAccount.sol";
import { WebAuthn256r1Wrapper } from "script/WebAuthn256r1/WebAuthn256r1Wrapper.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__validateWebAuthnP256R1Signature is BaseTest {
    SmartAccountHarness internal smartAccount;
    EntryPointMock internal entryPoint;

    // create a valid p256r1 signature
    function _createP256R1Signature() internal view returns (bytes memory signature) {
        return abi.encode(
            Signature.Type.WEBAUTHN_P256R1,
            createFixtures.response.authData,
            createFixtures.response.clientDataJSON,
            createFixtures.signature.r,
            createFixtures.signature.s,
            keccak256(createFixtures.signer.credId)
        );
    }

    function setUp() external setUpCreateFixture {
        // 1. Mock the chain id
        vm.chainId(StaticData.CHAIN_ID);

        // 2. Deploy an entryPoint instance and copy it where it is expected
        vm.etch(StaticData.ENTRYPOINT, address(new EntryPointMock()).code);
        entryPoint = EntryPointMock(StaticData.ENTRYPOINT);

        // 3. Deploy the WebAuthn verifier library
        WebAuthn256r1Wrapper webAuthnVerifier = new WebAuthn256r1Wrapper();

        // 4. deploy the implementation of the account
        SmartAccount accountImplementation = new SmartAccountHarness(StaticData.ENTRYPOINT, address(webAuthnVerifier));

        // 5. Deploy the proxy where it is expected, and initialize it using this contract as factory
        //    This step also set the first signer of the account
        deployCodeTo(
            "ERC1967Proxy.sol",
            abi.encode(
                address(accountImplementation),
                abi.encodeWithSelector(
                    SmartAccount.initialize.selector,
                    keccak256(createFixtures.signer.credId),
                    createFixtures.signer.pubX,
                    createFixtures.signer.pubY,
                    createFixtures.signer.credId
                )
            ),
            StaticData.SENDER
        );
        smartAccount = SmartAccountHarness(StaticData.SENDER);

        // 7. ensure the fixture data we expect to use in the tests are correct
        assertEq(StaticData.getChallenge(), bytes32(createFixtures.signature.challenge));
    }

    function test_ReturnTrueIfTheSignatureRecoveryIsCorrect() external {
        // 1. Mock the call to the entryPoint to return the expected nonce
        vm.mockCall(
            address(entryPoint), abi.encodeWithSelector(EntryPointMock.getNonce.selector), abi.encode(StaticData.NONCE)
        );

        // 2. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            // fields relevant for the flow
            sender: StaticData.SENDER,
            nonce: StaticData.NONCE,
            callData: StaticData.CALL_DATA,
            paymasterAndData: StaticData.PAYMASTER_AND_DATA,
            signature: _createP256R1Signature(),
            // unused fields
            initCode: hex"053F",
            callGasLimit: 0x053F,
            verificationGasLimit: 0x053F,
            preVerificationGas: 0x053F,
            maxFeePerGas: 0x053F,
            maxPriorityFeePerGas: 0x053F
        });

        // 3. Verify the signature
        uint256 result = smartAccount.exposed_validateSignature(userOp);
        assertTrue(result == Signature.State.SUCCESS);
    }

    function test_ReturnFalseIfTheWebauthnLibraryReturnFalse() external {
        // 1. Mock the call to the entryPoint to return the expected nonce
        vm.mockCall(
            address(entryPoint), abi.encodeWithSelector(EntryPointMock.getNonce.selector), abi.encode(StaticData.NONCE)
        );

        // 2. Create a UserOperation with the expected values
        UserOperation memory userOp = UserOperation({
            // fields relevant for the flow
            sender: StaticData.SENDER,
            nonce: StaticData.NONCE,
            callData: StaticData.CALL_DATA,
            paymasterAndData: StaticData.PAYMASTER_AND_DATA,
            signature: _createP256R1Signature(),
            // unused fields
            initCode: hex"053F",
            callGasLimit: 0x053F,
            verificationGasLimit: 0x053F,
            preVerificationGas: 0x053F,
            maxFeePerGas: 0x053F,
            maxPriorityFeePerGas: 0x053F
        });

        // 3. mock the call to the webauthn verifier to return false
        vm.mockCall(
            smartAccount.webAuthnVerifier(),
            abi.encodeWithSelector(WebAuthn256r1Wrapper.verify.selector),
            abi.encode(false)
        );

        // 4. Ensure the signature is not valid
        uint256 result = smartAccount.exposed_validateSignature(userOp);
        assertTrue(result == Signature.State.FAILURE);
    }

    function test_ReturnFalseIfTheSignerIsNotStored() external {
        // 1. Mock the call to the entryPoint to return the expected nonce
        vm.mockCall(
            address(entryPoint), abi.encodeWithSelector(EntryPointMock.getNonce.selector), abi.encode(StaticData.NONCE)
        );

        // 2. Remove the previously set signer -- to bypass the entiere 4337 flow we prank the caller to be the
        //    smartAccount itself
        vm.prank(address(smartAccount));
        smartAccount.removeWebAuthnP256R1Signer(keccak256(createFixtures.signer.credId));

        // 3. Create a UserOperation struct -- the signer is not set
        UserOperation memory userOp = UserOperation({
            // fields relevant for the flow
            sender: StaticData.SENDER,
            nonce: StaticData.NONCE,
            callData: StaticData.CALL_DATA,
            paymasterAndData: StaticData.PAYMASTER_AND_DATA,
            signature: _createP256R1Signature(),
            // unused fields
            initCode: hex"053F",
            callGasLimit: 0x053F,
            verificationGasLimit: 0x053F,
            preVerificationGas: 0x053F,
            maxFeePerGas: 0x053F,
            maxPriorityFeePerGas: 0x053F
        });

        // 4. Verify the signature
        uint256 result = smartAccount.exposed_validateSignature(userOp);
        assertTrue(result == Signature.State.FAILURE);
    }

    function test_ReturnTrueEvenIfTheNonceIsNotCorrect() external {
        // @DEV: This is the entrypoint contract that is in charge of validating
        //       the nonce in the user operation is the correct one.
        //       Our validation function must not checking it.

        // 1. Create a UserOperation struct -- the nonce is not correct
        UserOperation memory userOp = UserOperation({
            // fields relevant for the flow
            sender: StaticData.SENDER,
            nonce: StaticData.NONCE,
            callData: StaticData.CALL_DATA,
            paymasterAndData: StaticData.PAYMASTER_AND_DATA,
            signature: _createP256R1Signature(),
            // unused fields
            initCode: hex"053F",
            callGasLimit: 0x053F,
            verificationGasLimit: 0x053F,
            preVerificationGas: 0x053F,
            maxFeePerGas: 0x053F,
            maxPriorityFeePerGas: 0x053F
        });

        // 2. Verify the signature succeeds
        uint256 result = smartAccount.exposed_validateSignature(userOp);
        assertTrue(result == Signature.State.SUCCESS);
    }

    function test_RevertIfTheSignatureIsNotDecodable() external {
        // 1. Mock the call to the entryPoint to return the expected nonce
        vm.mockCall(
            address(entryPoint), abi.encodeWithSelector(EntryPointMock.getNonce.selector), abi.encode(StaticData.NONCE)
        );

        // 2. Create an invalid signature that is not decodable
        bytes memory signature = _createP256R1Signature();
        bytes memory truncSignature = truncBytes(signature, 0, 40);

        // 3. Create a UserOperation struct -- the signature is not valid
        UserOperation memory userOp = UserOperation({
            // fields relevant for the flow
            sender: StaticData.SENDER,
            nonce: StaticData.NONCE,
            callData: StaticData.CALL_DATA,
            paymasterAndData: StaticData.PAYMASTER_AND_DATA,
            signature: truncSignature,
            // unused fields
            initCode: hex"053F",
            callGasLimit: 0x053F,
            verificationGasLimit: 0x053F,
            preVerificationGas: 0x053F,
            maxFeePerGas: 0x053F,
            maxPriorityFeePerGas: 0x053F
        });

        // 4. Verify the validation reverts
        vm.expectRevert();
        smartAccount.exposed_validateSignature(userOp);
    }
}

/*
** This library defines the data that has been used to generate the challenge.
** The resulting challenge has been used to generate all the create fixtures in the
** `test/fixtures/create.json` file.
** In order to verify the creation flow, we need to recreate the environment that has
** been used to generate the fixtures. That means:
** - Deploy an EntryPoint instance at the address `entryPointAddress`
** - Deploy a SmartAccount instance at the address `sender`
** - Set the nonce of the account to the expected value. The nonce is managed by the entryPoint
** - Set the chainId to the expected value
**
** After setting up the environement, all of the fixtures listed in the `test/fixtures/create.json`
** file would be valid.
**
** TODO: move those data somewhere else
*/
library StaticData {
    uint256 internal constant CHAIN_ID = 0x13;
    address payable internal constant SENDER = payable(0xfB10aB832bD4Efba97002d9D7B58A029CC06b6A9);
    uint256 internal constant NONCE = 0x124;
    address internal constant ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    bytes internal constant CALL_DATA =
        hex"b61d27f600000000000000000000000029e69af6083f790d31804ed9adad40ccc32accc9000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000006000000000000000000000000000000000000000000000000000000000000000041249c5"
        hex"8b00000000000000000000000000000000000000000000000000000000";
    bytes internal constant PAYMASTER_AND_DATA =
        hex"904dff443aac03cefc537a85a98c1cd590dbbcb9d41670a13abb75fc1e8ce03534a2af932c758611cd58dd0f32"
        hex"e35069c2b42a2f42fffe2f583727d3f826fcfc169ae240befc9488e36f5d0f9d5b2c16aead3ba91c";

    function getChallenge() internal pure returns (bytes32) {
        bytes memory packedData = abi.encode(SENDER, NONCE, CALL_DATA, PAYMASTER_AND_DATA);
        bytes memory encodedPackedData = abi.encode(keccak256(packedData), ENTRYPOINT, CHAIN_ID);
        return keccak256(encodedPackedData);
    }
}

contract EntryPointMock {
    function getNonce(address, uint192) external pure returns (uint256) {
        // allow the addition of the first signer
        return 0;
    }
}

contract SmartAccountHarness is SmartAccount {
    constructor(address entryPoint, address webAuthnVerifier) SmartAccount(entryPoint, webAuthnVerifier) { }

    // automatically calculate the hash of the userOp and call the internal method
    function exposed_validateSignature(UserOperation calldata userOp) external returns (uint256) {
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
