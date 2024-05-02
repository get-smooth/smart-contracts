// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__ValidateCreationSignature is BaseTest {
    SmartAccountHarness internal account;
    AccountFactoryHarness internal factory;
    MockEntryPoint internal entrypoint;

    // deploy the mocked entrypoint, the mocked factory, the account
    function setUp() external setUpCreateFixture {
        // 1. Deploy a mock of the entrypoint
        entrypoint = new MockEntryPoint();

        // 2. Deploy an implementation of the account
        address accountImplementation = address(new SmartAccountHarness(address(entrypoint), makeAddr("verifier")));

        // 3. deploy the implementation of the factory and its instance
        factory = new AccountFactoryHarness(address(accountImplementation), SMOOTH_SIGNER.addr);

        // 4. deploy a valid instance of the account implementation and set a valid signer
        account = SmartAccountHarness(
            payable(
                address(
                    factory.exposed_deployAccount(
                        keccak256(createFixtures.signer.credId),
                        createFixtures.signer.pubX,
                        createFixtures.signer.pubY,
                        createFixtures.signer.credId
                    )
                )
            )
        );
    }

    // utilitary function that calculates a valid initCode and the signature
    function _calculateInitCodeAndSignature() internal view returns (bytes memory initCode, bytes memory signature) {
        signature = craftDeploymentSignature(createFixtures.response.authData, address(account));

        initCode = abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(
                AccountFactory.createAndInitAccount.selector,
                createFixtures.response.authData,
                signature,
                createFixtures.transaction.calldataHash
            )
        );
    }

    function test_FailsIfNonceNot0(uint256 fuzzedNonce) external {
        // it fails if called twice

        fuzzedNonce = bound(fuzzedNonce, 1, type(uint256).max);

        // 1. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. check the signature validation is failure -- nonce not equal to 0
        assertEq(
            account.exposed_validateCreationSignature(
                fuzzedNonce, initCode, createFixtures.transaction.callData, signature
            ),
            Signature.State.FAILURE
        );
    }

    function test_RevertsIfTheInitCodeIsNotCorrectlyConstructed() external {
        // it fails if the initcode is not correctly constructured

        // 1. get valid signature
        (, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. construct invalid initcode (authData/signature inverted)
        bytes memory invalidInitCode = abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(
                AccountFactory.createAndInitAccount.selector,
                signature,
                createFixtures.response.authData,
                createFixtures.transaction.calldataHash
            )
        );

        // 3. check the signature validation is failure
        vm.expectRevert();
        account.exposed_validateCreationSignature(0, invalidInitCode, createFixtures.transaction.callData, signature);
    }

    function test_FailsIfTheUseropFactoryIsNotCorrect(address incorrectFactory) external {
        // it fails if the userop factory is not correct

        vm.assume(incorrectFactory != address(factory));

        // 1. get valid signature
        (, bytes memory sig) = _calculateInitCodeAndSignature();

        // 2. construct invalid initcode (incorrect factory address)
        bytes memory invalidInitCode = abi.encodePacked(
            address(incorrectFactory), // incorrect factory address
            abi.encodeWithSelector(
                AccountFactory.createAndInitAccount.selector,
                createFixtures.response.authData,
                sig,
                createFixtures.transaction.calldataHash
            )
        );

        // 3. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, invalidInitCode, createFixtures.transaction.callData, sig),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfTheAdminOfTheFactoryIsNotCorrect(address incorrectSigner) external {
        // it fails if the admin of the factory is not correct
        vm.assume(incorrectSigner != SMOOTH_SIGNER.addr);

        // 1. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. mock the call that fetch factory's admin. The idea of the test is to set a different
        // admin in the factory that the one used to sign the signature. The call is expected to revert
        // as the signer doesn't correspond to the expected one.
        vm.mockCall(
            address(factory), abi.encodeWithSelector(OwnableUpgradeable.owner.selector), abi.encode(incorrectSigner)
        );

        // 3. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, signature),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfThePassedSignatureIsNotCorrect(string memory name) external {
        // it fails if the passed signature is not correct

        // 1. create an invalid signature with a random signer
        (, uint256 signerSK) = makeAddrAndKey(name);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSK, keccak256("Signed by someone else"));
        bytes memory invalidSign = abi.encodePacked(r, s, v);

        // 2. get valid initcode and signature
        (bytes memory initCode,) = _calculateInitCodeAndSignature();

        // 3. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, invalidSign),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfThePassedCalldataHashIsNotCorrect(bytes calldata incorrectCallData) external {
        // it fails if the passed signature is not correct

        // 1. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. check the signature validation is failure (because calldata incorrect)
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, incorrectCallData, signature), Signature.State.FAILURE
        );
    }

    function test_FailsIfSignatureTypeMissing() external {
        // it fails if the passed signature is not correct

        // 1. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. remove the signature type from the signature
        bytes memory invalidSig = truncBytes(signature, 1, signature.length);

        // 3. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, invalidSig),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfTheCredIdDoesNotMatchTheCredIdStored(bytes32 incorrectCredIdHash) external {
        // it fails if the credId does not match the credId stored

        // 1. make sure the fuzzed values do not match the real ones
        vm.assume(incorrectCredIdHash != keccak256(createFixtures.signer.credId));

        // 2. replace the stored value of the valid credIdHash with the incorrect value
        bytes32 credIdStorageSlot =
            SignerVaultWebAuthnP256R1.getSignerStartingSlot(keccak256(createFixtures.signer.credId));
        vm.store(address(account), credIdStorageSlot, incorrectCredIdHash);

        // 3. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 4. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, signature),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfThePubKeyXDoesNotMatchThePubKeyXStored(uint256 incorrectPubKeyX) external {
        // it fails if the pubKeyX does not match the pubKeyX stored

        // 1. make sure the fuzzed values do not match the real ones
        vm.assume(incorrectPubKeyX != createFixtures.signer.pubX);

        // 2. replace the stored value of the valid credIdHash with the incorrect value
        bytes32 pubKeyXStorageSlot = bytes32(
            uint256(SignerVaultWebAuthnP256R1.getSignerStartingSlot(keccak256(createFixtures.signer.credId))) + 1
        );
        vm.store(address(account), pubKeyXStorageSlot, bytes32(incorrectPubKeyX));

        // 3. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 4. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, signature),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfThePubKeyYDoesNotMatchThePubKeyYStored(uint256 incorrectPubKeyY) external {
        // it fails if the pubKeyY does not match the pubKeyY stored

        // 1. make sure the fuzzed values do not match the real ones
        vm.assume(incorrectPubKeyY != createFixtures.signer.pubY);

        // 2. replace the stored value of the valid credIdHash with the incorrect value
        bytes32 pubKeyXStorageSlot = bytes32(
            uint256(SignerVaultWebAuthnP256R1.getSignerStartingSlot(keccak256(createFixtures.signer.credId))) + 2
        );
        vm.store(address(account), pubKeyXStorageSlot, bytes32(incorrectPubKeyY));

        // 3. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 4. check the signature validation is failure
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, signature),
            Signature.State.FAILURE
        );
    }

    function test_SucceedIfTheSignatureRecoveryIsCorrect() external {
        // it succeed if the signature recovery is correct

        // 1. get valid initcode and signature
        (bytes memory initCode, bytes memory signature) = _calculateInitCodeAndSignature();

        // 2. check the signature validation is successful
        assertEq(
            account.exposed_validateCreationSignature(0, initCode, createFixtures.transaction.callData, signature),
            Signature.State.SUCCESS
        );
    }
}

contract SmartAccountHarness is SmartAccount {
    constructor(address entryPoint, address webAuthnVerifier) SmartAccount(entryPoint, webAuthnVerifier) { }

    function exposed_validateCreationSignature(
        uint256 nonce,
        bytes calldata initCode,
        bytes calldata callData,
        bytes calldata signature
    )
        external
        returns (uint256)
    {
        return _validateCreationSignature(nonce, initCode, callData, signature);
    }
}

contract AccountFactoryHarness is AccountFactory {
    constructor(address accountImplementation, address operator) AccountFactory(accountImplementation, operator) { }

    function exposed_deployAccount(
        bytes32 credIdHash,
        uint256 pubX,
        uint256 pubY,
        bytes memory credId
    )
        external
        returns (SmartAccount account)
    {
        return _deployAccount(credIdHash, pubX, pubY, credId);
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
