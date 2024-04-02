// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetEntrypoint
/// @notice Fetch the entrypoint used by the account
contract AccountGetEntrypoint is BaseScript {
    function run() public broadcast returns (address entryPoint) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the entrypoint used by the account
        entryPoint = address(account.entryPoint());
    }
}
