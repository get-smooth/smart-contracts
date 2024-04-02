// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetImplementation
/// @notice Fetch the implementation account consumed by the proxy
contract AccountGetImplementation is BaseScript {
    function run() public broadcast returns (address accountImplementation) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // fetch the storage slot where the implementation is stored
        bytes32 implementationSlot = account.proxiableUUID();

        // load the storage of the account to get the implementation
        accountImplementation = address(bytes20(vm.load(accountAddress, implementationSlot)));
    }
}
