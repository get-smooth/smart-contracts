// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Vm } from "forge-std/Vm.sol";

contract Account__Constructor is BaseTest {
    function test_NeverReverts() external {
        try new SmartAccount(address(0), address(0)) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("account.constructor() reverted");
        } catch {
            fail("account.constructor() reverted");
        }
    }

    function test_StoresAndExposesTheWebauthnVerifierAddress(address webAuthnVerifier) external {
        // it should expose the webauthn verifier address

        SmartAccount account = new SmartAccount(address(0), webAuthnVerifier);
        assertEq(account.webAuthnVerifier(), webAuthnVerifier);
    }

    function test_StoresTheEntrypointAddress(address entrypoint) external assumeNoPrecompile(entrypoint) {
        // it should expose the entrypoint address

        SmartAccountTestWrapper account = new SmartAccountTestWrapper(entrypoint, address(0));
        assertEq(account.exposedEntryPoint(), entrypoint);
    }

    function test_StoresTheDeployerAddress() external {
        // it stores the deployer address

        // make the factory the sender for the next call
        address factory = makeAddr("factory");
        vm.prank(factory);

        // deploy the account. The address of the factory must be stored as the deployer
        SmartAccountTestWrapper account = new SmartAccountTestWrapper(makeAddr("entrypoint"), makeAddr("verifier"));

        assertEq(account.exposedFactory(), factory);
    }

    function test_DoNotStoreAnyStorageVariables() external {
        // it should not store any storage variable

        // start recoding future state changes
        vm.startStateDiffRecording();

        // deploy the account (this will trigger the constructor logic)
        address(new SmartAccount(address(1), address(2)));

        // stop recording state changes and get the state diff
        Vm.AccountAccess[] memory records = vm.stopAndReturnStateDiff();

        // make sure nothing has been stored in the storage of the account
        assertEq(records[0].storageAccesses.length, 0);
    }
}

/// @dev Test contract that expose the factory address of the account
contract SmartAccountTestWrapper is SmartAccount {
    constructor(address entryPoint, address webAuthnVerifier) SmartAccount(entryPoint, webAuthnVerifier) { }

    function exposedFactory() external view returns (address) {
        return factory;
    }

    function exposedEntryPoint() external view returns (address) {
        return address(entryPoint());
    }
}
