// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { ForkTest } from "test/fork/ForkTest.t.sol";
import { AccountFactory } from "src/AccountFactory.sol";

contract Fork__AccountFactory is ForkTest {
    AccountFactory internal factory;

    // DEV: we do not test the account implementation yet, let's we mock it
    address constant defaultWebAuthnVerifier = address(0);
    // TODO: USE A REAL NAME SERVICE OWNER
    address constant defaultNameServiceOwner = address(2);

    function setUp() external initFork {
        // deploy a new factory before each test
        factory = new AccountFactory{ salt: "fork_test_factory" }(
            address(ENTRYPOINT), defaultWebAuthnVerifier, defaultNameServiceOwner
        );
    }

    function test_MustCreateAnAccountWithNewGivenAddress() external {
        // it must create an account with new given address
    }

    function test_MustCreateAnAccountAndInitWithNewGivenAddress() external {
        // it must create an account and init with new given address
    }

    function test_MustReturnTheAddressOfAlreadyDeployedAccount() external {
        // it must return the address of already deployed account
    }

    function test_MustReturnCorrectAddressOfTheAccount() external {
        // it must return correct address of the account
    }

    function test_MustSetTheCorrectAddressOfTheEntrypointInTheAccount() external {
        // it must set the correct address of the entrypoint in the account
    }
}
