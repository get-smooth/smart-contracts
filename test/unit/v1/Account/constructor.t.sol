// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SmartAccount__Constructor is BaseTest {
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

    function test_StoresTheEntrypointAddress(address entrypoint) external {
        // it should expose the entrypoint address

        assumeNotPrecompile(entrypoint);

        SmartAccount account = new SmartAccount(entrypoint, address(0));
        assertEq(address(account.entryPoint()), entrypoint);
    }

    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function test_DisableTheInitializer() external {
        // it disable the initializer

        // deploy the account
        SmartAccount account = new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier"));

        // make sure the version is set to the max value possible
        bytes32 value = vm.load(address(account), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(type(uint64).max)));

        // make sure the initializer is not callable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize();
    }
}
