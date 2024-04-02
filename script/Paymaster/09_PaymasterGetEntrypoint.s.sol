// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterGetEntrypoint
/// @notice Fetch the entrypoint used by the paymaster
contract PaymasterGetEntrypoint is BaseScript {
    function run() public broadcast returns (address entryPointAddress) {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // fetch the entrypoint used by the paymaster
        entryPointAddress = address(paymaster.entryPoint());
    }
}
