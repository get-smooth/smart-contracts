// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";

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

    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function test_DisableTheInitializer() external {
        // it disable the initializer

        // deploy the account
        SmartAccountTestWrapper account = new SmartAccountTestWrapper(makeAddr("entrypoint"), makeAddr("verifier"));

        // make sure the version is set to the max value possible
        bytes32 value = vm.load(address(account), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(type(uint64).max)));

        // make sure the initializer is not callable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize();
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
