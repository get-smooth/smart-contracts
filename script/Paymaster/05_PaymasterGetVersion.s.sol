// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterGetVersion
/// @notice Fetch the version of the paymaster
contract PaymasterGetVersion is BaseScript {
    function run() public broadcast returns (uint256 version) {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // fetch the version of the paymaster
        version = paymaster.version();
    }
}
