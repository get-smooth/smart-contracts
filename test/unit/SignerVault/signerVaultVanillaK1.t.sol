// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import { SignerVaultVanillaP256K1 } from "src/SignerVaultVanillaP256K1.sol";

contract SignerVault__VanillaP256K1 is BaseTest {
    SignerVaultVanillaP256K1TestWrapper internal implementation;

    function setUp() external {
        implementation = new SignerVaultVanillaP256K1TestWrapper();
    }

    // bound an address to avoid collisions with precompiled contracts
    function boundNoPrecompute(address addr) private pure returns (address) {
        return address(uint160((bound(uint256(uint160(addr)), 100, type(uint256).max))));
    }

    /// @notice Load the owner address of the signer by reading its exact storage slot
    function loadSS(bytes32 slot) private view returns (address) {
        return address(uint160(uint256(vm.load(address(implementation), slot))));
    }

    // return vm.load(address(implementation), startingSlot);

    function test_AlwaysStoreASignerToTheSameStorageSlot(address signer) external {
        // it should always store a signer to the same storage slot

        signer = boundNoPrecompute(signer);

        // calculate the starting slot for the signer
        bytes32 slot = implementation.getSignerStartingSlot(signer);

        // store the signer
        implementation.set(signer);

        // load the value of the calculated slot
        address signerStored = loadSS(slot);

        // assert the signer is the same as the one stored
        assertEq(signerStored, signer);

        // reset the storage slot
        vm.store(address(implementation), slot, bytes32(0));

        // store the signer again
        implementation.set(signer);

        // load the value of the calculated slot
        signerStored = loadSS(slot);

        // assert the signer is the same as the one stored
        assertEq(signerStored, signer);
    }

    function test_DoesNotStoreTwoSignersToTheSameStorageSlots(address signer1, address signer2) external {
        // it should not store two signers to the same storage slots

        signer1 = boundNoPrecompute(signer1);
        signer2 = boundNoPrecompute(signer2);
        vm.assume(signer1 != signer2);

        // calculate the starting slot for the signer 1
        bytes32 slot1 = implementation.getSignerStartingSlot(signer1);

        // calculate the starting slot for the signer 2
        bytes32 slot2 = implementation.getSignerStartingSlot(signer2);

        // ensure the slots are different
        assertNotEq(slot1, slot2);
    }

    function test_ReturnTrueIfSignerExistsGivenTheOwnerAddress(address signer) external {
        // it should return true if signer exists given the owner address

        signer = boundNoPrecompute(signer);

        // store the signer
        implementation.set(signer);

        // check if the signer exists
        assertTrue(implementation.has(signer));
    }

    function test_ReturnFalseIfNoSignerExistsGivenTheOwnerAddress(address signer) external {
        // it should return false if no signer exists given the owner address

        signer = boundNoPrecompute(signer);

        // check if the signer exists
        assertFalse(implementation.has(signer));
    }

    function test_RemoveAStoredSignerBasedOnTheOwnerAddress(address signer) external {
        // it should remove a stored signer based on the owner address

        signer = boundNoPrecompute(signer);

        // store the signer
        implementation.set(signer);

        // check if the signer exists
        assertTrue(implementation.has(signer));

        // remove the signer
        implementation.remove(signer);

        // check if the signer has been deleted
        assertFalse(implementation.has(signer));
    }

    function test_AlwaysUseTheSameRoot() external {
        // it should always use the same root

        assertEq(implementation.root(), 0x4af245f3834b267909e0839a9d1bd5a4d800d78cbc580638b0487080d20b0900);
    }
}

/// @notice this contract is a wrapper around the SignerVaultVanillaP256K1 library
/// @dev wrapper must be placed after the test contracts for bulloak to work
contract SignerVaultVanillaP256K1TestWrapper {
    function root() external pure returns (bytes32) {
        return SignerVaultVanillaP256K1.ROOT;
    }

    function getSignerStartingSlot(address signer) external pure returns (bytes32) {
        return SignerVaultVanillaP256K1.getSignerStartingSlot(signer);
    }

    function set(address signer) external {
        SignerVaultVanillaP256K1.set(signer);
    }

    function has(address signer) external view returns (bool) {
        return SignerVaultVanillaP256K1.has(signer);
    }

    function remove(address signer) external {
        SignerVaultVanillaP256K1.remove(signer);
    }
}
