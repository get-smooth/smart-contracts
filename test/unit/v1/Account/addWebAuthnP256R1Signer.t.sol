// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__AddWebAuthnP256R1Signer is BaseTest {
    SmartAccount private account;
    address private factory;
    address private entrypoint;

    uint256 private pubkeyX = 0x1;
    uint256 private pubkeyY = 0x2;

    // Duplicate of the event in the SmartAccount.sol file
    event SignerAdded(
        bytes1 indexed signatureType, bytes credId, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function setUp() external setUpCreateFixture {
        // deploy the entrypoint
        entrypoint = address(new MockEntryPoint());

        // deploy the account using the "factory"
        factory = makeAddr("factory");
        vm.prank(factory);
        account = new SmartAccount(entrypoint, makeAddr("verifier"));
    }

    function test_RevertsIfASignerAlreadyExists() external {
        // it reverts if a signer already exists

        // 1. set the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);

        // 2. Add a new signer to the account. The only way to call the function is to call it from the account itself.
        //    The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 3. we tell the VM to expect an error
        vm.expectRevert(
            abi.encodeWithSelector(
                SignerVaultWebAuthnP256R1.SignerOverrideNotAllowed.selector, keccak256(createFixtures.signer.credId)
            )
        );

        // 4. we call the function that adds the new signer
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(SmartAccount.addWebAuthnP256R1Signer.selector, createFixtures.response.authData)
        );
    }

    function test_CanOnlyBeCalledByItself(address caller) external {
        // it can only be called by itself

        // 1. we assume the caller is not the account
        vm.assume(caller != address(account));

        // 2. we tell the VM to expect an error
        vm.expectRevert(abi.encodeWithSelector(SmartAccount.NotItself.selector));

        // 3. we call the function that adds the new signer using an unauthorized caller
        vm.prank(caller);
        account.addWebAuthnP256R1Signer(createFixtures.response.authData);
    }

    function test_SetANewSigner() external {
        // it set a new signer

        // 1. calculate the credId hash
        bytes32 newCredIdHash = keccak256(createFixtures.signer.credId);

        // 2. Add a new signer to the account. The only way to call the function is to call it from the account
        // itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(SmartAccount.addWebAuthnP256R1Signer.selector, createFixtures.response.authData)
        );

        // 3. we check the signer doesn't already exist
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(newCredIdHash);

        // 4. we expect the new signer to be added
        (storedCredIdHash, storedPubkeyX, storedPubkeyY) = account.getSigner(newCredIdHash);
        assertEq(storedCredIdHash, keccak256(createFixtures.signer.credId));
        assertEq(storedPubkeyX, createFixtures.signer.pubX);
        assertEq(storedPubkeyY, createFixtures.signer.pubY);
    }

    function test_EmitTheSignerAddEventWithThePrefix() external {
        // it emit the signer add event

        // 1. calculate the credId hash
        bytes32 newCredIdHash = keccak256(createFixtures.signer.credId);

        // 1. Add a new signer to the account. The only way to call the function is to call it from the account
        // itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 2. we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));
        emit SignerAdded(
            Signature.Type.WEBAUTHN_P256R1,
            createFixtures.signer.credId,
            newCredIdHash,
            createFixtures.signer.pubX,
            createFixtures.signer.pubY
        );

        // 3. we call the function that adds the new signer
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(SmartAccount.addWebAuthnP256R1Signer.selector, createFixtures.response.authData)
        );
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
