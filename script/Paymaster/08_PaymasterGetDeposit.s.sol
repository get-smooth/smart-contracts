// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterGetDeposit
/// @notice Fetch the current deposit of the paymaster
contract PaymasterGetDeposit is BaseScript {
    function run() public broadcast returns (uint256 balance) {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // fetch the current deposit of the paymaster
        balance = paymaster.getDeposit();
    }
}
