// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetVersion
/// @notice Fetch the version of the account
contract AccountGetVersion is BaseScript {
    function run() public broadcast returns (uint256 version) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the version ofthe account
        version = account.version();
    }
}
