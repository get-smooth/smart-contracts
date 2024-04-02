// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterGetOwner
/// @notice Fetch the owner of the paymaster
contract PaymasterGetOwner is BaseScript {
    function run() public broadcast returns (address owner) {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // fetch the owner of the paymaster
        owner = paymaster.owner();
    }
}
