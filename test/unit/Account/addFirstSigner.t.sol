// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { SignerVaultWebAuthnP256R1 } from "src/SignerVaultWebAuthnP256R1.sol";
import { BaseTest } from "test/BaseTest.sol";
import { StorageSlotRegistry } from "src/StorageSlotRegistry.sol";

contract Account__AddFirstSigner is BaseTest {
    SmartAccount private account;
    uint256 private pubkeyX = 0x1;
    uint256 private pubkeyY = 0x2;

    // Duplicate of the event in the Account.sol file
    event SignerAdded(bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY);

    function setUp() external {
        // deploy the account
        account = new SmartAccount(address(1), address(2));
    }

    function test_RevertsIfTheFuseIsNotSet() external {
        // it reverts if the fuse is not set

        vm.expectRevert(abi.encodeWithSelector(SmartAccount.FirstSignerAlreadySet.selector));

        account.addFirstSigner(pubkeyX, pubkeyY, keccak256("qdqdqdqdqddqd"));
    }

    function test_BurnsTheFuse() external {
        // it burns the fuse

        // initialize the account to set the fuse to true
        account.initialize();

        // make sure the fuse is set to true
        assertEq(vm.load(address(account), StorageSlotRegistry.FIRST_SIGNER_FUSE), bytes32(uint256(1)));

        // burn the fuse by adding the first signer
        account.addFirstSigner(pubkeyX, pubkeyY, keccak256("qdqdqdqdqddqd"));

        // make sure the fuse is set to false
        assertEq(vm.load(address(account), StorageSlotRegistry.FIRST_SIGNER_FUSE), bytes32(0));
    }

    function test_CanNotBeCalledTwice() external {
        // initialize the account to set the fuse to true
        account.initialize();

        // burn the fuse by adding the first signer
        account.addFirstSigner(pubkeyX, pubkeyY, keccak256("qdqdqdqdqddqd"));

        // expect an error for the next call of `addFirstSigner`
        vm.expectRevert(abi.encodeWithSelector(SmartAccount.FirstSignerAlreadySet.selector));

        // try to add the first signer again -- this must revert
        account.addFirstSigner(pubkeyX, pubkeyY, keccak256("qdqdqdqdqddqd"));
    }

    function test_StoresTheSigner() external {
        // it stores the signer

        bytes memory credId = "qdqdqdqdqddqd";
        bytes32 credIdHash = keccak256(credId);

        // initialize the account to set the fuse to true
        account.initialize();

        // get the starting slot of the signer
        bytes32 startingSlot = SignerVaultWebAuthnP256R1.getSignerStartingSlot(credIdHash);

        // check nothing has been stored yet
        assertEq(vm.load(address(account), startingSlot), bytes32(0));
        assertEq(bytes32(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 1)))), bytes32(0));
        assertEq(bytes32(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 2)))), bytes32(0));

        // add the first signer
        account.addFirstSigner(pubkeyX, pubkeyY, credIdHash);

        // check the signer has been stored
        assertEq(vm.load(address(account), startingSlot), credIdHash);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 1))), pubkeyX);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 2))), pubkeyY);
    }

    function test_EmitsTheSignerAddEvent(uint256 fuzzedPubKeyX, uint256 fuzzedPubKeyY) external {
        // it emits the signer add event

        // bound the pubkey to the secp256r1 curve
        fuzzedPubKeyX = boundP256R1(fuzzedPubKeyX);
        fuzzedPubKeyY = boundP256R1(fuzzedPubKeyY);

        bytes memory credId = "qdqdqdqdqddqd";
        bytes32 credIdHash = keccak256(credId);

        // initialize the account to set the fuse to true
        account.initialize();

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));

        // we trigger the exact event we expect to be emitted in the next call
        emit SignerAdded(credIdHash, fuzzedPubKeyX, fuzzedPubKeyY);

        // burn the fuse by adding the first signer
        account.addFirstSigner(fuzzedPubKeyX, fuzzedPubKeyY, credIdHash);
    }
}
