// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__AddWebAuthnP256R1Signer is BaseTest {
    SmartAccount private account;
    address private entrypoint;

    // Duplicate of the event in the SmartAccount.sol file
    event SignerAdded(
        bytes1 indexed signatureType, bytes credId, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function setUp() external setUpCreateFixture {
        // 1. deploy the entrypoint
        entrypoint = address(new MockEntryPoint());

        // 2. deploy the implementation of the account
        SmartAccount accountImplementation = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 3. deploy the factory
        AccountFactory factory = new AccountFactory(address(accountImplementation), SMOOTH_SIGNER.addr);

        // 4. calculate the future address of the account
        address accountFutureAddress = factory.getAddress(createFixtures.response.authData);

        // 5. deploy the proxy that targets the implementation and set the first signer
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountFutureAddress);
        account = SmartAccount(
            payable(
                factory.createAndInitAccount(
                    createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
                )
            )
        );
    }

    function test_RevertsIfTheSignerAlreadyExists() external {
        // it reverts if the signer already exists

        // 1. Add a new signer to the account. The only way to call the function is to call it from the account itself.
        //    The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 2. we tell the VM to expect an error
        vm.expectRevert(
            abi.encodeWithSelector(
                SignerVaultWebAuthnP256R1.SignerOverrideNotAllowed.selector, keccak256(createFixtures.signer.credId)
            )
        );

        // 3. we call the function that adds the new signer
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

        // 1. load another valid fixture to test the creation of a new signer
        // (!!) This function override the initial one in the storage. After this point, for this test,
        // the `createFixtures` variable will be the one loaded by the `loadCreateFixture` function
        loadCreateFixture(createFixtures.id + 1);

        // 2. calculate the credId hash
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

        // 1. load another valid fixture to test the creation of a new signer
        // (!!) This function override the initial one in the storage. After this point, for this test,
        // the `createFixtures` variable will be the one loaded by the `loadCreateFixture` function
        loadCreateFixture(createFixtures.id + 1);

        // 2. Add a new signer to the account. The only way to call the function is to call it from the account
        // itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 3. we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));
        emit SignerAdded(
            Signature.Type.WEBAUTHN_P256R1,
            createFixtures.signer.credId,
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY
        );

        // 4. we call the function that adds the new signer
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
