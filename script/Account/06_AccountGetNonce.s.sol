// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetNonce
/// @notice Fetch the 4337 nonce of the account
contract AccountGetNonce is BaseScript {
    function run() public broadcast returns (uint256 nonce) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the 4337 nonce of the account
        nonce = account.getNonce();
    }
}
