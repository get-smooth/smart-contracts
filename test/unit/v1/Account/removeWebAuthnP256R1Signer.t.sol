// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__RemoveWebAuthnP256R1Signer is BaseTest {
    SmartAccount private account;
    address private factory;
    address private entrypoint;

    bytes32 private credIdHash = keccak256("qdqd");
    uint256 private pubkeyX = 0x1;
    uint256 private pubkeyY = 0x2;

    // Duplicate of the event in the SmartAccount.sol file
    event SignerRemoved(bytes1 indexed signatureType, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY);

    function setUp() external {
        // deploy the entrypoint
        entrypoint = address(new MockEntryPoint());

        // deploy the account using the "factory"
        factory = makeAddr("factory");
        vm.prank(factory);
        account = new SmartAccount(entrypoint, makeAddr("verifier"));

        // set the first signer
        vm.prank(factory);
        account.addFirstSigner(pubkeyX, pubkeyY, credIdHash);
    }

    function test_CanOnlyBeCalledByItself(address caller) external {
        // it can only be called by itself

        // 1. we assume the caller is not the account
        vm.assume(caller != address(account));

        // 2. we tell the VM to expect an error
        vm.expectRevert(abi.encodeWithSelector(SmartAccount.NotItself.selector));

        // 3. we call the function that adds the new signer using an unauthorized caller
        vm.prank(caller);
        account.removeWebAuthnP256R1Signer(keccak256("qdqd"));
    }

    function test_RemoveAnExistingSigner() external {
        // it remove an existing signer

        // 1. we check the signer exists
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, pubkeyX);
        assertEq(storedPubkeyY, pubkeyY);

        // 2. Add a new signer to the account. The only way to call the function is to call it from the account
        //    itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);
        account.execute(
            address(account), 0, abi.encodeWithSelector(SmartAccount.removeWebAuthnP256R1Signer.selector, credIdHash)
        );

        // 3. we expect the signer to be removed
        (storedCredIdHash, storedPubkeyX, storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, bytes32(0));
        assertEq(storedPubkeyX, 0);
        assertEq(storedPubkeyY, 0);
    }

    function test_DoNotCheckIfTheSignerExists() external {
        // it do not check if the signer exists

        // 1. we check the signer doesn't exist
        bytes32 unsetCredIdHash = keccak256("unset");
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(unsetCredIdHash);
        assertEq(storedCredIdHash, bytes32(0));
        assertEq(storedPubkeyX, 0);
        assertEq(storedPubkeyY, 0);

        // 2. Add a new signer to the account. The only way to call the function is to call it from the account
        //    itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(SmartAccount.removeWebAuthnP256R1Signer.selector, unsetCredIdHash)
        );

        // 3. we expect the signer to be removed
        (storedCredIdHash, storedPubkeyX, storedPubkeyY) = account.getSigner(unsetCredIdHash);
        assertEq(storedCredIdHash, bytes32(0));
        assertEq(storedPubkeyX, 0);
        assertEq(storedPubkeyY, 0);
    }

    function test_EmitTheSignerRemovalEventWithTheOldPubkey() external {
        // it emit the signer removal event with the old pubkey

        // 1. Add a new signer to the account. The only way to call the function is to call it from the account
        // itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 2. we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));
        emit SignerRemoved(Signature.Type.WEBAUTHN_P256R1, credIdHash, pubkeyX, pubkeyY);

        // 3. we call the function that adds the new signer
        account.execute(
            address(account), 0, abi.encodeWithSelector(SmartAccount.removeWebAuthnP256R1Signer.selector, credIdHash)
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
