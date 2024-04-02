// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetFactory
/// @notice Fetch the factory that deployed the account
contract AccountGetFactory is BaseScript {
    function run() public broadcast returns (address factory) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the factory
        factory = account.factory();
    }
}
