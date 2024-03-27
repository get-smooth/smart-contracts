// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__AddFirstSigner is BaseTest {
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

    function test_RevertsIfTheNonceIsNot0(uint256 randomNonce) external {
        // it reverts if the nonce is not 0

        randomNonce = bound(randomNonce, 1, type(uint256).max);

        // mock the call to the entrypoint to return the random nonce
        vm.mockCall(
            address(entrypoint), abi.encodeWithSelector(MockEntryPoint.getNonce.selector), abi.encode(randomNonce)
        );

        // expect an error for the next call of `addFirstSigner`
        vm.expectRevert(SmartAccount.InvalidFirstSignerAddition.selector);

        //  try to add the first signer -- this must revert
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);
    }

    function test_RevertsIfNotCalledByTheFactory() external {
        // it reverts if not called by the factory

        // expect an error for the next call of `addFirstSigner`
        vm.expectRevert(SmartAccount.NotTheFactory.selector);

        //  try to add the first signer -- this must revert
        account.addFirstSigner(createFixtures.response.authData);
    }

    function test_StoresTheSigner() external {
        // it stores the signer

        bytes memory credId = createFixtures.signer.credId;
        bytes32 credIdHash = keccak256(credId);
        uint256 expectedPubX = createFixtures.signer.pubX;
        uint256 expectedPubY = createFixtures.signer.pubY;

        // get the starting slot of the signer
        bytes32 startingSlot = SignerVaultWebAuthnP256R1.getSignerStartingSlot(credIdHash);

        // check nothing has been stored yet
        assertEq(vm.load(address(account), startingSlot), bytes32(0));
        assertEq(bytes32(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 1)))), bytes32(0));
        assertEq(bytes32(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 2)))), bytes32(0));

        // add the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);

        // check the signer has been stored
        assertEq(vm.load(address(account), startingSlot), credIdHash);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 1))), expectedPubX);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 2))), expectedPubY);
    }

    function test_EmitsTheSignerAddEvent() external {
        // it emits the signer add event

        // bound the pubkey to the secp256r1 curve
        bytes memory credId = createFixtures.signer.credId;
        bytes32 credIdHash = keccak256(credId);
        uint256 expectedPubX = createFixtures.signer.pubX;
        uint256 expectedPubY = createFixtures.signer.pubY;

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));

        // we trigger the exact event we expect to be emitted in the next call
        emit SignerAdded(Signature.Type.WEBAUTHN_P256R1, credId, credIdHash, expectedPubX, expectedPubY);

        // burn the fuse by adding the first signer
        vm.prank(factory);
        account.addFirstSigner(createFixtures.response.authData);
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}
