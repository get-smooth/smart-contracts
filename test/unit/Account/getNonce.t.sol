// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";

contract Account__GetNonce is BaseTest {
    SmartAccount private acc;

    function setUp() external {
        address entryPoint = address(new MinimalistEntryPointNonceManagerTest());
        acc = new SmartAccount(entryPoint, makeAddr("verifier"));
    }

    //TODO: increment nonce in the account?

    function test_ReturnTheNextSequentialNonceOfTheAccount() external {
        // it return the next sequential nonce of the account

        // manually increment the nonce -- faking a transaction by the account
        MinimalistEntryPointNonceManagerTest(address(acc.entryPoint())).incrementNonce();

        // make sure the nonce has been incremented
        assertEq(acc.getNonce(), 1);
    }

    function test_Return0ForInactiveAccount() external {
        // it return 0 for a never used account

        assertEq(acc.getNonce(), 0);
    }
}

contract MinimalistEntryPointNonceManagerTest {
    uint256 internal nonce;

    function getNonce(address, uint192) external view returns (uint256) {
        return nonce;
    }

    function incrementNonce() external {
        nonce++;
    }
}
