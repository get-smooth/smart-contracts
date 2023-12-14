// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import { SignerVaultWebAuthnP256R1 } from "src/SignerVaultWebAuthnP256R1.sol";

contract SignerVault__WebAuthnP256R1 is BaseTest {
    SignerVaultWebAuthnP256R1TestWrapper internal implementation;

    function setUp() external {
        implementation = new SignerVaultWebAuthnP256R1TestWrapper();
    }

    // user-defined value used to make the tests clearer
    enum SIGNER {
        CLIENT_ID_HASH,
        PUBKEY_X,
        PUBKEY_Y
    }

    /// @notice bound the arguments to a valid range
    function _safeBound(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        private
        pure
        returns (uint256, uint256)
    {
        vm.assume(clientIdHash != keccak256(""));
        pubkeyX = bound(pubkeyX, 1, type(uint256).max);
        pubkeyY = bound(pubkeyY, 1, type(uint256).max);
        return (pubkeyX, pubkeyY);
    }

    /// @notice Load a specific data of the signer by reading its exact storage slot
    function loadSS(bytes32 startingSlot, SIGNER offset) private view returns (bytes32) {
        bytes32 slot = bytes32(uint256(startingSlot) + uint8(offset));
        return vm.load(address(implementation), slot);
    }

    /// @notice Do the same than `loadSS` but cast the result to an unsigned 256-bits integer
    function loadSSxU(bytes32 startingSlot, SIGNER offset) private view returns (uint256) {
        return uint256(loadSS(startingSlot, offset));
    }

    /// @dev We manipulate the storage slots directly instead of calling the other utils functions
    ///      of the library to isolate the test as much as possible
    function test_ShouldAlwaysStoreASignerToTheSameStorageSlots(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should always store a signer to the same storage slots

        // bound the fuzzed arguments to have coherent values
        (pubkeyX, pubkeyY) = _safeBound(clientIdHash, pubkeyX, pubkeyY);

        // calculate the starting slot where the signer will be stored
        bytes32 startingSlot = implementation.getSignerStartingSlot(clientIdHash);

        // ensure the slots where the signer will be stored are empty
        assertEq(loadSSxU(startingSlot, SIGNER.CLIENT_ID_HASH), 0);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), 0);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), 0);

        // store the signer
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // ensure the slots where the signer is expected to be stored now contain the signer's data
        assertEq(loadSS(startingSlot, SIGNER.CLIENT_ID_HASH), clientIdHash);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), pubkeyX);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), pubkeyY);

        // reset the storage slots
        vm.store(address(implementation), startingSlot, bytes32(0));
        vm.store(address(implementation), bytes32(uint256(startingSlot) + 1), bytes32(0));
        vm.store(address(implementation), bytes32(uint256(startingSlot) + 2), bytes32(0));

        // store the signer again
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // ensure the slots where the signer is expected to be stored contain the signer's data again
        assertEq(loadSS(startingSlot, SIGNER.CLIENT_ID_HASH), clientIdHash);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), pubkeyX);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), pubkeyY);
    }

    function test_ShouldNotStoreTwoSignersToTheSameStorageSlots(
        bytes32 clientIdHash1,
        bytes32 clientIdHash2
    )
        external
    {
        // it should not store two signers to the same storage slots

        // bound the fuzzed arguments to have coherent values
        vm.assume(clientIdHash1 != keccak256(""));
        vm.assume(clientIdHash1 != clientIdHash2);

        // calculate the starting slot where the first signer will be stored
        bytes32 startingSlot1 = implementation.getSignerStartingSlot(clientIdHash1);

        // calculate the starting slot where the second signer will be stored
        bytes32 startingSlot2 = implementation.getSignerStartingSlot(clientIdHash2);

        // ensure both starting slots are different
        assertNotEq(startingSlot1, startingSlot2);
    }

    function test_ShouldBePossibleToOverrideExistingSigner(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should be possible to override existing signer

        // bound the fuzzed arguments to have coherent values
        (pubkeyX, pubkeyY) = _safeBound(clientIdHash, pubkeyX, pubkeyY);

        // store the signer in the vault
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // store the signer in the vault
        implementation.set(clientIdHash, 1, 2);

        // calculate the starting slot where the signer will be stored
        bytes32 startingSlot = implementation.getSignerStartingSlot(clientIdHash);

        // ensure the slots where the signer will be stored are empty
        assertEq(loadSS(startingSlot, SIGNER.CLIENT_ID_HASH), clientIdHash);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), uint256(1));
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), uint256(2));
    }

    function test_ShouldReturnTheStoredSignerGivenAClientId(
        bytes calldata clientId,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should return the stored signer given a client id

        // bound the fuzzed coordinates to have coherent values
        pubkeyX = bound(pubkeyX, 1, type(uint256).max);
        pubkeyY = bound(pubkeyY, 1, type(uint256).max);

        // calculate the hash of the client id
        bytes32 clientIdHash = keccak256(clientId);

        // store the signer in the vaul
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // retrieve the signer for the given client id
        SignerVaultWebAuthnP256R1.WebAuthnP256R1Signer memory signer = implementation.get(clientId);
        assertEq(signer.clientIdHash, clientIdHash);
        assertEq(signer.pubkeyX, pubkeyX);
        assertEq(signer.pubkeyY, pubkeyY);
    }

    function test_ShouldReturnAnEmptySignerIfNotFoundGivenAClientId(bytes calldata clientId) external {
        // it should return an empty signer if not found given a client id

        // retrieve the signer for the given client id
        SignerVaultWebAuthnP256R1.WebAuthnP256R1Signer memory signer = implementation.get(clientId);
        assertEq(signer.clientIdHash, bytes32(0));
        assertEq(signer.pubkeyX, 0);
        assertEq(signer.pubkeyY, 0);
    }

    function test_ShouldRevertIfNoSignerFoundWhenUsingSafe(bytes calldata clientId) external {
        // it should revert if no signer found when using safe

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(abi.encodeWithSelector(SignerVaultWebAuthnP256R1.SignerNotFound.selector, clientId));

        // try to retrieve a non-existing signer using the safe method
        implementation.tryGet(clientId);
    }

    function test_ShouldReturnTrueIfSignerExistsGivenAClientIdHash(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should return true if signer exists given a client id hash

        // bound the fuzzed arguments to have coherent values
        (pubkeyX, pubkeyY) = _safeBound(clientIdHash, pubkeyX, pubkeyY);

        // store the signer in the vault
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // ensure the signer exists
        assertTrue(implementation.has(clientIdHash));
    }

    function test_ShouldReturnFalseIfNoSignerExistsGivenAClientIdHash(bytes32 clientIdHash) external {
        // it should return false if no signer exists given a client id hash

        // ensure the signer exists
        assertFalse(implementation.has(clientIdHash));
    }

    function test_ShouldReturnTrueIfSignerExistsGivenAClientId(
        bytes calldata clientId,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should return true if signer exists given a client id

        // bound the fuzzed arguments to have coherent values
        pubkeyX = bound(pubkeyX, 1, type(uint256).max);
        pubkeyY = bound(pubkeyY, 2, type(uint256).max);

        // store the signer in the vault
        implementation.set(keccak256(clientId), pubkeyX, pubkeyY);

        // ensure the signer exists
        assertTrue(implementation.has(clientId));
    }

    function test_ShouldReturnFalseIfNoSignerExistsGivenAClientId(bytes calldata clientId) external {
        // it should return false if no signer exists given a client id

        // ensure the signer exists
        assertFalse(implementation.has(clientId));
    }

    function test_ShouldRemoveAStoredSignerBasedOnAClientIdHash(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should remove a stored signer based on a client id hash

        // bound the fuzzed arguments to have coherent values
        (pubkeyX, pubkeyY) = _safeBound(clientIdHash, pubkeyX, pubkeyY);

        // calculate the starting slot where the signer will be stored
        bytes32 startingSlot = implementation.getSignerStartingSlot(clientIdHash);

        // store the signer
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // ensure the signer exists
        assertEq(loadSS(startingSlot, SIGNER.CLIENT_ID_HASH), clientIdHash);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), pubkeyX);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), pubkeyY);

        // remove the signer
        implementation.remove(clientIdHash);

        // ensure the signer has been removed
        assertEq(loadSS(startingSlot, SIGNER.CLIENT_ID_HASH), bytes32(0));
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_X), 0);
        assertEq(loadSSxU(startingSlot, SIGNER.PUBKEY_Y), 0);
    }

    function test_ShouldReturnTheStoredPubkeyAssociatedToAClientIdHash(
        bytes32 clientIdHash,
        uint256 pubkeyX,
        uint256 pubkeyY
    )
        external
    {
        // it should return the store pubkey associated given a client id hash

        // bound the fuzzed arguments to have coherent values
        (pubkeyX, pubkeyY) = _safeBound(clientIdHash, pubkeyX, pubkeyY);

        // store the signer in the vault
        implementation.set(clientIdHash, pubkeyX, pubkeyY);

        // retrieve the pubkey associated to the client id hash
        (uint256 pkX, uint256 pkY) = implementation.pubkey(clientIdHash);

        // ensure the pubkey is the one we expect
        assertEq(pkX, pubkeyX);
        assertEq(pkY, pubkeyY);
    }

    /// @dev The root value must never change. Never.
    function test_ShouldAlwaysUseTheSameRoot() external {
        // it should always use the same root

        assertEq(implementation.root(), 0x766490bc3db2290d3ce2c7c2b394a53399f99517ba4974536d11869c06dc8900);
    }
}

/// @notice this contract is a wrapper around the SignerVaultWebAuthnP256R1 library
/// @dev wrapper must be placed after the test contracts for bulloak to work
contract SignerVaultWebAuthnP256R1TestWrapper {
    function root() external pure returns (bytes32) {
        return SignerVaultWebAuthnP256R1.ROOT;
    }

    function getSignerStartingSlot(bytes32 clientIdHash) external pure returns (bytes32) {
        return SignerVaultWebAuthnP256R1.getSignerStartingSlot(clientIdHash);
    }

    function set(bytes32 clientIdHash, uint256 pubkeyX, uint256 pubkeyY) external {
        SignerVaultWebAuthnP256R1.set(clientIdHash, pubkeyX, pubkeyY);
    }

    function get(bytes calldata clientId)
        external
        view
        returns (SignerVaultWebAuthnP256R1.WebAuthnP256R1Signer memory WP256r1signer)
    {
        return SignerVaultWebAuthnP256R1.get(clientId);
    }

    function tryGet(bytes calldata clientId)
        external
        view
        returns (SignerVaultWebAuthnP256R1.WebAuthnP256R1Signer memory WP256r1signer)
    {
        return SignerVaultWebAuthnP256R1.tryGet(clientId);
    }

    function has(bytes32 clientIdHash) external view returns (bool) {
        return SignerVaultWebAuthnP256R1.has(clientIdHash);
    }

    function has(bytes memory clientId) external view returns (bool) {
        return SignerVaultWebAuthnP256R1.has(clientId);
    }

    function pubkey(bytes32 clientIdHash) external view returns (uint256 pubkeyX, uint256 pubkeyY) {
        return SignerVaultWebAuthnP256R1.pubkey(clientIdHash);
    }

    function remove(bytes32 clientIdHash) external {
        SignerVaultWebAuthnP256R1.remove(clientIdHash);
    }
}
