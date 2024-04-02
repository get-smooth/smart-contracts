// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__RemoveWebAuthnP256R1Signer is BaseTest {
    SmartAccount private account;
    address private entrypoint;

    // Duplicate of the event in the SmartAccount.sol file
    event SignerRemoved(bytes1 indexed signatureType, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY);

    function setUp() external setUpCreateFixture {
        // 1. deploy a mock of the entrypoint
        entrypoint = address(new MockEntryPoint());

        // 2. deploy the implementation of the account
        SmartAccount accountImplementation = new SmartAccount(entrypoint, makeAddr("verifier"));

        // 3. deploy the factory
        address factoryImplementation = address(deployFactoryImplementation(address(accountImplementation)));
        AccountFactory factory =
            deployFactoryInstance(factoryImplementation, makeAddr("proxy_owner"), SMOOTH_SIGNER.addr);

        // 4. calculate the future address of the account
        address accountFutureAddress = factory.getAddress(createFixtures.response.authData);

        // 5. deploy the proxy that targets the implementation and set the first signer
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountFutureAddress);
        account = SmartAccount(payable(factory.createAndInitAccount(createFixtures.response.authData, signature)));
    }

    function test_CanOnlyBeCalledByItself(address caller) external {
        // it can only be called by itself

        // 1. we assume the caller is not the account
        vm.assume(caller != address(account));

        // 2. we tell the VM to expect an error
        vm.expectRevert(abi.encodeWithSelector(SmartAccount.NotItself.selector));

        // 3. we call the function that adds the new signer using an unauthorized caller
        vm.prank(caller);
        account.removeWebAuthnP256R1Signer(keccak256(createFixtures.signer.credId));
    }

    function test_RemoveAnExistingSigner() external {
        // it remove an existing signer

        // 1. calculate the credIdHash of the stored signer
        bytes32 credIdHash = keccak256(createFixtures.signer.credId);

        // 1. we check the signer exists
        (bytes32 storedCredIdHash, uint256 storedPubkeyX, uint256 storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, credIdHash);
        assertEq(storedPubkeyX, createFixtures.signer.pubX);
        assertEq(storedPubkeyY, createFixtures.signer.pubY);

        // 2. Remove the signer from the account. The only way to call the function is to call it from the account
        //    itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);
        account.execute(
            address(account), 0, abi.encodeWithSelector(SmartAccount.removeWebAuthnP256R1Signer.selector, credIdHash)
        );

        // // 3. we expect the signer to be removed
        (storedCredIdHash, storedPubkeyX, storedPubkeyY) = account.getSigner(credIdHash);
        assertEq(storedCredIdHash, bytes32(0));
        assertEq(storedPubkeyX, 0);
        assertEq(storedPubkeyY, 0);
    }

    function test_DoNotCheckIfTheSignerExists() external view {
        // it do not check if the signer exists

        // 1. we remove an unset signer -- it should not revert
        try account.getSigner(keccak256("it's a trap")) {
            assertTrue(true);
        } catch Error(string memory) {
            assertTrue(false);
        } catch {
            assertTrue(false);
        }
    }

    function test_EmitTheSignerRemovalEventWithTheOldPubkey() external {
        // it emit the signer removal event with the old pubkey

        // 1. Add a new signer to the account. The only way to call the function is to call it from the account
        // itself. The only way to do that is by calling the `execute` function with the entrypoint contract.
        vm.prank(entrypoint);

        // 2. we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(account));
        emit SignerRemoved(
            Signature.Type.WEBAUTHN_P256R1,
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY
        );

        // 3. we call the function that adds the new signer
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(
                SmartAccount.removeWebAuthnP256R1Signer.selector, keccak256(createFixtures.signer.credId)
            )
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
