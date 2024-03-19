// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseTest } from "test/BaseTest.sol";

contract SmartAccount__Receive is BaseTest {
    address internal account;

    function setUp() external {
        account = address(new SmartAccount(makeAddr("entrypoint"), makeAddr("verifier")));
    }

    function test_CanReceiveNativeTokens(address sender, uint256 amount) external {
        // it can receive native tokens

        // sender = bound(100, type(address).max);
        amount = bound(amount, 1, type(uint256).max);

        // make the sender the caller for the next call and send him n native tokens
        hoax(sender, amount);
        // send all the native tokens from the sender to the account
        (bool sent,) = account.call{ value: amount }("");

        // make sure the account has received the native tokens from the sender
        assertTrue(sent);
        assertEq(address(account).balance, amount);
    }
}
